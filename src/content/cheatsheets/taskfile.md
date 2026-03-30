---
title: "Taskfile"
description: "Quick reference for Task runner - a simpler alternative to Make for dev workflows."
updatedDate: 2026-03-30
---

## Basics

```bash
# Run default task
task

# Run named task
task build

# Run multiple tasks
task lint test

# List available tasks
task --list
task -l

# Dry run (show commands)
task build --dry

# Force run (ignore up-to-date checks)
task build --force
```

## Taskfile Structure

```yaml
# Taskfile.yml
version: '3'

vars:
  APP_NAME: myapp
  BUILD_DIR: bin

tasks:
  default:
    cmds:
      - task: test
      - task: build

  build:
    desc: Build the application
    cmds:
      - go build -o {{.BUILD_DIR}}/{{.APP_NAME}} ./cmd/api

  test:
    desc: Run tests
    cmds:
      - go test ./...
```

## Variables

```yaml
# Global variables
vars:
  ENV: dev
  PORT: 8080

# Dynamic variables (shell output)
vars:
  GIT_SHA:
    sh: git rev-parse --short HEAD
  VERSION:
    sh: cat VERSION

# Task-level variables
tasks:
  deploy:
    vars:
      TARGET: '{{.ENV | default "staging"}}'
    cmds:
      - echo "Deploying to {{.TARGET}}"

# Environment variables
tasks:
  run:
    env:
      PORT: '{{.PORT}}'
      LOG_LEVEL: debug
    cmds:
      - go run ./cmd/api
```

## Task Dependencies

```yaml
tasks:
  build:
    deps: [generate, lint]
    cmds:
      - go build -o bin/server .

  # Dependencies run in parallel by default.
  # Use 'cmds' with 'task' to run sequentially.
  deploy:
    cmds:
      - task: test
      - task: build
      - task: push

  # Dependency with variables
  docker:
    deps:
      - task: build
        vars:
          GOOS: linux
          GOARCH: amd64
    cmds:
      - docker build -t myapp .
```

## Sources and Generates (Up-to-date Checks)

```yaml
tasks:
  build:
    desc: Build binary
    sources:
      - ./**/*.go
      - go.mod
      - go.sum
    generates:
      - bin/server
    cmds:
      - go build -o bin/server ./cmd/api

  # Method: checksum (default) or timestamp
  assets:
    sources:
      - src/assets/**/*
    generates:
      - dist/assets/**/*
    method: timestamp
    cmds:
      - cp -r src/assets dist/
```

## Conditionals and Status

```yaml
tasks:
  install:
    desc: Install dependencies
    status:
      - test -d node_modules
    cmds:
      - npm install

  migrate:
    desc: Run migrations
    preconditions:
      - sh: test -f .env
        msg: ".env file is required"
      - sh: command -v migrate
        msg: "migrate tool not installed"
    cmds:
      - migrate up
```

## Platform-Specific Commands

```yaml
tasks:
  open:
    desc: Open the app
    cmds:
      - cmd: open http://localhost:8080
        platforms: [darwin]
      - cmd: xdg-open http://localhost:8080
        platforms: [linux]
```

## Internal Tasks and Aliases

```yaml
tasks:
  build:
    aliases: [b]
    desc: Build the app
    cmds:
      - go build .

  # Internal tasks don't show in --list
  generate-proto:
    internal: true
    cmds:
      - protoc --go_out=. *.proto
```

## Includes

```yaml
# Taskfile.yml
version: '3'

includes:
  docker: ./taskfiles/Docker.yml
  db: ./taskfiles/Database.yml
  # With directory override
  api:
    taskfile: ./api/Taskfile.yml
    dir: ./api
```

```bash
# Run included tasks with namespace
task docker:build
task db:migrate
task api:test
```

## Directory and Shell

```yaml
tasks:
  frontend:
    dir: ./frontend
    cmds:
      - npm run build

  # Run in specific shell
  script:
    cmds:
      - cmd: |
          set -euo pipefail
          echo "strict mode"
        shell: bash
```

## Interactive and Silent

```yaml
tasks:
  deploy:
    prompt: "Deploy to production?"
    cmds:
      - ./deploy.sh

  quiet:
    silent: true
    cmds:
      - echo "this won't echo the command itself"

  # Ignore errors
  cleanup:
    cmds:
      - cmd: rm -rf tmp/
        ignore_error: true
      - echo "done"
```

## Dotenv

```yaml
version: '3'

dotenv: ['.env', '.env.local']

tasks:
  run:
    cmds:
      - echo $DATABASE_URL
```

## Useful Patterns

```yaml
version: '3'

vars:
  APP: myapp
  GIT_SHA:
    sh: git rev-parse --short HEAD

tasks:
  default:
    cmds:
      - task: lint
      - task: test
      - task: build

  dev:
    desc: Run with live reload
    deps: [install]
    cmds:
      - air -c .air.toml

  lint:
    desc: Lint code
    cmds:
      - go vet ./...
      - golangci-lint run

  test:
    desc: Run tests
    cmds:
      - go test -race -cover ./...

  build:
    desc: Build binary
    sources: ['./**/*.go', 'go.mod']
    generates: ['bin/{{.APP}}']
    cmds:
      - go build -ldflags "-X main.version={{.GIT_SHA}}" -o bin/{{.APP}} ./cmd/api

  docker:
    desc: Build Docker image
    cmds:
      - docker build -t {{.APP}}:{{.GIT_SHA}} .

  clean:
    desc: Remove build artifacts
    cmds:
      - rm -rf bin/ dist/ tmp/
```
