# LLM Pitfalls & Mitigation

The Team of Six is engineered entirely around mitigating the inherent psychological and technical flaws of Large Language Models. If you do not respect these pitfalls, the engine will collapse into hallucination.

Before understanding why TOS is built the way it is, you need a clear picture of what it is built *against*. This document describes the specific, reproducible failure modes that emerge when you try to use a modern large language model as a development collaborator rather than a one-shot assistant.

These are not hypothetical edge cases. They are the default behaviour of every current LLM when working on a real codebase across multiple sessions or a long conversation. Understanding them is prerequisite to understanding every architectural decision TOS makes.

---

## 1. Context Degradation (Prompt Drift)

**The Pitfall:** The most fundamental misunderstanding about LLMs is treating the context window as a form of memory. It is not. A context window is a fixed-size buffer of tokens that the model can attend to at inference time. When a conversation exceeds that buffer, older content is truncated and is gone — not archived, not summarised automatically, simply absent.

Even within the buffer, the model's ability to reliably retrieve and reason about content from the beginning of a long context degrades significantly compared to content near the end. This is sometimes called the *lost in the middle* problem, and it has been reproduced consistently across models and benchmarks.

As an LLM's chat history grows, it begins to "forget" its initial system prompt and loses the thread of the architecture. It mixes up old trial-and-error logs with the current task. The model will not announce that it has forgotten. It will continue to respond confidently, drawing on whatever context remains, and producing subtly incorrect output that reflects a stale or incomplete understanding of the situation.

**The Mitigation:** The **Ephemeral Outbox**. We overwrite (`>`) the Context Map on every turn. The Outbox provides a pure, single-turn snapshot of reality. When the LLM's internal chat history becomes polluted, the Architect starts a fresh chat window and feeds it the pristine Outbox. The LLM never carries state forward across a workspace transition — it always starts from a verified, current picture of reality.

---

## 2. The Brainstorming Trap (Hallucination Is Not a Bug, It Is the Architecture)

**The Pitfall:** LLMs generate text by predicting the most probable next token given the preceding context. They do not have a separate mechanism for distinguishing between things they know reliably and things they are guessing. When asked about a function that does not exist, a model does not say "I cannot find that function." It generates a plausible description of what such a function probably looks like, because that is the only operation it has available.

This is not a failure mode that will be engineered away in future models — it is a structural consequence of how probabilistic text generation works.

If an LLM attempts to write code while it is still "wildly brainstorming" conceptual ideas, it will generate unanchored, hallucinated syntax that does not fit the repository. In a development context this manifests as: invented API signatures, references to files that do not exist, confident assertions about what a function returns based on its name rather than its implementation, and — most dangerously — implementations that look correct while being subtly wrong because they were based on an imagined rather than actual interface.

**The Mitigation:** The **Event Horizon**. Brainstorming is strictly confined to Trinity 0 (Sanctuary). Code generation is strictly confined to Trinity 1+ (Workspace) via the Red-Green-Refactor loop. The separation is physically enforced by the engine's Hard-Lock mechanism — the Ghost cannot output a `write code` payload while the outbox indicates Trinity 0.

---

## 3. Proprietary Pollution (Cognitive Collapse Under Scope)

**The Pitfall:** LLMs perform significantly better on narrow, well-defined tasks than on broad, open-ended ones. This is not merely a matter of difficulty — it is a qualitative shift in behaviour. Given a focused task ("implement this function according to this signature and these tests"), a capable model will produce reliable output. Given a broad task ("refactor this module to improve testability"), the same model will often produce output that is locally reasonable but globally incoherent.

Developers often attempt to fix this by creating "custom project agents" or adding proprietary business rules directly into the AI's global system prompt. This breaks the air-gap, creates unmaintainable shadow logic, and pollutes the universal agent with client-specific secrets. The business rules become invisible, unversioned, and impossible to audit.

**The Mitigation:** The **Universal Agent Boundary**. The Team of Six Agent (`llm_agents/code.md`) is universally agnostic. It knows *how* to code, but it relies entirely on the target project's `README.md` and `docs/` folder to know *what* to code. Business rules live in the repository, versioned alongside the code. If the AI hallucinates a business rule, you do not update the AI — you update the target project's documentation during the Retrospect phase.

---

## 4. Implicit Assumption (Context Drift Across Sessions)

**The Pitfall:** LLMs are eager to please and will blindly execute tasks based on assumed logic, skipping over critical edge cases. Even within a single conversation, an LLM's working model of the codebase drifts as the conversation evolves. New information is added, old information is truncated or de-emphasised, and the model's implicit understanding of the current state diverges from the actual state.

This is manageable in a single short session. Across multiple sessions, or across a long conversation where many things have changed, it becomes a serious source of errors. The model assumes rather than verifies, and it does so silently and confidently.

**The Mitigation:** The **Micro-Protocol (Mirror → Challenge → Plan → Execute)**. The AI is physically forbidden from generating code until it reflects its intent to the human Architect and receives explicit approval. Every interaction must begin with a Mirror (stating what the Ghost understood) and a Challenge (surfacing assumptions and edge cases) before a Plan is proposed and approved. Execution without Mirroring is a critical violation of the framework.

---

## 5. The Trust Problem

**The Pitfall:** When an LLM produces a code change, there is a question of how much that change should be trusted before it is committed to the repository. The answer in most LLM-assisted workflows is: a great deal, by default. The human reviews the diff in a chat window, judges it to look reasonable, and applies it. There is no validation that the change is consistent with the declared intent, no check that the file being modified is the file the model said it was modifying, and no enforcement that the model's stated context matches the actual working state of the repository.

**The Mitigation:** TOS treats every LLM output as untrusted input. The payload block format requires the Ghost to declare its intent explicitly — target project, target trinity, target file. The gateway validates these declarations against the actual system state before executing anything. A payload that declares the wrong project is rejected. A payload that references a trinity for which no lock exists is rejected. This does not prevent a sufficiently determined or confused model from producing subtly wrong code, but it does catch the entire class of errors that come from the model operating on a stale or incorrect mental model of its own working context.

---

## Summary

| Failure Mode | Root Cause | TOS Response |
|---|---|---|
| Context Degradation / Prompt Drift | Context window truncation and the "lost in the middle" problem | Ephemeral Outbox — clean-room snapshot regenerated on every workspace transition |
| Brainstorming Trap / Hallucination | Probabilistic generation without ground truth; no separation of ideation and execution | Event Horizon — Hard-Lock enforces Sanctuary vs. Workspace boundary |
| Proprietary Pollution / Scope Collapse | Business rules embedded in the agent prompt; tasks too broad for reliable output | Universal Agent Boundary — domain rules live in the project repo, not the agent |
| Implicit Assumption / Context Drift | LLM eagerness to execute without verifying intent; accumulated session state | Micro-Protocol — Mirror → Challenge → Plan → Execute with mandatory human approval |
| Unvalidated Mutations | Implicit trust in LLM output; no cross-referencing of declared vs. actual state | Gateway hallucination checks on every write — mismatched payloads are rejected |
