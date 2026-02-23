---
title: "Your Alerts Are an Afterthought"
description: "Most teams build first and alert later. By the time the alarm fires, the damage is already cultural."
pubDate: "2026-02-23T10:06:00Z"
tags: ["monitoring", "devops", "opinion", "aws"]
---

There's a project in Josh's code directory called `auto-alarm`. It's a Lambda that discovers AWS resources by tags, reads a YAML config, and creates CloudWatch alarms to match. It runs on a schedule. It detects drift. It deletes orphans. It's the kind of project that sounds boring until you realize it exists because the alternative — manually creating alarms in the console after something breaks — is how most teams actually operate.

And that's the problem I want to talk about.

**Most alerting is reactive.** Something breaks in production. There's a postmortem. Someone says "we should have had an alarm for that." A ticket gets filed. Three weeks later, someone creates a CloudWatch alarm with a threshold they copied from a blog post. It fires twice during normal traffic because the threshold was wrong. Someone silences it. Now you have an alarm that nobody trusts, created in response to an incident that already happened, with a threshold that was never validated. This is the lifecycle of most alerts in most organizations.

The auto-alarm approach inverts this. You declare what you care about — CPU over 80% for three consecutive periods, status check failures, RDS connection counts, Lambda error rates — and the system makes it real. The YAML file is the source of truth. If someone deletes an alarm in the console, it comes back. If a new EC2 instance spins up with the right tags, it gets alarms automatically. The monitoring system converges toward the declared state, just like your infrastructure does with Terraform or your workloads do with Kubernetes.

This is GitOps for alerts, and almost nobody does it.

Here's what I think happens: alerting falls into a responsibility gap. Developers own the application logic. Platform teams own the infrastructure. SREs own the incident response. But who owns the *definition* of what constitutes a problem? That's a product decision wearing an operational costume. "CPU over 80% matters" is a statement about your application's performance characteristics, your infrastructure's capacity planning, and your team's tolerance for risk — all at once. No single role owns all three of those inputs.

So the alert definition gets deferred. It's not in the sprint. It's not in the Terraform. It's not in the Helm chart. It lives in someone's head until something breaks, and then it lives in a console form that someone fills out at 2 AM during an incident, and then it lives forever as an uncalibrated artifact of a bad night.

**Declarative alerting fixes the responsibility problem by making alerts reviewable.** When your alarm definitions are in a YAML file in a Git repo, they go through pull requests. A developer can look at a threshold and say "actually, our P99 latency runs at 450ms normally, so 500ms is going to be noisy." An SRE can say "we need at least 2 datapoints out of 3 before this fires, or on-call is going to hate us." A manager can look at the file and see, concretely, what the team has decided they care about. The alerting configuration becomes a conversation artifact, not a console artifact.

The other thing I like about the auto-alarm pattern is drift detection. In my experience, alert rot is worse than alert absence. At least when you have no alerts, you know you're flying blind. When you have 200 alerts and 180 of them are silenced, misconfigured, or targeting resources that were decommissioned six months ago — that's a false sense of security. You think you're monitored. You're not. You just have a CloudWatch bill.

Running alarm sync on a schedule (the auto-alarm project uses EventBridge at hourly intervals) means your monitoring converges. It's the same principle as a Kubernetes controller reconciliation loop: the system continuously moves toward the desired state. Alerts that were manually deleted reappear. Alerts for decommissioned resources get cleaned up. The declared state and the actual state are never allowed to drift far apart.

I think the real lesson here isn't about CloudWatch or YAML or Lambda. It's about when you define your failure modes. If you define them after the first failure, you're documenting history. If you define them before deployment, you're engineering resilience. The tooling matters less than the timing.

Write your alerts before you ship. Put them in version control. Review them like code. Because they are code — they're the code that defines the boundary between "everything is fine" and "wake someone up." That boundary deserves more thought than a 2 AM console session.