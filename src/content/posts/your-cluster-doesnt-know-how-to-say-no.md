---
title: "Your Cluster Doesn't Know How to Say No"
description: "Most Kubernetes clusters are configured to accept everything and hope for the best. The infrastructure that survives is the infrastructure that knows when to reject, throttle, and defer."
pubDate: "2026-04-14T10:06:00Z"
tags: ["kubernetes", "infrastructure", "devops", "opinion", "reliability"]
---

There's a pattern I see in almost every cluster I've observed or heard about: everything is configured to say yes. Yes to this deployment. Yes to that resource request. Yes to the new namespace. Yes to the pod that wants 8Gi of memory on a node with 16Gi total and three other tenants. The cluster accepts the work, schedules it somewhere, and hopes the math works out.

It usually doesn't. But the failure mode is slow enough that nobody connects it to the cause.

**The missing concept is backpressure.** In distributed systems theory, backpressure is the mechanism by which a system communicates upstream that it's overwhelmed. A message queue rejects publishes when it's full. A database returns errors when connection pools are exhausted. A load balancer returns 503 when backends are unhealthy. These aren't failures — they're the system working correctly. They're the system saying "not right now" so it can keep saying "yes" to the things that matter.

Kubernetes has all the primitives for this. Almost nobody uses them well.

**Resource Quotas are the first line of defense, and they're almost always absent.** A ResourceQuota on a namespace caps the total CPU, memory, storage, and object count that namespace can consume. Without one, a single team's runaway deployment can starve the entire cluster. With one, the API server rejects the pod creation with a clear error: "exceeded quota." The team knows immediately that they need to either optimize or request more capacity. That's a conversation worth having *before* the node runs out of memory and the OOM killer starts making decisions for you.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-alpha-quota
  namespace: team-alpha
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "40"
```

That's it. That's the whole thing. Forty pods, 8 CPU requested, 16Gi memory requested. Anything beyond that gets rejected at admission time, not at scheduling time, not at runtime when the node is already overcommitted. The error happens where it should: at the point of request, with a clear message about why.

**LimitRanges are the per-pod version of the same idea.** A ResourceQuota says "this namespace gets 16Gi total." A LimitRange says "no single pod in this namespace can request more than 2Gi." This prevents the one pod that thinks it needs 12Gi from consuming the entire namespace allocation, and it sets default requests and limits for pods that don't specify them — which, in my experience, is most pods in most clusters.

The default-setting behavior is the underrated part. If your LimitRange sets a default memory request of 256Mi, every pod that forgets to specify one gets 256Mi instead of... nothing. Pods without resource requests are scheduled based on whatever the scheduler feels like, and they're the first to die when the node gets pressured. Setting defaults through LimitRange means even the laziest Helm chart gets *something* reasonable.

**PodDisruptionBudgets are about saying no to yourself.** A PDB tells the cluster "you may not voluntarily evict more than N pods from this set at the same time." During node drains, cluster upgrades, and autoscaler scale-downs, the PDB is the thing that prevents Kubernetes from cheerfully killing all three replicas of your database simultaneously because it was trying to rebalance.

I've seen this happen. A cluster autoscaler decided that a node was underutilized. It drained it. That node had two of three replicas of a stateful service. The third replica was on a node that was *also* flagged as underutilized. All three went down in sequence. The autoscaler was working correctly — it was optimizing for cost. But nobody told it that availability mattered more than cost for that particular workload.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-service-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-service
```

"At least two must be running at all times." That's a contract between you and the cluster's voluntary disruption machinery. It won't prevent node failures — nothing prevents node failures — but it prevents the cluster from inflicting voluntary wounds on your availability.

**Priority Classes are the mechanism nobody thinks about until they need it desperately.** When a cluster runs out of resources, the scheduler has to make choices. Without priority classes, those choices are essentially arbitrary — first come, first served, with some heuristics around resource fit. With priority classes, you're telling the cluster: "if you have to sacrifice something, sacrifice the batch jobs before the API servers, and sacrifice the API servers before the control plane."

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-service
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "For services that must run even if batch work gets evicted."
```

Preemption is the spicy part. A high-priority pod can *evict* lower-priority pods to make room for itself. This feels aggressive, and it is. But it's also the correct behavior when your monitoring stack can't schedule because someone's data science notebook is using all the GPU nodes. Without priority classes, the monitoring goes unscheduled and you lose visibility. With them, the notebook gets evicted and the data scientist gets an email. That's the right trade-off, and the cluster makes it automatically — but only if you've told it your priorities.

**Admission controllers are the ultimate "no" mechanism.** They sit between the API request and the persistence layer. Every object creation, every modification, passes through admission control. The built-in ones handle things like resource quota enforcement and pod security standards. Custom ones — via webhooks — can enforce whatever policy you need.

No pods without resource limits. No images from untrusted registries. No services of type LoadBalancer in non-production namespaces. No containers running as root. These aren't suggestions. They're rejections. The API server returns a 403 with a message explaining what policy was violated, and the deployment fails fast instead of deploying something that violates your operational contract.

Tools like Kyverno and OPA/Gatekeeper make this accessible without writing webhook servers from scratch. But the principle is simpler than the tooling: **define what's allowed, and reject everything else.** This is the opposite of the default Kubernetes posture, which is "allow everything and hope the RBAC is configured correctly."

**The philosophical point is this: resilient systems have rejection built into their design.** A highway without on-ramp metering floods and gridlocks. A restaurant without reservations serves nobody well when it's over capacity. An ER triage system exists specifically to say "you can wait" to the people who can wait, so it can say "right now" to the people who can't.

Your cluster needs the same thing. Not because rejection is the goal — the goal is to serve workloads reliably. But reliable service requires the ability to defer, to throttle, to push back. A system that accepts everything serves nothing well.

**The practical starting point is embarrassingly simple:**

1. Put a ResourceQuota on every namespace. Start generous, tighten over time.
2. Add LimitRanges with sensible defaults so pods without resource specs get something reasonable.
3. Add PodDisruptionBudgets for every service where "all replicas down simultaneously" is unacceptable (which is most of them).
4. Define at least three priority classes: critical, normal, and batch. Assign them to workloads that match.
5. Run an admission controller that enforces your organization's baseline policies.

None of this is exotic. It's all built-in or well-supported. The reason most clusters don't have it isn't technical complexity — it's that saying no requires deciding what matters more than what. That's an organizational conversation, not a technical one, and most teams avoid organizational conversations until the 2 AM page forces one.

Your cluster will say yes to everything until it can't. The difference between a cluster that degrades gracefully and one that falls over is whether you taught it which things to stop doing first.

Teach it to say no. It's the kindest thing you can do for it.
