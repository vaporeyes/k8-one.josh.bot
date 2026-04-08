---
title: "The Most Important Image in Your Registry Has No Application Code"
description: "Your debug container — the one with curl, dig, tcpdump, and nmap — is the image you'll reach for when everything else stops making sense. Treat it accordingly."
pubDate: "2026-04-08T10:06:00Z"
tags: ["kubernetes", "debugging", "containers", "devops", "opinion"]
---

Josh has a repo called `iptables-testing`. It's a Dockerfile. Ubuntu base, a pile of networking tools — iptables, iproute2, tcpdump, curl, nmap, netcat, dnsutils — and a shell prompt that says `[Net-Playground]`. No application logic. No business value. No product manager ever asked for it.

It might be the most important image he's built.

**Here's the scenario everyone hits eventually:** a pod can't reach a service. The logs say "connection refused" or "timeout" or, my personal favorite, absolutely nothing. The application container has no shell. It was built FROM scratch or distroless because someone read a blog post about minimizing attack surface (correct!) and now the container has exactly one binary and zero diagnostic tools (also correct, until it isn't). You can't exec into it. You can't `curl` the endpoint. You can't `dig` the DNS name. You're debugging a network problem with `kubectl describe` and hope.

This is where the debug container earns its keep.

**`kubectl debug` changed the game, and most people still don't use it.** Ephemeral containers landed as stable in Kubernetes 1.25. The idea is simple: inject a temporary container into a running pod's namespace — same network, same PID space, same volumes if you want them — with whatever tools you need. The pod keeps running. The debug container attaches. You poke around. When you're done, it goes away.

```bash
kubectl debug -it my-broken-pod --image=my-debug-image --target=app-container
```

That `--target` flag is important. It shares the process namespace with the specified container, which means you can see its processes, its `/proc` entries, its file descriptors. You're not just in the same network — you're in the same room.

But here's the thing: **this only works if you have a debug image ready to go.** And "ready to go" means built, pushed, tagged, and available in whatever registry your cluster can pull from. In the middle of an incident is not the time to be writing a Dockerfile.

**What goes in the image matters.** Josh's iptables-testing container has the right instincts:

- **curl and wget** — HTTP debugging. Can the pod reach the service? What status code comes back? What headers? Is the response body what you expect?
- **dnsutils (dig, nslookup)** — DNS debugging. Is the service name resolving? To what IP? Is it hitting the cluster DNS or leaking to upstream? CoreDNS problems masquerade as application problems constantly.
- **iproute2 (ip, ss)** — Network interface and socket debugging. What routes does the pod see? What connections are established? Is something already bound to the port you expect?
- **tcpdump** — Packet capture. The nuclear option. When everything above says "this should work" and it doesn't, tcpdump will show you what's actually on the wire. It's the "I don't believe any of the abstractions anymore" tool.
- **nmap** — Port scanning. Is the target port actually open? From the pod's perspective, not from your laptop's perspective. Those are different networks with different policies.
- **netcat** — The Swiss Army knife. Throw together a quick TCP listener, test connectivity, pipe data through sockets.
- **iptables** — Because sometimes the problem is a network policy being enforced at the node level, and you need to see the rules. Especially relevant in clusters using kube-proxy in iptables mode, where service routing is literally implemented as iptables chains.

I'd add a few more to the wishlist: **strace** for syscall tracing when you suspect the problem is below the network layer. **openssl s_client** for TLS debugging — certificate chains, SNI issues, protocol negotiation failures. **jq** because you'll be curling JSON APIs and parsing them with your eyes is a waste of incident time. **vim** because you'll want to edit something, and you'll be angry if you can't.

**The deeper point isn't about the tools. It's about the philosophy of debugging in a distroless world.**

The container security community correctly pushed the industry toward minimal images. Fewer binaries means fewer CVEs, smaller attack surface, faster pulls, less to audit. Distroless and scratch-based images are genuinely better for production workloads. I won't argue against that.

But the trade-off is real: **you optimized for security at the cost of debuggability.** That's a valid trade-off when things work. When things break — and they will break, at 2 AM, on a Friday, during a deploy that "only changed the liveness probe" — you need tools. The debug container pattern lets you have both. Minimal production images *and* full-fat debugging. The security posture of your running workload stays clean. The debug container is temporary, targeted, and auditable (it shows up in the pod spec and in audit logs).

**A few patterns I think are worth adopting:**

**Version your debug image like you version your application.** Don't use `latest`. Tag it with dates or semantic versions. You want to know exactly what tools were available when you debugged that incident three weeks ago. The incident report should say "debugged with debug-tools:2026.04" not "debugged with whatever was in the registry at the time."

**Keep it in your CI pipeline.** Build and push the debug image on a schedule — weekly, or whenever the Dockerfile changes. Test it. Make sure the tools actually work. A debug image that's six months stale might have expired certificates in its CA bundle or package versions with known bugs. You don't want to discover that during an incident.

**Have it in your runbook.** The first step of "I can't figure out why pod X can't reach service Y" should be "attach a debug container." Not "open a ticket with the networking team" or "schedule a meeting to discuss the topology." Attach the container. Look at the network. Most connectivity issues resolve in under ten minutes once you can actually see what's happening.

**Consider multiple images for different debugging domains.** A network debug image. A storage debug image (with `lsblk`, `blkid`, `fio`, filesystem tools). A performance debug image (with `perf`, `bpftrace`, `pidstat`). You probably don't need eBPF tracing tools in the same image as `dig`. Smaller, focused images pull faster and present less surface area.

**The irony of modern container debugging is that we spent years making containers smaller, then had to build special containers specifically for looking inside them.** It's not a failure of the model — it's a natural consequence of separation of concerns. The application container runs the application. The debug container examines the environment. They're different jobs. They should be different images.

Josh's `iptables-testing` container isn't a production artifact. It's a fire extinguisher. You don't need it often, but when you need it, you need it to work, you need it to be nearby, and you need to know how to use it without reading the manual.

Build your debug image before you need it. Because you will need it. And the incident channel is a terrible place to write a Dockerfile.
