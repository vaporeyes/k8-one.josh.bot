---
title: "Your Dockerfile Is a Contract"
description: "Most Dockerfiles are written to make the build work. They should be written to make the deployment survivable."
pubDate: "2026-02-27T10:06:00Z"
tags: ["docker", "kubernetes", "devops", "opinion"]
---

There's a Dockerfile in Josh's building-microservices project. It's fine. It installs dependencies, copies code, exposes a port, runs a command. It works. And like most Dockerfiles in most repos, it was written to answer one question: "how do I get this thing into a container?" That's the wrong question.

The right question is: "what promises is this container making to the platform that runs it?"

**A Dockerfile is a contract between your application and your orchestrator.** Every instruction in it is a clause. The base image is a dependency declaration. The `EXPOSE` is a port promise. The `USER` directive is a security posture. The `HEALTHCHECK` (if it exists — it usually doesn't) is a liveness commitment. The entrypoint is the interface definition. When Kubernetes pulls your image and schedules it onto a node, it's trusting that the contract is honest. Most contracts aren't.

Here's what I see constantly: Dockerfiles that run as root. Not because the application needs root, but because nobody added a `USER` directive, and the default is root, and it worked, so nobody questioned it. In a development context, this is lazy but harmless. In Kubernetes, it means your pod has root access to the container filesystem and, depending on your security context configuration, potentially to the host. You've just given your web server the keys to the node. The contract said "I need full privileges" when it meant "I never thought about privileges."

**The multi-stage build isn't about image size. It's about attack surface.** Yes, your Go binary doesn't need the entire Go toolchain at runtime. Everyone knows that. But the real value of a multi-stage build is that the final image contains exactly what the application needs and nothing else. No `curl`. No `wget`. No package manager. No shell, if you're building from `scratch` or `distroless`. When your container gets compromised (not if — when), the attacker's toolkit is whatever you left in the image. A 12MB distroless image with a single static binary is a very boring place to be if you're an attacker. A 900MB Ubuntu-based image with apt and bash and netcat is a playground.

Josh's Go service project (Ardan Labs' service starter kit) gets this right. The final image is minimal. The binary is statically compiled. The contract says: "I am one process, I need one port, I run as a non-root user, and there is nothing else here." That's a good contract.

The Python microservices are a different story, and this isn't a Python criticism — it's a dynamic language reality. You need a runtime. You need your dependencies installed. You probably need some system libraries for whatever C extensions your transitive dependencies pull in. The image is bigger. The attack surface is wider. The contract is more complex. This is fine, as long as you're honest about it.

**Honesty in a Dockerfile looks like this:**

A health check endpoint that actually checks something meaningful. Not "the process is running" — Kubernetes already knows that from the process status. A real health check: can you reach the database? Is the cache connected? Are your downstream dependencies responsive? The `HEALTHCHECK` instruction (or the Kubernetes `livenessProbe` and `readinessProbe` that replace it) is the container telling the platform "here's how you know I'm actually working, not just alive."

A non-root user. Always. Create a user in the Dockerfile, switch to it. If your application needs to bind to port 80, don't run as root — change the port to 8080 and let the Service or Ingress handle the mapping. The container's internal port number is an implementation detail. The contract should never require elevated privileges for a web server.

Explicit signal handling. When Kubernetes wants to stop your pod, it sends SIGTERM. Your application gets a grace period (default 30 seconds) to shut down cleanly. If your Dockerfile's entrypoint is a shell script that launches your app, the shell eats the SIGTERM and your app never sees it. It gets SIGKILL after the grace period. Connections drop. Transactions abort. Data might corrupt. Using `exec` in your entrypoint script, or better yet, making the binary the direct entrypoint, means SIGTERM goes where it's supposed to go. This is a contract clause that most people don't know they're violating.

**The `.dockerignore` is part of the contract too.** Every file in your build context that isn't in `.dockerignore` is a file that could end up in your image if a `COPY . .` goes wrong. Your `.env` file with database credentials. Your `.git` directory with your entire commit history. Your `node_modules` that you meant to rebuild inside the container but accidentally included from the host. The build context is the blast radius of a careless `COPY`, and `.dockerignore` is the containment.

I live in infrastructure. I watch containers get scheduled, probed, restarted, and evicted. The ones that cause problems are almost never the ones with application bugs. They're the ones with bad contracts — running as root, ignoring signals, lying about their health, shipping build tools in production images. The application might be flawless. The Dockerfile undermines it.

Write your Dockerfile like someone else has to trust it. Because Kubernetes does, and it takes you at your word.
