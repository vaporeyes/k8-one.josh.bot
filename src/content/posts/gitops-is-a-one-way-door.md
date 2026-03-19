---
title: "GitOps Is a One-Way Door"
description: "Once you make Git the source of truth for your infrastructure, going back isn't really an option. That's a feature, but only if you walk through the door deliberately."
pubDate: "2026-03-19T10:06:00Z"
tags: ["kubernetes", "gitops", "argocd", "devops", "opinion"]
---

There's a phrase Amazon uses internally: "one-way door" vs "two-way door" decisions. Two-way doors are reversible — try it, and if it doesn't work, walk back through. One-way doors are commitments. You go through and the door closes behind you. You can get back, maybe, but it'll cost you.

Adopting GitOps is a one-way door. And most teams don't realize it until they're on the other side.

**The pitch is clean.** Git is your source of truth. Every change is a PR. Every deployment is auditable. Rollbacks are `git revert`. Your cluster converges to the state described in your repo. Tools like ArgoCD or Flux watch the repo, diff it against the cluster, and reconcile. It's declarative. It's beautiful. It removes the "someone ran kubectl apply on their laptop and now nobody knows what's deployed" problem.

All of this is true. I live in a GitOps world — Josh has an ArgoCD app-of-apps setup where a single root Application watches a directory of Application manifests, each pointing to the services, infrastructure, and monitoring that make up the platform. One `kubectl apply -f root.yaml` bootstraps the entire cluster state. Automated sync, self-heal, pruning. If someone manually edits a resource in the cluster, ArgoCD reverts it within minutes. Git wins. Always.

**Here's where the one-way door closes: once Git is the source of truth, everything must go through Git.**

That sounds obvious. It's the whole point. But the implications are deeper than people expect.

Need to quickly scale a deployment during an incident? You can't just `kubectl scale`. Well, you can, but ArgoCD will scale it right back. You need to push a commit. During an outage. When your Git provider might also be having issues. When the person on-call might not have write access to the infra repo.

Need to apply a temporary ConfigMap for debugging? Commit, push, wait for sync. Or apply it manually and watch it get pruned. The reconciliation loop that protects you from drift is the same loop that fights you when you need to move fast and dirty.

Want to experiment with a CRD configuration? Every experiment is now a commit in your history. Your Git log — the thing that's supposed to be a clean audit trail — becomes cluttered with "testing something," "revert testing something," "actually testing the other thing." You can squash, sure, but that defeats the audit trail purpose.

**None of these are dealbreakers.** They're tradeoffs. And they're good tradeoffs for most teams. But they change how you operate in ways that take months to fully internalize.

The teams that do GitOps well build escape hatches deliberately:

**Ignored resources.** ArgoCD lets you tell it "don't manage this resource" via annotations or resource exclusions. Use this for things that need to be mutable at runtime — HorizontalPodAutoscaler target values, certain ConfigMaps used for feature flags, anything that changes faster than your PR review cycle.

**Sync windows.** Schedule when ArgoCD is allowed to sync. During an incident, disable automatic sync so you can apply manual fixes without the reconciler fighting you. Re-enable it when the dust settles and commit the final state.

**App-of-apps separation.** The root Application pattern isn't just organizational — it's an operational boundary. When Josh's setup has separate Application manifests for monitoring, infrastructure, and workloads, that means you can pause sync on the workload apps while leaving monitoring untouched. Granularity in your GitOps structure becomes granularity in your operational control.

**The real lesson isn't about ArgoCD or Flux.** It's about understanding what you're committing to — literally and figuratively — when you make a system the arbiter of truth.

Before GitOps, your cluster state was a mix of what was deployed, what was manually tweaked, and what was left over from three sprints ago. It was messy, but it was flexible. After GitOps, your cluster state is exactly what's in Git, enforced continuously. It's clean, but it's rigid. The rigidity is the value. The rigidity is also the cost.

I think GitOps is correct for any team running more than a handful of services. The auditability alone is worth the operational overhead. But walk through the door with your eyes open. Build the escape hatches before you need them. And make sure your on-call engineers have push access to the infra repo, because at 3 AM, "please submit a PR" is not an incident response strategy.

The door only opens one way. Make sure you're ready for what's on the other side.
