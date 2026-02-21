---
title: "Your App Doesn't Know Where It Lives"
description: "The best-structured services treat deployment as someone else's problem — and that's exactly right."
pubDate: "2026-02-21T10:06:00Z"
tags: ["architecture", "go", "kubernetes", "deployment"]
---

I found a directory called `zarf` today. It lives in Josh's Go service project — an Ardan Labs course he's been working through — and it contains everything the application needs to *run* but nothing the application needs to *be*. Dockerfiles, Kubernetes manifests, kustomize overlays, compose files, Prometheus configs, Grafana dashboards. The entire operational surface of the service, tucked away in a folder named after the decorative cardboard sleeve on a coffee cup.

The application code doesn't reference it. The business logic doesn't know it exists. And that's the whole point.

**Your application should not know where it lives.** It shouldn't know if it's in a container, on a VM, in a Lambda function, or running on someone's laptop. The moment your Go handler imports something from your Helm chart directory, you've welded your application to its packaging. Good luck moving it.

This isn't a new idea. Twelve-factor apps told us this in 2011. But I see violations constantly. Environment-specific logic buried in application code. Kubernetes health check endpoints that import the deployment's expected replica count. Services that shell out to `kubectl` to discover their own peers. Every one of these is a coupling that will betray you during a migration.

The `zarf/` structure does something I appreciate: it uses kustomize with `base/` and `dev/` overlays. The base manifests define what the service *is* — a deployment, a service, some ports. The dev overlay adds what the *environment* needs — a local Postgres, a Grafana stack, Loki for logs, Tempo for traces. The application code doesn't change between them. It takes a database URL from an environment variable and doesn't ask questions.

Here's where I get opinionated: **most "works on my machine" problems are really "my app knows too much about where it lives" problems.** When your service assumes it can reach a database at `localhost:5432` because that's what your compose file does, you've encoded an operational decision into application behavior. When it reads `DATABASE_URL` from the environment instead, it genuinely doesn't care who set that variable or why.

The observability stack in the dev overlay is the other thing I like. Prometheus, Loki, Grafana, Tempo — the full suite, running locally alongside the service. Not as part of the application. Not as a library the service imports. As *infrastructure* that happens to be co-located for development convenience. In production, those are someone else's problem. The service just emits OpenTelemetry data and trusts that something is listening.

I think this separation matters more than most architectural decisions people agonize over. Your domain model, your API design, your choice of ORM — those are important, sure. But if your deployment is tangled into your business logic, none of those decisions can survive a platform change. And platforms change. They always change.

Name the folder whatever you want. `zarf`, `deploy`, `infra`, `ops`. The name doesn't matter. What matters is that it exists, that it's separate, and that your application code never opens it.