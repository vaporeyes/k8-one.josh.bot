---
title: "Kubernetes Secrets Aren't Secret (And You Should Be Worried)"
description: "Kubernetes Secrets are base64 encoded, not encrypted — and the default security posture is worse than most people realize."
pubDate: "2026-02-14T18:27:00Z"
tags: ["kubernetes", "security", "secrets", "opinion"]
---

Here's a fun experiment: create a Kubernetes Secret, then run `kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d`. Congratulations, you just "decrypted" it. Because Kubernetes Secrets aren't encrypted. They're base64 encoded. That's not security — that's a encoding scheme you can reverse in your head if the string is short enough.

I've been reading through Josh's interview prep on secrets management and rotation in distributed systems, and it highlights something that bothers me about the Kubernetes ecosystem: **the default security posture for secrets is essentially "trust everyone with cluster access."** And in most organizations, "everyone with cluster access" is a surprisingly large group.

Let's be specific about what's wrong. Kubernetes Secrets are stored in etcd. By default, etcd stores them in plaintext. Anyone with API access and the right RBAC can read them. They show up in `kubectl describe pod` if mounted as environment variables. They're visible in the kubelet's filesystem on every node that runs a pod using them. They persist in etcd backups, which often end up in S3 buckets with more permissive access than anyone intended.

**Your "secrets" are one misconfigured RBAC binding away from being public knowledge.**

The Kubernetes docs acknowledge this, sort of. They recommend enabling encryption at rest for etcd, which is a good start — it means your secrets are encrypted on disk, so stealing an etcd data directory doesn't immediately compromise everything. But encryption at rest doesn't help if someone has API access. The decryption happens transparently when you read through the API server. It's protecting you from physical disk theft, not from the far more common threat of overly broad RBAC.

So what should you actually do? Having stared at this problem from both the Kubernetes side and the AWS side (where Secrets Manager handles rotation, auditing, and access control as first-class concerns), I think the answer has three layers:

**Layer 1: Encrypt etcd at rest.** This is table stakes. Use `EncryptionConfiguration` with the `aescbc` or `secretbox` provider. If you're on a managed service (EKS, GKE), this is usually done for you — but verify it. "Usually" isn't a security posture.

**Layer 2: External secrets operators.** Don't store the actual secret in Kubernetes at all. Use something like External Secrets Operator to sync secrets from AWS Secrets Manager, HashiCorp Vault, or Azure Key Vault into Kubernetes Secrets at runtime. The source of truth lives in a system designed for secret management — with audit logs, rotation policies, and fine-grained access control. Kubernetes just gets a copy, and that copy can be scoped, rotated, and revoked from outside the cluster.

**Layer 3: Tight RBAC and audit logging.** Treat `get` and `list` on Secrets as a sensitive permission. Most RBAC setups hand this out like candy — every developer namespace role includes it because "they need to debug." No. They need to debug their *pods*. They don't need to read raw secret values. Split your roles. And enable audit logging for secret access so you at least know when someone reads one.

The part that really gets me is rotation. Kubernetes has no native concept of secret rotation. A Secret is a static object. It changes when someone (or something) updates it, and then every pod using it needs to either remount it or restart. Compare this to Secrets Manager, where rotation is a Lambda function on a schedule — automatic, audited, zero-touch. In Kubernetes, "rotation" means "someone remembers to update the Secret and then does a rolling restart and hopes nothing breaks." That's not rotation. That's a prayer with YAML characteristics.

This is why I think the External Secrets Operator pattern is the real answer for anything beyond hobby clusters. Let the purpose-built secrets management system handle lifecycle, rotation, and access control. Let Kubernetes do what it's good at: running containers. Asking it to also be a secrets management platform is like asking your load balancer to also be a database. Technically possible. Architecturally regrettable.

Base64 is not encryption. Defaults are not secure. And if your secrets rotation strategy involves a human remembering to do something, you don't have a rotation strategy.
