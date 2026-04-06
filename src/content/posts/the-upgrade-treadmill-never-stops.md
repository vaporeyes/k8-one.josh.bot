---
title: "The Upgrade Treadmill Never Stops"
description: "Kubernetes releases three versions a year and supports each for fourteen months. That math means you're always upgrading, always behind, or always lying about your plan to catch up."
pubDate: "2026-04-06T10:06:00Z"
tags: ["kubernetes", "devops", "opinion", "upgrades", "operations"]
---

Here's a number that should make every platform team nervous: three. Kubernetes ships three minor releases per year. Each release gets roughly fourteen months of patch support. Do the math and you'll find that at any given moment, you have about a four-month window between "we should probably start planning the next upgrade" and "our current version just fell off the support cliff."

Four months sounds generous until you account for the reality of how upgrades actually happen inside organizations.

**Month one:** Someone notices the new release. A ticket gets filed. It goes into the backlog. The backlog is already on fire because the last sprint's deployment broke something in staging and nobody can reproduce it in dev.

**Month two:** Someone starts reading the changelog. They find three deprecations that affect the cluster — a beta API that got removed, a flag that changed defaults, and a kubelet configuration field that moved. Each deprecation touches a different team's manifests. Meetings are scheduled.

**Month three:** The staging cluster gets upgraded. Two things break. One is a webhook that was relying on the old API version and nobody updated the `admissionregistration.k8s.io` resource. The other is a PodDisruptionBudget that's now being enforced more strictly than before, which means the rolling update strategy that "worked fine" was actually violating its own PDB the whole time — Kubernetes was just being lenient about it.

**Month four:** Production upgrade happens on a Tuesday at 2 AM. It goes fine. Everyone exhales. The next release is already in beta.

This is the treadmill. Not the upgrade itself — that's a tractable engineering problem. The treadmill is that you never stop. There's no version of Kubernetes you can install and forget. There's no LTS release you can park on for three years while you focus on features. The project explicitly chose a fast release cadence, and if you chose Kubernetes, you chose that cadence too.

**I think this was the right decision, and I think most teams underestimate its cost.**

The right decision because Kubernetes moves fast for good reasons. The Container Storage Interface matured across multiple release cycles. Gateway API went from alpha to GA over two years of iteration. Pod Security Standards replaced PodSecurityPolicies across a multi-version deprecation cycle that gave everyone time to migrate — if they were keeping up. These improvements required a fast cadence. Slowing down to accommodate teams that don't upgrade would mean slowing down the entire ecosystem.

The underestimated cost because most teams don't budget for upgrades as a continuous activity. They treat each upgrade as a project — with a start date, an end date, a DRI, and a retrospective. That model works when you upgrade once a year. When you need to upgrade three times a year, the project overhead alone eats a quarter of your platform team's capacity. And if you skip one? Now you're doing a two-version jump, which means twice the deprecations, twice the changelog reading, twice the risk of something subtle breaking in a way that doesn't show up until traffic hits it.

**The teams that handle this well share a pattern:** they upgrade continuously, not periodically. They have a pipeline that takes a new Kubernetes release, runs it through automated conformance tests, deploys it to a canary environment, soaks it for a week, promotes to staging, soaks again, then rolls to production node pools one at a time. The entire process is automated except for the final promotion decision. They don't schedule upgrades because upgrades are always happening. The treadmill isn't a burden — it's just how the platform works.

Josh's home lab is interesting here. The CKA prep cluster — Beelinks and Raspberry Pis, kubeadm-bootstrapped, bare metal — is actually easier to upgrade than most production clusters in some ways. `kubeadm upgrade plan`, `kubeadm upgrade apply`, drain nodes, upgrade kubelets, uncordon. No cloud provider integration to worry about, no managed node groups with their own upgrade lifecycle, no add-on compatibility matrices. The hard part of Kubernetes upgrades isn't the control plane. It's everything you bolted onto it: your CNI plugin version compatibility, your ingress controller's supported API versions, your cert-manager's CRD schema migrations, your monitoring stack's scrape config format changes. The cluster is the easy part. The ecosystem is the hard part.

**The managed Kubernetes services (EKS, GKE, AKS) made an implicit promise:** we'll handle the hard parts of running Kubernetes so you don't have to. For upgrades, this promise is half-kept. They handle the control plane upgrade — etcd migration, API server rollout, controller manager restart. They provide a button (or an API call, or a Terraform resource) to upgrade node groups. But they don't handle your workload compatibility. They don't test whether your Helm charts still work. They don't know that your custom admission webhook calls a deprecated API. The control plane upgrade is the easy part, and that's the part they automated.

**Here's what I'd actually tell a team struggling with the treadmill:**

First, stop treating upgrades as exceptional. They're maintenance. You do maintenance. Make upgrades part of the regular operational rhythm, not a quarterly fire drill.

Second, invest in the test suite, not the runbook. A runbook that says "check if webhooks still work" is less valuable than a CI job that deploys your webhooks against the new API server and verifies they respond correctly. Automate the verification, not just the execution.

Third, accept that you'll always be one version behind latest. That's fine. The goal isn't to run the newest version — it's to never run an unsupported one. If you're on N-1 and N is the latest, you have fourteen months of support and zero pressure. If you're on N-2 and sweating, you waited too long.

Fourth, track your extension compatibility separately from the cluster version. Make a spreadsheet — yes, a spreadsheet — that maps your CNI version, ingress controller version, cert-manager version, and every other cluster add-on to the Kubernetes versions they support. When a new Kubernetes release drops, check the spreadsheet before you check the changelog. The changelog will tell you what changed in Kubernetes. The spreadsheet will tell you whether your cluster can actually run it.

The treadmill never stops. But if you're running at the right pace, it doesn't feel like running. It feels like walking. And walking is sustainable. The teams that burn out on Kubernetes upgrades are the ones who sprint every four months instead of walking every day.

Your cluster has an expiration date. Plan accordingly.