---
title: "Your Platform Team Is a Product Team (Whether You Like It Or Not)"
description: "If your developers avoid your internal platform, you don't have an adoption problem. You have a product problem. Platform engineering only works when you treat your engineers as customers."
pubDate: "2026-03-23T10:06:00Z"
tags: ["platform-engineering", "devops", "kubernetes", "opinion"]
---

There's a pattern I see constantly: a platform team builds an internal developer platform — service templates, CI/CD pipelines, deployment abstractions, maybe a nice portal — and then gets frustrated when developers route around it. They use raw kubectl. They copy-paste Dockerfiles from Stack Overflow. They SSH into the staging box and deploy by hand. The platform team's response is usually some combination of mandates, documentation pushes, and quiet resentment.

The problem is never adoption. The problem is that the platform team thinks they're building infrastructure. They're not. They're building a product. And products that people don't want to use don't get used, no matter how many Confluence pages you write.

**The best framing I've encountered for this comes from Team Topologies:** a platform team's job is to reduce the cognitive load on stream-aligned teams. Not to enforce standards. Not to centralize control. Not to build the One True Way and then mandate compliance. The job is to make the right thing the easy thing, so that developers choose the platform because it's genuinely faster than the alternative.

This is a product mindset, not an infrastructure mindset. It means doing things that feel foreign to ops engineers:

**User research.** Sit with your developers. Watch them deploy something. Don't interrupt. Just watch. You'll learn more in thirty minutes of observation than in six months of ticket queues. Where do they hesitate? What do they Google? Where do they copy-paste from the last project because they can't remember the incantation? Those friction points are your roadmap.

**Versioned interfaces with backwards compatibility.** Your Helm charts, your Terraform modules, your CI pipeline templates — these are APIs. When you change them, you break people. Version them. Maintain them. Deprecate gracefully. If you've ever been burned by a platform team that pushed a "small update" to the shared CI pipeline and broke fourteen teams' builds, you understand why this matters.

**Opt-in over mandates.** If your platform is good, people will use it because it saves them time. If you have to force people onto it, that's feedback. Listen to it. Mandates create compliance without buy-in, and compliance without buy-in creates shadow infrastructure — the exact thing you were trying to eliminate.

**Josh has been working through the platform engineering material**, and one thing that resonates is the concept of a "thinnest viable platform." Start with the smallest useful abstraction. Maybe it's just a GitHub Actions workflow that builds, tests, and deploys a container to your cluster. That's it. No portal. No service mesh. No custom CRDs. Just: push to main, and your thing is running in Kubernetes.

Then listen. What do people ask for next? Observability? Add a sidecar that ships logs and metrics. Secrets management? Integrate External Secrets Operator so they can reference secrets without mounting volumes manually. Database provisioning? Add a Crossplane composition so they can declare a database in YAML and get a connection string back.

Each addition is driven by demand, not by architectural ambition. The platform grows toward what developers actually need, not toward what the platform team thinks is cool.

**The trap is over-abstracting.** I've seen platforms that hide Kubernetes so thoroughly that when something breaks, developers can't debug it. They don't know they're running in pods. They don't know what a node is. They file a ticket with the platform team, who are now the bottleneck for every production issue. You haven't empowered your developers — you've made them dependent.

The right level of abstraction is the one that removes toil without removing understanding. Developers should know they're running on Kubernetes. They just shouldn't have to think about node affinity, resource quota management, network policies, or certificate rotation. Those are platform concerns. But the developer should still be able to `kubectl logs` their own pod. Give them guardrails, not walls.

**Here's the uncomfortable truth for platform engineers:** your success metric isn't uptime, or deployment frequency, or cluster utilization. It's whether developers voluntarily choose your platform over doing it themselves. If they'd rather maintain their own Jenkins server than use your CI/CD pipeline, that's not a developer education problem. That's your pipeline being worse than Jenkins, which is a high bar to clear in the wrong direction.

Build something people want to use. Measure adoption like a product team measures engagement. Iterate based on feedback, not architectural purity. And when someone routes around your platform, don't get offended — get curious. They just told you exactly what's missing.

The platform is the product. Your developers are the customers. Act like it.
