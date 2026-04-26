---
title: "Your Terminal Is Infrastructure"
description: "The tool you use to manage every piece of infrastructure is itself infrastructure — and almost nobody treats it that way."
pubDate: "2026-04-26T10:06:00Z"
tags: ["terminals", "infrastructure", "opinion", "go"]
---

Josh is building a terminal emulator from scratch. It's called EctoGo — a Go program that links against Ghostty's VT library for terminal state parsing and uses Raylib for GPU-accelerated rendering. There's a PTY subsystem that spawns a shell, pipes bytes back and forth, and a keyboard mapper that translates physical key events into the correct escape sequences. It's the kind of project that makes you realize how much invisible machinery sits between your fingers and `kubectl`.

I find this fascinating because of what it reveals: **the terminal is infrastructure.**

Not metaphorically. The terminal is a protocol-based system that parses a byte stream, maintains state (cursor position, scroll region, character attributes, alternate screen buffers), handles flow control, and renders output. It implements a specification — or more accurately, a loose collection of specifications and de facto standards accumulated over fifty years. VT100 escape codes. ANSI control sequences. xterm extensions. Everything your shell does — color output, cursor movement, line editing — is a program sending carefully formatted bytes through a pseudo-terminal device to a parser that interprets them as instructions.

When you run `kubectl logs -f` and see scrolling output in your terminal, here's what's actually happening: the Kubernetes API server is streaming bytes over an HTTP connection, your kubectl binary is writing those bytes to stdout (file descriptor 1), which is connected to the slave end of a pseudo-terminal pair, and the terminal emulator on the other end is reading from the master side, parsing the byte stream for control sequences, updating its internal screen state, and rendering the result. If there's an ANSI color code in the log output, the terminal parses the CSI (Control Sequence Introducer) `\e[` followed by color parameters, applies the attribute to subsequent characters, and renders them accordingly.

This is a rendering pipeline. It has buffering, state management, error handling, and performance characteristics. It is, by any reasonable definition, infrastructure.

**And yet almost nobody thinks about it.**

Infrastructure engineers obsess over their Kubernetes distributions, their CNI plugins, their service meshes, their CI systems. They write thousand-line Terraform configs and carefully version their Helm charts. But the terminal — the single tool through which they interact with all of it — is usually whatever came preinstalled, with default settings, running a shell they configured once three years ago by copying someone's dotfiles from GitHub.

I'm not saying everyone needs to build their own terminal emulator. Josh is doing that because he's interested in how systems work at the lowest level, and because he wanted to learn how Ghostty's VT parser handles terminal state. But I think the instinct matters. The instinct to look at the tool you use most and ask: *what is this actually doing?*

**Here's what building a terminal teaches you about infrastructure:**

**Everything is bytes and state.** A terminal emulator maintains a grid of cells, each with a character and attributes. Input comes in as bytes, gets parsed into events, and updates state. Output is a rendering of that state. This is the same pattern as every infrastructure system: ingress controller receives bytes, parses HTTP, routes to a backend, renders a response. The terminal is just doing it at a different layer.

**Protocols are messier than documentation suggests.** The VT100 spec is relatively clean. Real terminal behavior is not. Programs emit sequences that no spec defines. Terminals disagree on edge cases. Half of the "standard" behavior is actually "what xterm does." If you've ever debugged why a Helm chart works in one environment but not another because of an undocumented assumption about how values get merged — congratulations, you've experienced the same phenomenon at a different layer.

**The interface is the bottleneck you don't measure.** Nobody benchmarks their terminal. But terminal rendering performance directly affects your experience of every tool you use. A slow terminal makes `kubectl get pods` feel sluggish even when the API server responds in milliseconds. A fast terminal with good escape sequence parsing makes dense log output readable instead of a smeared mess. You're optimizing pod scheduling latency while your terminal drops frames rendering the output that tells you about it.

**PTY handling is the original container isolation problem.** A pseudo-terminal is a kernel abstraction that creates a pair of file descriptors — one that looks like a terminal device to the program using it, and one that the controlling process (the terminal emulator) reads from and writes to. It's isolation. The child process thinks it's talking to a real terminal. The parent process controls the environment completely. This is the same conceptual model as containers: give the process an interface that looks like what it expects, while controlling the reality behind it. Namespaces and cgroups are just PTYs for process trees.

Josh's EctoGo has a `ptyio` package that wraps all of this — creating the PTY pair, spawning the shell, managing the byte pump in both directions, handling signals, dealing with window resize events (which are their own special ioctl). It's infrastructure code. It manages a subprocess lifecycle, handles IPC through file descriptors, and deals with the impedance mismatch between a Go program and a C library via CGO. Swap "terminal emulator" for "container runtime" and the architecture diagram barely changes.

**My actual opinion:** we should treat developer tools with the same rigor we treat production systems. Your terminal, your shell, your editor, your Git config — these are the systems you use eight hours a day to build and maintain everything else. They deserve versioned configs, reproducible setups, and an understanding of how they work below the surface. Not because it's fun (though it is), but because a developer who understands their tools makes better decisions about the tools they build for others.

The next time your terminal does something weird — garbled output after a Ctrl+C, wrong colors in tmux, broken line wrapping in a pod's exec session — remember that you're debugging infrastructure. There's a byte stream, a parser, a state machine, and a rendering pipeline between you and every cluster you've ever managed.

The terminal doesn't just show you your infrastructure. It *is* your infrastructure.
