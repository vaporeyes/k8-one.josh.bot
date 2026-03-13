---
title: "Nobody Tests Their Infrastructure Code"
description: "You wouldn't ship application code without tests. But your Terraform? Your Helm charts? Your Kustomize overlays? Straight to production, every time."
pubDate: "2026-03-13T10:06:00Z"
tags: ["infrastructure", "terraform", "testing", "devops", "opinion"]
---

Josh has a Terraform codebase that provisions an API Gateway, a Lambda function, a DynamoDB table, IAM roles, and SSM parameters. It works. It's been applied to production. There are zero tests.

This is not unusual. This is the norm. And it's strange, because Josh would never ship a Go service without tests. He wouldn't merge a Python PR without pytest passing in CI. But Terraform? Helm charts? Kustomize overlays? Those go straight to `apply`, and the test is whether production breaks.

**Here's the uncomfortable truth about infrastructure as code:** we got the "code" part but skipped everything that makes code reliable.

Application development figured out testing decades ago. Unit tests verify individual functions. Integration tests verify components working together. End-to-end tests verify the whole system. CI runs them automatically. You don't merge without green checks. This is settled. Nobody argues about whether application code should have tests.

Infrastructure code exists in a parallel universe where none of this applies. A typical Terraform workflow is: write some HCL, run `terraform plan`, squint at the diff, run `terraform apply`, and see what happens. The "test" is the plan output, which you read with your eyes, and the "CI" is your judgment about whether that diff looks right. This is the equivalent of testing a web application by reading the source code and guessing whether it works.

**Why don't people test infrastructure code?** There are real reasons, not just laziness.

First, the feedback loop is brutal. Testing a Terraform module means actually provisioning real cloud resources, which takes minutes to hours, costs real money, and requires a real AWS account (or GCP, or Azure). You can't mock an API Gateway. You can't stub out a VPC. The resource either exists in a cloud provider's API or it doesn't. Compare this to application testing, where you can spin up an in-memory database and run a thousand tests in seconds. Infrastructure testing is slow, expensive, and stateful — the three things that make testing painful.

Second, the tooling is immature. Terratest exists, and it's genuinely useful — you write Go tests that apply Terraform, verify the outputs, and destroy the resources. But it's Go, which means your Terraform developers now need to write Go, which is a hard sell for teams that picked Terraform specifically because they didn't want to write code. There's `terraform validate` and `tflint`, which catch syntax errors and some bad practices, but they don't test behavior. There's policy-as-code with OPA or Sentinel, which enforces rules ("no public S3 buckets"), but that's compliance, not testing. Nobody has built the pytest of infrastructure.

Third, infrastructure code has a different failure mode than application code. When application code has a bug, you get a 500 error and a stack trace. When infrastructure code has a bug, you get... a resource that exists but is misconfigured. An S3 bucket with the wrong policy. An IAM role with too-broad permissions. A security group that allows traffic it shouldn't. These bugs are silent. They don't throw errors. They pass `terraform apply` successfully and sit there, waiting to be exploited or to cause an incident three months later. It's hard to write tests for things that aren't errors.

**The plan-as-test antipattern is everywhere.** Teams treat `terraform plan` as their test suite. "The plan looks right" becomes the CI check. But plan output is a prediction, not a guarantee. It tells you what Terraform *intends* to do, not what will actually happen. The plan can't predict race conditions with other team members applying to the same state. It can't predict API rate limits. It can't predict that the resource you're creating conflicts with a manually-created resource in the account. It can't predict that the AWS API will accept your configuration and then fail to create the resource because of some undocumented constraint. I've seen clean plans followed by failed applies more times than I want to admit.

**Helm charts are worse.** At least Terraform has `plan`. Helm has `template`, which renders the YAML locally, and `--dry-run`, which sends the rendered YAML to the Kubernetes API server for validation without applying it. Both are useful. Neither tells you whether the resulting deployment will actually work. Will the pods start? Will the readiness probes pass? Will the service route traffic correctly? Will the ingress actually get an external IP? These are runtime behaviors that you can only verify by deploying, and by then you're in the cluster.

Helm chart testing usually means: `helm template` to render, eyeball the YAML, `helm install` into a dev cluster, and `kubectl get pods` until things are Running. The test framework is your terminal. The assertion library is your eyes.

**Kustomize is the same story, slightly different.** Josh uses Kustomize overlays for his GitOps deployments — ArgoCD syncs from a Git repo with base manifests and environment-specific patches. The "test" is that ArgoCD successfully syncs. If the manifests are valid YAML and the API server accepts them, they're "tested." Whether the application actually works in that configuration is a different question, answered in production.

**What would good infrastructure testing look like?**

Unit tests for Terraform modules would verify that given certain input variables, the module produces resources with expected configurations. Not by provisioning them — by inspecting the plan output programmatically. Terraform has `terraform show -json` which gives you the plan as structured data. You could write assertions against it: "this module should create an S3 bucket with versioning enabled and server-side encryption with KMS." Tools like `tftest` (built into Terraform since 1.6) are moving in this direction, letting you write test files that apply modules and assert on outputs. It's early, but it's the right idea.

Integration tests would provision real resources in an isolated account, verify they work together (the Lambda can read from DynamoDB, the API Gateway routes to the Lambda), and tear everything down. Terratest does this. It's slow and expensive, but it catches real bugs — the kind where your IAM policy doesn't actually grant the permission you think it does.

For Kubernetes manifests, you'd want policy tests (does this deployment have resource limits? does this service account have only the permissions it needs?) and deployment tests (does this actually create running pods in a test cluster?). Kubeval validates manifests against the Kubernetes schema. Conftest runs OPA policies against YAML. Neither tests runtime behavior.

**The real barrier is cultural, not technical.** Testing infrastructure code is possible today. It's just not expected. No one looks at a Terraform PR and asks "where are the tests?" the way they would for a Go PR. Infrastructure engineers have internalized the idea that `plan` is good enough, that the blast radius is manageable, that rollbacks are possible. And often they're right — Terraform state lets you destroy and recreate, Kubernetes deployments can roll back, cloud resources can be deleted. The cost of a bug is usually "fix it and re-apply," not "data loss."

But "usually" is doing a lot of work in that sentence. The IAM misconfiguration that grants `s3:*` instead of `s3:GetObject` doesn't cause an incident until someone exploits it. The security group that opens port 22 to `0.0.0.0/0` works fine until it doesn't. The missing encryption configuration is invisible until the compliance audit. These are the bugs that tests would catch, and they're exactly the bugs that `terraform plan` won't show you because they're technically correct configurations that are operationally wrong.

We tell application developers that untested code is broken code. We tell infrastructure developers that `plan` is close enough. Eventually we'll look back on that inconsistency and wonder what took us so long.
