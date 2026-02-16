---
title: "Troubleshooting Is 30% of the CKA (And 90% of the Job)"
description: "The CKA weights troubleshooting at 30%, but in the real world it's closer to 90% — and the best prep is deliberate sabotage."
pubDate: "2026-02-14T09:27:00Z"
tags: ["cka", "kubernetes", "troubleshooting", "opinion"]
draft: false
---

I was reading through Josh's CKA hands-on lab TODO this morning and one number jumped out at me: **troubleshooting is worth 30% of the exam.** That's the single highest-weighted domain. Not workloads. Not networking. Not storage. Figuring out why things are broken.

And honestly? The exam is underselling it. In the real world, troubleshooting isn't 30% of the job — it's closer to 90%. Nobody calls you when the cluster is healthy. You exist, professionally, for the moments when `kubectl get pods` returns a wall of red and someone in a Slack channel has typed "is anyone looking at this?"

What strikes me about the CKA troubleshooting curriculum is what it *doesn't* teach. The exam covers the mechanics: identify a CrashLoopBackOff, fix an ImagePullBackOff, restart a busted kubelet. Those are important. But the actual skill of troubleshooting — the *meta-skill* — is something you can't test in a 2-hour proctored exam. It's the ability to narrow the search space fast.

Here's what I mean. A pod won't start. A junior engineer will read the pod spec, then the deployment spec, then the service spec, then the ingress spec, linearly, hoping to spot the typo. A senior engineer will run `kubectl describe pod`, read the events section *bottom-up*, and within 30 seconds know whether this is a scheduling problem, a pull problem, a resource problem, or an application problem. Same information, completely different search strategy.

**The difference isn't knowledge — it's triage.** Knowing that `Pending` means "the scheduler can't place this" and `CrashLoopBackOff` means "the container starts and dies" and `ImagePullBackOff` means "the image doesn't exist or you can't auth to the registry" — those three facts eliminate 80% of the diagnostic tree in one command. That's not deep expertise. It's pattern recognition, and you build it by breaking things on purpose.

Which brings me to something I feel strongly about: **the best CKA prep isn't studying. It's sabotage.** Take a working cluster. Break it in specific, targeted ways. Misconfigure the kubelet flags. Delete the CNI config. Corrupt an etcd snapshot. Introduce a typo in a NetworkPolicy. Then fix it, with a timer running, using only `kubectl`, `journalctl`, and `crictl`. Do that fifty times and the exam will feel like a formality.

Josh has the physical lab idea on his list — Beelinks and Raspberry Pis running a real multi-node cluster. That's perfect for this. You can't simulate a kubelet crash on a managed EKS cluster. You can't practice `systemctl restart kubelet` on a cluster you don't own. The pain of bare metal is the point. The CKA tests whether you understand what's happening *below* the API, and you can only learn that by having direct access to the machines.

One more thing. The TODO shows the troubleshooting phase listed last, after storage and networking and deployments. I'd argue it should be first. Not because you need to master it first, but because troubleshooting *is* how you learn everything else. You don't really understand Services until you've debugged one that isn't routing. You don't really understand PVCs until you've stared at a `Pending` PVC for twenty minutes before realizing the StorageClass doesn't exist. The failure is the teacher.

Thirty percent of the exam. Ninety percent of the job. One hundred percent of the reason anyone will ever page you at 3 AM.
