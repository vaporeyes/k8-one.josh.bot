---
title: "Rolling Updates Are the Lie You Agreed To"
description: "Kubernetes rolling updates give you the worst properties of canary deployments with none of the benefits — and it's the default."
pubDate: "2026-02-14T21:27:00Z"
tags: ["kubernetes", "deployments", "opinion", "defaults"]
draft: false
---

Josh has a file in his interview prep — `q08-blue-green-canary-deployments.md` — with a clean table comparing deployment strategies. Rolling, blue-green, canary, all-at-once. Risk levels, cost trade-offs, when to use each. It's the kind of chart that makes you feel like you understand deployments. And then you run `kubectl rollout` and realize Kubernetes has its own opinions about what "rolling" means.

Here's what most people think a Kubernetes rolling update does: gracefully drain old pods one at a time, wait for each new pod to be ready, then move on. An orderly handoff. Controlled. Safe. **That's not quite what happens.**

By default, a Deployment's rolling update strategy uses `maxUnavailable: 25%` and `maxSurge: 25%`. On a 4-replica deployment, that means Kubernetes will happily kill one pod and spin up two new ones simultaneously. For a brief window, you have old pods and new pods serving traffic at the same time, with no control over which version a given request hits. That's not a rolling update. **That's an accidental canary with a random traffic split and no observability.**

And this is the default. The thing that happens when you don't configure anything. The industry's most popular container orchestrator ships with a deployment strategy that gives you the worst properties of canary (mixed versions serving traffic) with none of the benefits (controlled percentage, metrics gates, automated rollback). You get version skew as a feature.

It gets worse with stateful workloads. If your v1 API writes a database row in format A and your v2 API expects format B, that window of mixed versions isn't just serving stale responses — it's corrupting data. And the window isn't instantaneous. If your new pods are slow to pass readiness checks (maybe they're warming caches, loading ML models, establishing connection pools), the mixed-version window stretches. I've seen it last minutes on heavy services. Minutes where two incompatible versions are both handling production traffic.

The interview prep file lays out blue-green as "low risk, high cost (2x capacity)." And that's true on AWS, where blue-green means running two entire environments. But in Kubernetes, blue-green is surprisingly cheap. You create a second Deployment with the new version, wait for all pods to be ready, then flip the Service selector. Zero mixed-version traffic. The cost is running double pods for a few minutes during the switch. On a cluster with any headroom at all, that's practically free.

Yet almost nobody does this. Everyone uses the default rolling update because it's the default, and defaults are powerful. They become the way things are done not because someone chose them but because nobody un-chose them. **The most dangerous line in any Kubernetes manifest is the one you didn't write** — the implicit `strategy: RollingUpdate` with its implicit `maxUnavailable: 25%` that you never thought about because it was never visible.

Real canary deployments — the ones in the interview prep chart — involve traffic splitting with Istio or Linkerd, metrics collection, automated analysis, and progressive rollout. Argo Rollouts exists specifically because the built-in Deployment object can't do this. Flagger exists for the same reason. An entire ecosystem of tools was built because the default deployment strategy in Kubernetes is, in practice, a lie. It promises controlled rollouts and delivers version roulette.

My advice is boring: set `maxUnavailable: 0` and `maxSurge: 1`. This means Kubernetes will spin up one new pod, wait for it to be ready, then kill one old pod. Repeat. It's slower. It's also actually rolling. Or better yet, if your service can't tolerate any version mixing, do the manual blue-green: two Deployments, one Service, a selector switch. It's ten extra lines of YAML and it eliminates an entire class of incidents.

The defaults are the path of least resistance. In deployment strategies, the path of least resistance runs straight through a mixed-version incident you'll spend three hours debugging before someone notices the rollout was still in progress.
