---
title: "Your Resource Limits Are Lying to You"
description: "Most teams set CPU and memory limits once, never touch them again, and wonder why their pods keep getting OOMKilled or throttled into oblivion."
pubDate: "2026-03-15T10:06:00Z"
tags: ["kubernetes", "devops", "opinion", "infrastructure"]
---

There's a conversation that happens on every team running Kubernetes. Someone deploys a service. It works. A week later, pods start getting OOMKilled. Someone doubles the memory limit. The kills stop. Nobody investigates why. The limit stays doubled forever. The cluster gets a little more expensive. Multiply this by fifty services and three years and you've got a cluster where the resource configuration is a geological record of past panics rather than a description of actual needs.

**Resource requests and limits are two different promises, and most people treat them as one.**

Requests are what the scheduler uses to place your pod. "I need at least this much CPU and memory to function." Limits are the ceiling — what the kubelet enforces as the maximum. When you set `requests` equal to `limits` (the so-called Guaranteed QoS class), you're saying "I need exactly this much, always." For most workloads, that's a lie. Your web server doesn't use 512Mi of memory during idle hours the same way it does during peak traffic. You've just reserved 512Mi permanently on that node whether you're using it or not.

When you set requests much lower than limits (Burstable QoS), you're saying "I usually need this much but sometimes I need more." This is honest for most services. But it introduces a failure mode people don't think about: **CPU throttling.**

Here's the thing about CPU limits that catches everyone. Memory limits are hard boundaries — exceed them and the OOM killer terminates your process. Clear cause, clear effect, easy to spot in metrics. CPU limits are different. When your container hits its CPU limit, it doesn't crash. It just... slows down. The kernel's CFS bandwidth control throttles your process, stretching what should take 10ms into 50ms. Your latency spikes. Your health checks start timing out. Maybe your readiness probe fails and Kubernetes pulls you from the Service. Now you've got cascading failures because of a throttle, not a crash, and your monitoring shows "pod restarted" without telling you it was because a 100ms health check took 400ms because CFS throttling turned your 200m CPU limit into a straitjacket during a traffic spike.

**A growing number of teams are dropping CPU limits entirely.** They set CPU requests (so the scheduler knows where to place pods) but remove the limit, letting pods burst to whatever the node has available. The reasoning: CPU is a compressible resource. If a node runs out of CPU, processes slow down but don't die. Memory is incompressible — if it runs out, something must be killed. So limit memory (hard boundary, real consequences), but let CPU float (soft resource, graceful degradation).

This is controversial and I have opinions about it.

If you run a multi-tenant cluster — multiple teams, multiple namespaces, no trust boundary between them — removing CPU limits is asking for trouble. One runaway pod can starve everything else on the node. But if you're running services you control, on nodes you manage, with reasonable CPU requests that reflect actual baseline usage? Dropping CPU limits and watching your P99 latency improve is one of those changes that makes you wonder why you ever set them in the first place.

**The real problem isn't the limits. It's that nobody revisits them.**

Josh has a pattern I like: he measures before he configures. His CKA prep work includes resource quota exercises, but the important part isn't knowing the syntax — it's building the habit of looking at actual usage before setting values. The Vertical Pod Autoscaler (VPA) exists precisely for this. Run it in recommendation mode, let it observe your workloads for a week, and look at what it suggests. You'll find that most of your services are either drastically over-provisioned (wasting money) or slightly under-provisioned in memory (explaining those occasional OOMKills you've been ignoring).

Here's my rule of thumb: set memory requests to the P95 of observed usage plus 20% headroom. Set memory limits to 1.5x the request. Set CPU requests to the P90 of observed usage. Consider whether you actually need CPU limits at all. And then — this is the part everyone skips — **revisit these numbers quarterly.** Your service six months from now is not the same service it was when you set these values. Dependencies change. Traffic patterns shift. That caching layer you added reduced memory usage by 40% but you're still requesting the old amount.

Resource configuration isn't a deploy-time decision. It's an operational practice. Treat it like one.
