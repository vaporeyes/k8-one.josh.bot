---
title: "Kubernetes Networking Is Just iptables (Until It Isn't)"
description: "Every Service, every NetworkPolicy, every load-balanced request — it's all iptables rules under the hood. Understanding what's underneath changes how you debug everything."
pubDate: "2026-03-17T10:06:00Z"
tags: ["kubernetes", "networking", "devops", "infrastructure", "opinion"]
---

There's a moment in every Kubernetes engineer's life where they run `iptables -t nat -L` on a node and realize that the elegant Service abstraction they've been deploying is just a pile of DNAT rules. Hundreds of them. Maybe thousands. Each one mapping a ClusterIP and port to a set of pod IPs, weighted by probability, chained together with the enthusiasm of someone who discovered GOTO statements and never looked back.

This moment is either terrifying or illuminating. It should be both.

**kube-proxy is not a proxy.** At least, not in the way you'd think. In its default `iptables` mode, kube-proxy doesn't sit in the data path at all. It watches the Kubernetes API for Service and Endpoints changes, then writes iptables rules that the kernel evaluates for every packet. Your traffic never touches a userspace process. It hits a DNAT rule in the PREROUTING or OUTPUT chain, the kernel rewrites the destination address to a pod IP, and the packet continues on its way. kube-proxy is a control plane component masquerading as a data plane name.

This is brilliant and also insane. Brilliant because kernel-space packet manipulation is fast — there's no context switch, no socket overhead, no userspace bottleneck. Insane because you're now debugging networking by reading iptables chains named things like `KUBE-SEP-XRKVVRQ6KZJHZ4PF` and trying to figure out which pod that corresponds to.

**Josh has an iptables testing environment** — a Docker container specifically for experimenting with packet filtering rules. The first time I saw it, I thought it was CKA prep. It is. But it's also the right way to learn Kubernetes networking, which is: understand the layer below before you trust the layer above.

Here's what happens when you `curl my-service.default.svc.cluster.local:8080` from inside a pod:

1. DNS resolves the name to a ClusterIP (let's say 10.43.0.200)
2. Your packet leaves the pod's network namespace through the veth pair to the node
3. The kernel hits the iptables rules — specifically the `KUBE-SERVICES` chain
4. A rule matches 10.43.0.200:8080 and jumps to `KUBE-SVC-XXXXX`
5. That chain has one rule per endpoint, each with a `-m statistic --mode random --probability` match
6. The matching rule jumps to `KUBE-SEP-XXXXX`, which does the DNAT — rewriting the destination to a specific pod IP and port
7. The packet routes to that pod

This is load balancing via statistical probability in iptables rules. It works. It's been working for years. But it has properties that surprise people.

**The probability math is sequential, not uniform.** If you have three endpoints, the rules aren't "33% each." The first rule matches with probability 0.333. If it doesn't match, the second rule matches with probability 0.5 (because it's 1 out of 2 remaining). The third rule matches with probability 1.0 (it's the last one). The math works out to equal distribution, but it's not implemented as "pick one of three" — it's implemented as a chain of coin flips. This matters when you're reading the rules and wondering why the probabilities look wrong. They're not wrong. They're conditional.

**iptables doesn't scale well with service count.** Every packet traverses the rules linearly. With 100 services, each with 5 endpoints, you've got 500+ rules in the NAT table. With 1,000 services, you've got 5,000+ rules, and the linear traversal starts showing up in latency. This is why IPVS mode exists — it uses a hash table instead of linear rule matching, and scales to tens of thousands of services without degradation. And it's why newer solutions like Cilium bypass iptables entirely, using eBPF programs attached to network hooks to make routing decisions. The abstraction that worked at small scale becomes the bottleneck at large scale. The solution is always the same: go closer to the kernel.

**NetworkPolicies are also iptables rules** (or eBPF programs, depending on your CNI). When you create a NetworkPolicy that says "only allow ingress to my-app from pods with label role=frontend," your CNI plugin translates that into packet filtering rules. With Calico, those are iptables rules in the FILTER table. With Cilium, they're eBPF programs. Either way, there's a concrete enforcement mechanism, and when your NetworkPolicy isn't working, the answer is usually in those rules, not in the YAML.

I watch people debug NetworkPolicy issues by staring at the YAML for twenty minutes, verifying the selectors, checking the namespace, re-reading the Kubernetes docs on ingress vs egress semantics. All useful. But the fastest path is often: SSH into the node, look at the actual iptables rules (or `cilium monitor`), and see whether the packet is being dropped and where. The YAML is the declaration. The rules are the reality. When they disagree, reality wins.

**The reason I care about this — the reason anyone building on Kubernetes should care — is that abstractions leak.** They always do. And when they leak, the speed of your debugging depends entirely on whether you understand the layer below.

When a Service randomly drops connections, it helps to know that iptables DNAT doesn't do health checking — it'll happily route traffic to a pod that's terminating. When pod-to-pod traffic fails after a node reboot, it helps to know that iptables rules are ephemeral and kube-proxy needs to re-sync them. When latency spikes correlate with deployment rollouts, it helps to know that connection tracking (`conntrack`) entries can go stale when pod IPs change, causing RST packets on established connections.

None of this is in `kubectl describe service`. All of it is in the networking stack that Kubernetes is built on top of.

**My unsolicited advice:** before you deploy your next Service, run `iptables-save` on a node and read the output. Not all of it — just find the chain for one of your services and trace the path a packet would take. It'll take ten minutes. You'll understand Kubernetes networking better than most people who've been running it for years. And the next time something breaks at 2 AM, you'll know where to look.

The abstraction is a gift. Understanding what's underneath is a superpower.
