---
title: "Sidecars Graduated and Nobody Noticed"
description: "Kubernetes finally made sidecars a real primitive. The sidecar container — the most important pattern nobody could formally express — is now a first-class citizen. Here's why that matters more than you think."
pubDate: "2026-05-10T10:06:00Z"
tags: ["kubernetes", "containers", "architecture", "opinion", "devops"]
---

Two days ago I wrote about init containers and how every one of them is a confession. Today I want to talk about sidecars, because Kubernetes quietly did something remarkable with them, and the infrastructure world mostly shrugged.

Native sidecar containers — the `restartPolicy: Always` field on init containers that makes them run for the lifetime of the pod — graduated to GA. The most common pattern in Kubernetes, the one that's been a convention held together by social agreement since 2015, is finally an actual primitive. And the reaction was mostly "oh cool, anyway."

I think that undersells it.

**The sidecar pattern has always been a lie we told ourselves.** Before native sidecars, a "sidecar" was just a regular container in the same pod that happened to perform a supporting role. Kubernetes didn't know it was a sidecar. The kubelet didn't treat it differently. If your Envoy proxy sidecar crashed, Kubernetes restarted it — same as any container. If your application container exited successfully (Job completed), the sidecar kept running, and the pod never terminated. If the sidecar needed to start before the main container, you couldn't express that. The ordering was undefined.

We worked around all of this with conventions. We wrote preStop hooks that sent SIGTERM to sidecars when the main container exited. We added shell scripts that polled for the main process and killed themselves when it disappeared. We ran sidecar injectors (hello, Istio) that modified pod specs at admission time. The entire service mesh ecosystem is built on injecting sidecar containers that Kubernetes doesn't formally understand.

That's a staggering amount of infrastructure complexity to compensate for the absence of a single field.

**Here's what `restartPolicy: Always` on an init container actually gives you:**

First, ordering. Native sidecars are init containers, so they start in order, before the main containers. Your Envoy proxy starts before your application. Your log collector starts before your application writes its first log line. This was the number one pain point with the old pattern — a race condition baked into every sidecar deployment. The application container could start before the proxy was ready, and the first few requests would fail. People solved this with — you guessed it — init containers that waited for the sidecar to be ready. Layers of workarounds, all the way down.

Second, lifetime awareness. When the main containers in a pod exit, the kubelet now knows to shut down native sidecars. A Job that completes actually completes, instead of hanging forever because the Istio sidecar doesn't know the work is done. This was such a persistent problem that `istio-proxy` had a dedicated `quitquitquit` endpoint, and people ran postStop hooks that curled it. Every service mesh user has debugged a stuck Job caused by a sidecar that wouldn't die.

Third, graceful shutdown ordering. Sidecars shut down in reverse order, after the main containers. Your log forwarder stays alive long enough to flush the last logs. Your proxy stays alive long enough to drain connections. This was nearly impossible to guarantee before — container shutdown order within a pod was concurrent and nondeterministic.

**The reason nobody noticed is the reason it matters.** Good primitives are invisible. They turn workarounds into configuration. The preStop hooks disappear. The sidecar-killing scripts disappear. The "wait for proxy" init containers disappear. The Istio quit-proxy hacks disappear. Each of those was a small piece of accidental complexity that developers maintained, debugged, and got wrong occasionally. Native sidecars delete entire categories of bugs by making the runtime do what conventions could only approximate.

**I have a theory about Kubernetes adoption patterns:** the platform wins not when it adds features, but when it absorbs patterns. Deployments absorbed the rolling update pattern. StatefulSets absorbed the ordered-identity pattern. Jobs absorbed the run-to-completion pattern. Each time, something that was a convention — "we deploy by creating new ReplicaSets and scaling down old ones" — became a declaration. You stopped writing the logic and started declaring the intent.

Native sidecars are the same transition for multi-container pod design. "This container supports that container" was a convention. Now it's a declaration.

**What this means for service meshes is interesting.** Istio and Linkerd built their entire injection model around the limitations of the old sidecar non-pattern. MutatingAdmissionWebhooks that intercept pod creation and inject proxy containers, plus all the lifecycle management hacks to work around ordering and shutdown issues. Native sidecars don't eliminate the need for injection — you still need something to decide which pods get proxies — but they eliminate most of the lifecycle complexity that made mesh operations fragile.

The next time Istio injects a sidecar, it can express "this proxy must start before the application and stop after it" as part of the pod spec, not as a collection of hooks and scripts that approximate that guarantee. That's meaningfully more reliable.

**Here's my broader observation:** the gap between Kubernetes patterns and Kubernetes primitives is where operational complexity lives. Every time there's a well-known pattern that the platform doesn't formally express, you get an ecosystem of tools, controllers, and workarounds to bridge the gap. Sidecars were the oldest and most universal gap. Operators, custom controllers, admission webhooks — these all exist partly because Kubernetes didn't have the right primitive for something people needed to do.

I wonder how much of the "Kubernetes is too complex" criticism is actually about this gap. The core primitives are clean. The complexity comes from the space between what you need to express and what the primitives can express. Every init container, every sidecar hack, every custom controller is filling that space.

Native sidecars shrink the space a little. And the best infrastructure changes are the ones that shrink the space so quietly that nobody notices.

Your pods have been running sidecars for years. Now Kubernetes actually knows that.
