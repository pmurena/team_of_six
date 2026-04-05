← [README.md](../README.md) | Next: [02-architecture.md](02-architecture.md) →

---

# 01 — LLM Pitfalls in Software Development

Before understanding why TOS is built the way it is, you need a clear picture of what it is built against. This document describes the specific, reproducible failure modes that emerge when you try to use a modern large language model as a development collaborator rather than a one-shot assistant.

These are not hypothetical edge cases. They are the default behaviour of every current LLM when working on a real codebase across multiple sessions or a long conversation. Understanding them is prerequisite to understanding every architectural decision TOS makes.

---

## The Context Window Is Not a Memory

The most fundamental misunderstanding about LLMs is treating the context window as a form of memory. It is not. A context window is a fixed-size buffer of tokens that the model can attend to at inference time. When a conversation exceeds that buffer, older content is truncated and is gone — not archived, not summarised automatically, simply absent. Even within the buffer, the model's ability to reliably retrieve and reason about content from the beginning of a long context degrades significantly compared to content near the end. This is sometimes called the *lost in the middle* problem, and it has been reproduced consistently across models and benchmarks.

The practical consequence is that a development session which starts with a careful briefing — here is the codebase structure, here is the coding style, here are the constraints — will see that briefing lose influence as the conversation grows. The model will not announce that it has forgotten. It will continue to respond confidently, drawing on whatever context remains available, and producing subtly incorrect output that reflects a stale or incomplete understanding of the situation.

---

## Hallucination Is Not a Bug, It Is the Architecture

LLMs generate text by predicting the most probable next token given the preceding context. They do not have a separate mechanism for distinguishing between things they know reliably and things they are guessing. When asked about a function that does not exist, a model does not say "I cannot find that function." It generates a plausible description of what such a function probably looks like, because that is the only operation it has available. This is not a failure mode that will be engineered away in future models — it is a structural consequence of how probabilistic text generation works.

In a development context this manifests as: invented API signatures, references to files that do not exist, confident assertions about what a function returns based on its name rather than its implementation, and — most dangerously — implementations that look correct and test-pass on synthetic inputs while being subtly wrong because they were based on an imagined rather than actual interface.

---

## Cognitive Collapse Under Scope

LLMs perform significantly better on narrow, well-defined tasks than on broad, open-ended ones. This is not merely a matter of difficulty — it is a qualitative shift in behaviour. Given a focused task ("implement this function according to this signature and these tests"), a capable model will produce reliable output. Given a broad task ("refactor this module to improve testability"), the same model will often produce output that is locally reasonable but globally incoherent — changes that make sense individually but conflict with each other, or that solve a different problem than the one intended.

This phenomenon — where expanding the scope of a task produces a disproportionate increase in error rate — can be called cognitive collapse. It is the reason that breaking work into small, atomic units is not just good development practice in the context of LLMs; it is a hard prerequisite for reliable output.

The standard advice is to decompose tasks manually and feed them to the model one at a time. TOS enforces this structurally: the Trinity mandate makes it mechanically impossible for the Ghost to work on more than one issue at a time, regardless of what the LLM might prefer to do.

---

## Context Drift Across Sessions

Even within a single conversation, an LLM's working model of the codebase drifts as the conversation evolves. New information is added, old information is truncated or de-emphasised, and the model's implicit understanding of the current state diverges from the actual state. This is manageable in a single short session. Across multiple sessions, or across a long conversation where many things have changed, it becomes a serious source of errors.

The naive solution is to re-paste the relevant files at the start of each session. This works, but it is manual, error-prone, and does not solve the within-session drift problem. The TOS solution is the Clean Room Snapshot: every time the Ghost transitions to a new workspace context, the system regenerates the full context document from the live source of truth — the current state of the GitHub issue, the PR, the diff against main, and the repository's file signature map. The LLM never carries state forward across a workspace transition. It always starts from a verified, current picture of reality.

---

## The Trust Problem

When an LLM produces a code change, there is a question of how much that change should be trusted before it is committed to the repository. The answer in most LLM-assisted workflows is: a great deal, by default. The human reviews the diff in a chat window, judges it to look reasonable, and applies it. There is no validation that the change is consistent with the declared intent, no check that the file being modified is the file the model said it was modifying, and no enforcement that the model's stated context matches the actual working state of the repository.

TOS treats every LLM output as untrusted input. The payload block format requires the Ghost to declare its intent explicitly — target project, target trinity, target file. The gateway validates these declarations against the actual system state before executing anything. A payload that declares the wrong project is rejected. A payload that references a trinity for which no lock exists is rejected. This does not prevent a sufficiently determined or confused model from producing subtly wrong code, but it does catch the entire class of errors that come from the model operating on a stale or incorrect mental model of its own working context.

---

## Summary

| Failure Mode | Root Cause | TOS Response |
|---|---|---|
| Lost briefing | Context window truncation | Clean Room Snapshot on every transition |
| Hallucinated interfaces | Probabilistic generation without ground truth | IPC boundary — Ghost never has direct access |
| Cognitive collapse | Too much scope in a single task | Trinity mandate — one issue, one branch, one feature |
| Context drift | Accumulated state across turns | Lock-gated workspace transitions with full regeneration |
| Unvalidated mutations | Implicit trust in LLM output | Gateway hallucination checks on every write |

---

← [README.md](../README.md) | Next: [02-architecture.md](02-architecture.md) →
