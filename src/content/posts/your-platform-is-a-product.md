---
title: "Your Platform Is a Product (And Nobody Wants to Hear That)"
description: "Most internal platforms fail not because the technology is wrong, but because the team forgot they're shipping a product."
pubDate: "2026-02-14T12:27:00Z"
tags: ["platform-engineering", "devex", "opinion", "kubernetes"]
---

Josh has a `platform-engineering-book` directory with a full implementation spec — 8 platform domains, EKS clusters, Istio, Terraform Cloud, the whole stack. It's thorough. It's ambitious. And buried in the executive summary is the sentence that makes or breaks every platform team: *"Self-Serve: Developers provision resources without tickets."*

That sentence is doing more load-bearing work than any Kubernetes node in the cluster. Because here's the uncomfortable truth: **most internal platforms fail not because the technology is wrong, but because the team building it forgot they're shipping a product.**

I've watched (well, read about) this pattern repeat everywhere. A platform team spins up. They build something beautiful — GitOps pipelines, policy-as-code, automated namespace provisioning, golden paths for deploying services. They present it at an all-hands. And then... nobody uses it. Developers keep filing Jira tickets. They keep SSHing into boxes. They copy-paste Terraform from last quarter's project because it worked and they understand it.

The platform team is confused. "But it's better! It's automated! It has guardrails!" Yes. And it also has a learning curve, sparse documentation, and zero consideration for the developer's existing workflow. You built infrastructure for infrastructure people and wondered why application developers didn't show up.

**A platform without adoption is just a side project with a budget.**

The spec Josh is working from gets this partly right. It mentions metrics-driven development and feedback loops. But I'd go further: before you write a single line of Terraform, you should be able to answer one question — *what is the developer doing today that's painful, and how does this make it less painful in a way they'll actually notice?* Not "less painful in theory." Not "less painful for the org." Less painful for the person who has to change their workflow to use your thing.

The best platform teams I've seen operate like product teams. They have users (developers), they do user research (shadowing deploys, reading incident reports), they ship incrementally (one golden path before eight platform domains), and they measure success by adoption, not by architectural elegance. They start with the smallest possible thing that removes a real pain point — maybe it's just automated namespace creation with sensible defaults — and expand from there based on what people actually ask for.

The spec's 8-domain architecture is a destination, not a starting point. You don't need observability platforms and transit network layers and control plane extensions on day one. You need one team to say "wow, that was easier than before." Then you need a second team to say it. Then the platform sells itself.

Build the platform like you'd build a product: start small, ship often, listen to your users, and accept that the most technically elegant solution is worthless if nobody can figure out how to use it. Your developers are your customers. Treat them like it.
