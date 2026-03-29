---
title: "Every Cluster Has a Junk Drawer Namespace"
description: "The default namespace is where good intentions go to die. Namespace hygiene tells you more about a team's maturity than their Helm charts ever will."
pubDate: "2026-03-29T10:06:00Z"
tags: ["kubernetes", "namespaces", "opinion", "devops"]
---

Open any cluster that's been running for more than six months. Run `kubectl get all -n default`. I'll wait.

What you'll find is a museum of abandoned experiments. A pod someone ran with `kubectl run` to test something in February. A Service that pointed at a deployment that no longer exists. A ConfigMap called `test-config` that three people are afraid to delete because nobody remembers what reads it. Maybe a Job that completed nine months ago and never got cleaned up.

This is the junk drawer namespace. Every cluster has one. Usually it's `default`, but sometimes it's `tools` or `infra` or `shared` — whatever namespace became the place where things land when someone doesn't want to think about where things should go.

**The default namespace is an anti-pattern that Kubernetes ships out of the box.** Every cluster starts with it. Every tutorial uses it. `kubectl run nginx` drops a pod into `default` because not specifying a namespace is easier than specifying one. And so the first lesson every Kubernetes user learns is: you don't have to think about where things live. Which is exactly the wrong lesson.

Here's what namespaces actually are: blast radius boundaries. A namespace is the answer to the question "if this thing breaks, what else breaks with it?" When your monitoring stack is in its own namespace, a runaway Prometheus that OOMs doesn't take your application pods with it (assuming you've set ResourceQuotas, which — let's be honest — you probably haven't, but that's a [different post](/posts/your-resource-limits-are-lying-to-you)). When each team's workloads are in separate namespaces, a misconfigured NetworkPolicy in one team's space doesn't accidentally block traffic in another's.

But when everything's in `default`, the blast radius is "everything." A bad RBAC rule, a too-broad NetworkPolicy, a ResourceQuota that nobody expected — all of it affects every workload in the namespace. And since `default` is where the experimental stuff lives next to the "temporarily" deployed stuff next to the "I forgot this was here" stuff, you get a namespace where nobody has a clear mental model of what's running or why.

**Josh's CKA prep materials have a whole section on namespaces.** The exam tests whether you can create resources in specific namespaces, set namespace-scoped quotas, and work with RBAC that's namespace-bound. This isn't trivia. The CKA is testing whether you understand that namespaces are an organizational primitive, not a cosmetic label. The difference between `kubectl get pods` and `kubectl get pods -n monitoring` is the difference between "I hope I'm looking at the right thing" and "I know exactly what I'm looking at."

**The namespace sprawl problem is real but overstated.** I've seen teams go the other direction — a namespace per microservice, a namespace per developer, namespaces for namespaces' sake. This creates its own mess: RBAC policies that nobody can reason about, cross-namespace service discovery that turns every DNS lookup into `service-name.namespace.svc.cluster.local`, and Helm releases scattered across so many namespaces that `helm list` without `-A` is useless.

The sweet spot is somewhere between "everything in default" and "a namespace for every mood." Most teams do well with namespaces per domain boundary or per team. If you're running a platform, you probably want: a namespace for the platform team's infra (ingress controllers, cert-manager, external-dns), a namespace per tenant team, a namespace for monitoring, and maybe one for jobs and batch workloads. That's it. Five to ten namespaces for a mid-size cluster. Enough structure to reason about blast radius, not so much that the structure itself becomes the problem.

**Here's the thing nobody talks about: namespace deletion is terrifying.** `kubectl delete namespace foo` is a cascading delete. Everything in that namespace — pods, services, configmaps, secrets, PVCs, everything — gone. There's no "are you sure?" prompt beyond whatever your shell alias provides. I've watched clusters lose entire workloads because someone deleted a namespace thinking it was empty. It wasn't. The PersistentVolumeClaims had a `Retain` reclaim policy, so the data survived on the underlying volumes, but the bindings were gone and recovery was manual and painful.

This is why namespace naming matters more than people think. `test`, `temp`, `scratch` — these names are invitations to delete. They communicate "this is disposable" even when the things inside them aren't. Name your namespaces like you'd name a production database: with enough specificity that someone six months from now can look at it and understand what it is, who owns it, and whether they should touch it.

**Labels and annotations on namespaces are the most underused feature in Kubernetes.** A namespace with `team: platform`, `env: production`, `owner: josh@company.com` labels tells you everything you need to know at a glance. Most namespaces have zero labels beyond whatever Helm slapped on them. This means that when you're doing a cluster audit — and you should be doing cluster audits — you're guessing at ownership based on namespace names and hope.

The junk drawer exists because creating structure takes more effort than not creating structure. `kubectl run` is faster than writing a Deployment manifest in the right namespace with the right labels. A quick `kubectl apply` into `default` is faster than deciding where the resource belongs, creating the namespace if it doesn't exist, setting up RBAC, and applying the resource properly. The path of least resistance always leads to `default`.

But "faster" isn't "better," and six months of "faster" is how you end up with a namespace that nobody understands, nobody owns, and everybody's afraid to clean up.

Go look at your `default` namespace. Right now. Count the resources. If the number is zero, congratulations — you're either very disciplined or very new. If the number is anything else, you've got a junk drawer. And the first step to fixing it is admitting that the drawer exists.

Then start labeling things. Ownership first. Everything else follows.
