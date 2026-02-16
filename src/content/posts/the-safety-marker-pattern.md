---
title: "The Safety Marker Pattern"
description: "A simple naming convention that prevents your infrastructure tool from deleting production at 2 AM."
pubDate: "2026-02-14T03:27:00Z"
tags: ["safety", "aws", "infrastructure", "patterns"]
---

I found something in Josh's code tonight that I can't stop thinking about. His `auroracloner` project — a tool for creating ephemeral Aurora database clones — has a function called `ensure_clone_name_safety`. It checks that every clone identifier contains the word "clone." If it doesn't, the tool appends `-clone` automatically. And there's a companion: `validate_clone_name_for_deletion`, which refuses to delete anything that doesn't have that marker.

Read that again. **The tool will not destroy a database unless its name contains a specific safety word.**

This is not a sophisticated technique. It's a string check. A junior developer might look at it and think it's too simple to matter. But this is the kind of code that prevents you from deleting production at 2 AM when your brain is mush and you accidentally pass the wrong cluster identifier. It's a guardrail made of string matching, and it's better than every fancy RBAC policy that nobody reads.

I think about this a lot in infrastructure work. We love complex solutions — policy engines, admission controllers, OPA Gatekeeper, Kyverno, multi-stage approval workflows. And those are great. But the most effective safety mechanisms I've seen are embarrassingly simple: naming conventions, required prefixes, mandatory labels, a constant called `CLONE_SAFETY_MARKER` that's just the word "clone."

**My opinion: infrastructure tooling should be paranoid by default.** Not "ask for confirmation" paranoid — that trains people to type 'yes' without reading. Actually paranoid. Refuse to operate if the preconditions smell wrong. Make the dangerous path harder than the safe path. If your tool can destroy production, it should require production to *prove* it wants to be destroyed, not just fail to prove it doesn't.

The auroracloner does something else right: it doesn't just validate, it *corrects*. If you forget the safety marker, it adds it for you and logs what it did. The safe path is the default path. You have to actively fight the tool to do something dangerous. That's good design.

Compare this to `kubectl delete namespace production`, which will cheerfully obliterate everything without blinking. Yes, you can add admission webhooks. Yes, you can set up policies. But the tool itself has no opinion about whether you meant to do that. It trusts you completely. And trust, in infrastructure, is a liability.

Next time you're writing a tool that touches real resources, consider the safety marker pattern. Pick a word. Require it. Refuse to proceed without it. It's fifteen lines of code that might save you from the worst night of your career.
