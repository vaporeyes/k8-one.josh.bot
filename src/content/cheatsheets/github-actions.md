---
title: "GitHub Actions"
description: "Quick reference for CI/CD workflows, triggers, jobs, and common patterns."
updatedDate: 2026-03-30
---

## Workflow Structure

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: go test ./...
```

## Triggers

```yaml
# Push / PR
on:
  push:
    branches: [main, release/*]
    paths: ['src/**', '*.go']
    tags: ['v*']
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]

# Schedule (cron)
on:
  schedule:
    - cron: '0 6 * * 1'              # Monday 6am UTC

# Manual trigger
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]

# On release
on:
  release:
    types: [published]

# On other workflow completion
on:
  workflow_run:
    workflows: ["Build"]
    types: [completed]
    branches: [main]

# Path filtering (ignore)
on:
  push:
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

## Jobs

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make test

  deploy:
    needs: test                        # dependency
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - run: echo "deploying"

  # Matrix strategy
  test-matrix:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        go-version: ['1.21', '1.22']
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ matrix.go-version }}

  # Reusable job with outputs
  version:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.get_tag.outputs.tag }}
    steps:
      - id: get_tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> "$GITHUB_OUTPUT"
```

## Steps

```yaml
steps:
  # Use an action
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0                   # full history

  # Run command
  - name: Build
    run: go build -o bin/server ./cmd/api

  # Multi-line command
  - name: Setup
    run: |
      echo "Setting up..."
      go mod download
      go generate ./...

  # Working directory
  - name: Test frontend
    run: npm test
    working-directory: ./frontend

  # Environment variables
  - name: Deploy
    run: ./deploy.sh
    env:
      AWS_REGION: us-east-1
      DEPLOY_ENV: ${{ inputs.environment }}

  # Conditional step
  - name: Deploy
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    run: ./deploy.sh

  # Continue on error
  - name: Lint
    run: golangci-lint run
    continue-on-error: true
```

## Environment and Secrets

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production            # requires approval
    env:
      APP_ENV: production
    steps:
      - name: Deploy
        run: ./deploy.sh
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      # Using vars (non-secret config)
      - name: Configure
        run: echo "Region is ${{ vars.AWS_REGION }}"
```

## Caching

```yaml
# Go modules
- uses: actions/setup-go@v5
  with:
    go-version-file: go.mod
    cache: true                        # auto-caches go modules

# Node modules
- uses: actions/setup-node@v4
  with:
    node-version-file: .node-version
    cache: npm

# Manual cache
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/pip
      .venv
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

## Artifacts

```yaml
# Upload
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    retention-days: 5

# Download (in another job)
- uses: actions/download-artifact@v4
  with:
    name: build-output
    path: dist/
```

## Common Actions

```yaml
# Checkout
- uses: actions/checkout@v4

# Go
- uses: actions/setup-go@v5
  with:
    go-version-file: go.mod

# Node
- uses: actions/setup-node@v4
  with:
    node-version-file: .node-version

# Python + uv
- uses: astral-sh/setup-uv@v5
- run: uv sync --locked

# Docker build + push
- uses: docker/setup-buildx-action@v3
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
- uses: docker/build-push-action@v6
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

# AWS credentials
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-arn: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1

# Terraform
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.7"
```

## Contexts and Expressions

```yaml
# GitHub context
${{ github.sha }}                      # commit SHA
${{ github.ref }}                      # refs/heads/main
${{ github.ref_name }}                 # main
${{ github.event_name }}               # push, pull_request
${{ github.actor }}                    # username
${{ github.repository }}               # owner/repo
${{ github.workspace }}                # checkout path
${{ github.run_id }}                   # unique run ID
${{ github.event.pull_request.number }}

# Conditionals
if: success()
if: failure()
if: always()
if: cancelled()
if: contains(github.event.head_commit.message, '[skip ci]')
if: startsWith(github.ref, 'refs/tags/v')
if: github.event_name == 'push'

# Ternary-like
${{ github.ref == 'refs/heads/main' && 'prod' || 'staging' }}
```

## Reusable Workflows

```yaml
# .github/workflows/deploy.yml (reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      AWS_ROLE_ARN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "Deploying to ${{ inputs.environment }}"
```

```yaml
# Caller workflow
jobs:
  deploy-staging:
    uses: ./.github/workflows/deploy.yml
    with:
      environment: staging
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## Useful Patterns

```yaml
# Run only on main, skip drafts
if: |
  github.event_name == 'push' ||
  (github.event_name == 'pull_request' && !github.event.pull_request.draft)

# Cancel in-progress runs on same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# Set output from step
- id: version
  run: echo "tag=$(git describe --tags --abbrev=0)" >> "$GITHUB_OUTPUT"
- run: echo "Version is ${{ steps.version.outputs.tag }}"

# Timeout
jobs:
  build:
    timeout-minutes: 15

# Permissions (least privilege)
permissions:
  contents: read
  packages: write
  id-token: write                      # for OIDC

# Service containers
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_PASSWORD: test
    ports: ['5432:5432']
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```
