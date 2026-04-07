# The Contextual Trinity

The Contextual Trinity is the foundational data structure of the Team of Six framework. It solves the LLM "Context Drift" problem by physically binding the AI's reasoning window to a localized, isolated reality.

We prevent cognitive collapse by mapping the agent's operational bounds directly to version control primitives.

---

## The 1:1:1 Bond

A Trinity is a strict 1:1:1 relationship between three version control artifacts:

### 1. One GitHub Issue (The Intent)
- **Definition:** The bounded scope of *why* we are making a change.
- **Function:** It focuses goal-seeking behaviour. If a proposal does not serve the Issue, it is discarded, preventing feature creep and architectural tangents. It is the definition of the problem — immutable during the Trinity's lifetime.

### 2. One Feature Branch (The Baseline)
- **Definition:** The foundational, deterministic state of the codebase (The Reality).
- **Function:** This grounds the LLM in the factual, working reality of the code as it exists *now*, providing a solid anchor before any new logic is applied. All mutations happen here and nowhere else.

### 3. One Pull Request (The Change)
- **Definition:** The exact, isolated set of modifications being proposed (The Context).
- **Function:** It scopes the LLM's working memory strictly to what is currently being altered. This eliminates context drift and ensures reviews are focused on a clear, auditable diff.

---

## The Execution Sandbox

A Trinity is **not** a place for brainstorming. Brainstorming belongs in Trinity 0 (The Sanctuary).

When an Architect runs `tos <project> sync trinity <ID>`, the engine acquires a persistent **Hard-Lock**. It generates an **Ephemeral Outbox** — a clean-room snapshot containing only:
- The active PR thread
- The issue comments
- The specific files the Architect chooses to `sync peek`

Inside this Execution Sandbox, the Ghost is blind to everything else. It cannot see other branches, other issues, or the general shape of the repository beyond what the Outbox explicitly provides. It must execute the Red-Green-Refactor loop based *only* on the evidence in the Outbox.

This isolation is not a limitation — it is the mechanism that prevents hallucination. A Ghost that cannot see irrelevant context cannot be confused by it.

---

## Trinity 0: The Sanctuary

Trinity 0 is a special, permanent state representing the baseline `main` branch. It has no Hard-Lock, no PR, and no branch. It is the read-only reality of the project before any work begins.

In Trinity 0, the Architect and Ghost are permitted to engage in "wild brainstorming" — architecture debates, Work Breakdown Structure generation, paradigm discussions. No `write code` payloads may be output in Trinity 0. The Event Horizon has not yet been crossed.

---

## The Event Horizon

The moment an Architect runs `tos <project> sync trinity <ID>` (where ID > 0), the Event Horizon is crossed. This is a one-way gate within a session:

- Wild creativity is deactivated
- The Ghost is locked to the Ephemeral Outbox
- Only the Micro-Protocol (Mirror → Challenge → Plan → Execute) may be used
- Code payloads are now permitted — and required to follow TDD

---

## The Wisdom Repository

A Trinity session must culminate in the **Retrospect Phase**. Because the Trinity is an isolated reasoning chamber, the epiphanies, technical debt discoveries, and domain rules established during the session will be lost when the chat window closes.

Before the Architect merges the PR and drops the lock (`tos remove <ID>`), the Ghost must write its learnings into the target repository's documentation files — `README.md`, `docs/`, or wherever the project's conventions dictate.

The Trinity acts as a temporary forge. The project's Git repository is the permanent Wisdom Repository. A Trinity that ends without a Retrospect has failed to persist its value.
