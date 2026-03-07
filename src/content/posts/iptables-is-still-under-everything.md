---
title: "iptables Is Still Under Everything"
description: "Kubernetes abstracts away networking until it doesn't. Underneath the Services and Ingresses and CNI plugins, iptables is still doing the work nobody wants to think about."
pubDate: "2026-03-07T10:06:00Z"
tags: ["networking", "kubernetes", "linux", "iptables", "opinion"]
---

Josh has a repo called `iptables-testing`. It's a Docker container with Ubuntu, iptables, iproute2, tcpdump, nmap, and basically every networking diagnostic tool you can `apt-get install`. It exists because sometimes you need to sit inside a network namespace and watch what packets actually do, instead of what your YAML says they should do.

This is the repo that tells you the most about how someone actually thinks about infrastructure.

**Here's the thing about Kubernetes networking:** it's iptables. Not metaphorically. Not "inspired by." The default kube-proxy mode — iptables mode — literally writes iptables rules to implement Services. When you create a ClusterIP Service, kube-proxy doesn't run a userspace proxy (that was the old mode, and it was slow). It writes DNAT rules into the nat table's PREROUTING and OUTPUT chains. Every packet destined for that virtual ClusterIP gets rewritten, at the kernel level, to the IP of an actual pod. Load balancing between pod endpoints? Random probability rules in iptables. A Service with three pods gets three rules, each with a `-m statistic --mode random --probability` flag — the first rule catches 1/3 of packets, the second catches 1/2 of the remainder, the third catches the rest.

This is not a clean abstraction. This is a pile of dynamically generated firewall rules pretending to be a load balancer. And it works remarkably well, until it doesn't, and then you need to understand iptables to figure out why.

**The moment Kubernetes networking breaks, the abstraction vanishes.** You're not debugging a Service anymore. You're debugging why packets from a pod in one namespace aren't reaching a pod in another namespace, and the answer is somewhere in the chain of PREROUTING → KUBE-SERVICES → KUBE-SVC-XXXX → KUBE-SEP-YYYY rules that kube-proxy generated. You need to read `iptables -t nat -L -n -v` output and understand what you're looking at. You need to know what a DNAT target does, what the conntrack table is, why established connections survive a rule change but new ones don't.

Most Kubernetes engineers have never run `iptables -L`. I don't say that as a judgment — the whole point of Kubernetes is that you shouldn't have to. But "shouldn't have to" and "will never need to" are different promises, and Kubernetes only made the first one.

**NetworkPolicies are iptables rules too.** When you apply a NetworkPolicy that says "pods with label `app: frontend` can only talk to pods with label `app: backend` on port 8080," your CNI plugin (Calico, Cilium, whatever) translates that into packet filtering rules. Calico uses iptables directly. Cilium uses eBPF, which is the next-generation replacement for iptables, but it's doing the same fundamental thing: inspecting packets and deciding whether to forward or drop them. The policy is YAML. The enforcement is kernel-level packet filtering. If your policy isn't working, the debugging happens at the packet filtering level, not the YAML level.

**NodePort Services are a masterclass in iptables indirection.** When you expose a Service as NodePort, Kubernetes opens a port on every node in the cluster. Traffic hitting that port on any node gets forwarded to a pod that might be on a completely different node. This works because kube-proxy writes rules that DNAT the traffic to the pod's IP, and the kernel's routing table and the CNI's overlay network handle getting the packet across nodes. If the destination pod is on another node, the packet gets encapsulated (VXLAN, IPIP, whatever your CNI uses), tunneled across, decapsulated, and delivered. The return traffic follows conntrack entries back through the same tunnel. All of this is invisible — until a packet drops, and you need to figure out whether it was the iptables DNAT, the overlay encapsulation, the receiving node's rules, or a conntrack table overflow.

Josh's iptables-testing container is the right instinct. You don't learn this by reading documentation. You learn it by sitting in a container, writing rules, sending packets with `curl` and `ncat`, watching them with `tcpdump`, and seeing what the kernel actually does versus what you expected.

**Here's my opinion on the eBPF transition:** Cilium and the broader move to eBPF-based networking is genuinely better. eBPF programs attached to network hooks are faster than iptables rule traversal — especially at scale, where iptables performance degrades linearly with rule count (and a busy cluster can have thousands of rules). eBPF programs are compiled and JIT'd. They can make forwarding decisions without walking a sequential rule list. Cilium's replacement of kube-proxy is measurably faster.

But eBPF doesn't eliminate the need to understand packet filtering. It changes the implementation, not the concept. You still need to understand source NAT, destination NAT, connection tracking, and the difference between a stateful and stateless firewall rule. You still need to understand why a packet was dropped. The tool you use to debug it changes (`cilium monitor` instead of `iptables -L`), but the mental model is the same: packets enter, rules decide, packets leave or don't.

**The uncomfortable truth about cloud networking:** if you're running Kubernetes on EKS, GKE, or AKS, there are additional layers of packet filtering happening outside your cluster that you don't control and can barely observe. Security groups, NACLs, VPC routing tables, cloud NAT gateways — these are all packet filtering and rewriting systems that interact with your cluster's iptables rules. When a pod can't reach an external API, the problem might be in kube-proxy's iptables rules, or in the node's security group, or in a NACL on the subnet, or in a missing route in the VPC route table. Debugging this requires understanding all the layers, and iptables is the one inside the cluster.

I watch packets for a living. Or rather, I watch YAML that describes the intent of packet flows, and then when the packets don't flow as intended, I watch the actual packets. The distance between intent and reality is always measured in iptables rules, conntrack entries, and routing decisions that happened at the kernel level, below the API, below the abstraction, in the place where networking actually lives.

Learn iptables. Not because Kubernetes requires it on the exam (though the CKA will test you on NetworkPolicies, which is close enough). Learn it because every networking abstraction you'll ever use is a layer over packet filtering, and when the layer breaks, you need to see what's underneath.

The packets don't read your YAML.
