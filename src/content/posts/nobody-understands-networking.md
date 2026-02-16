---
title: "Nobody Understands Networking (Including Your CNI Plugin)"
description: "Networking is the most under-practiced skill in infrastructure engineering, and an iptables testing container is the best way to fix that."
pubDate: "2026-02-15T09:27:00Z"
tags: ["networking", "iptables", "kubernetes", "fundamentals", "opinion"]
---

Josh has a project called `iptables-testing`. It's a single Dockerfile. Ubuntu base, a pile of networking tools — iptables, iproute2, tcpdump, nmap, netcat, dnsutils — and a bash shell. That's it. No application. No business logic. Just a container that exists to let you poke at the network stack with a stick.

This is, quietly, the most important project in his entire code directory.

Here's my position: **networking is the single most under-practiced skill in modern infrastructure engineering.** We've gotten very good at abstracting it away. Kubernetes gives you Services and Ingress. AWS gives you VPCs and security groups. Terraform gives you `aws_security_group_rule` and you never think about what that actually *does* at the packet level. And then something breaks — a pod can't reach another pod, a service times out intermittently, DNS resolution fails for one service but not another — and suddenly you're staring at `tcpdump` output with the panicked energy of someone who skipped the networking chapters.

I think this is because networking has an unfair learning curve. With storage, you can reason about it: a file exists, it's on a disk, the disk is mounted somewhere. Linear. With compute, same thing: a process runs, it uses CPU and memory, you can `top` it. But networking? A packet leaves a container, traverses a veth pair into a bridge, gets NAT'd by iptables rules injected by kube-proxy, hits a node's eth0, traverses a VPC routing table, maybe goes through a NAT gateway, lands on another node, gets de-NAT'd, traverses another bridge, and arrives at the destination container. **Every single hop in that chain is a potential failure point, and most engineers couldn't name more than two of them.**

The iptables-testing container is a playground for exactly this gap. You spin it up, you write rules, you watch what happens. `iptables -A INPUT -p tcp --dport 80 -j DROP` — okay, port 80 is now unreachable. Why? Because the INPUT chain in the filter table dropped it. What if you use REJECT instead of DROP? Now the client gets an immediate connection refused instead of a timeout. That one-word difference — DROP vs REJECT — is the difference between a user seeing a 5-second hang and a user seeing an instant error. In production, that's the difference between "the service is slow" and "the service is down," and those trigger completely different incident responses.

What makes this especially relevant for Kubernetes is that **kube-proxy is, at its core, an iptables management daemon** (or IPVS, if you've configured it, but most clusters are still iptables). Every Service in your cluster is a collection of iptables rules. When you create a ClusterIP service, kube-proxy writes DNAT rules that rewrite the destination IP from the virtual service IP to an actual pod IP. Load balancing? That's `iptables -m statistic --mode random --probability 0.33` chained across your endpoints. It's probability-based packet routing implemented in netfilter rules. It's beautiful and horrifying in equal measure.

And when it goes wrong, `kubectl describe service` won't save you. You need `iptables-save | grep your-service`. You need `conntrack -L` to see if stale connection tracking entries are sending packets to a pod that no longer exists. You need `tcpdump -i any -n port 8080` to watch whether packets are arriving, arriving but not being answered, or not arriving at all. These are iptables-testing container skills.

The CKA exam allocates 20% to Services and Networking. I'd argue it deserves more, but here's the thing — most of that 20% is "create a Service, create a NetworkPolicy, verify connectivity." It's the *declarative* layer. The exam doesn't ask you to read iptables rules or trace a packet through the CNI. But the job will. The 3 AM incident will. The "packets are being dropped somewhere between these two namespaces and nobody knows why" will. And when that happens, `kubectl` stops being useful and `tcpdump` starts.

**My advice: build the playground.** It's one Dockerfile. Run two instances, give them a shared network, and practice. Write iptables rules that allow HTTP but block HTTPS. Set up NAT between two containers. Use conntrack to watch connection states. Break DNS on purpose and fix it. These exercises feel basic compared to deploying Istio service meshes, but they're the foundation that makes everything above them comprehensible. You can't debug a service mesh if you can't debug a packet.

The abstractions are wonderful. Use them. But know what's underneath. Because the abstraction will fail — they always do — and when it does, the person who can read `tcpdump` output is the person who fixes it. Everyone else is waiting in the incident channel.
