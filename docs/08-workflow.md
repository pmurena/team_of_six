# Workflow: The Cognitive Cadence

The Team of Six operates on a strictly deterministic workflow designed to bound Large Language Model (LLM) context, prevent hallucination, and guarantee code quality.

We do not simply "ask the AI to code." We force the AI into a rigid **Cognitive Cadence**. This cadence is divided into **Macro-Phases** (the lifecycle of a feature) and a **Micro-Protocol** (the required communication loop the Ghost must execute within every single phase).

---

## The Event Horizon: Sanctuary vs. Workspace

Before understanding the phases, you must understand the Event Horizon.

- **The Sanctuary (Trinity 0):** This is the baseline, read-only state of the project (`main` branch). Here, the Architect and the Ghost are allowed to engage in "wild brainstorming." You can discuss broad architecture, debate paradigms, and create Work Breakdown Structures (WBS). No code is written here.
- **The Workspace (Trinity 1+):** Once a specific task is selected, the Architect acquires a Hard-Lock (`tos <project> sync trinity <ID>`). This is the Event Horizon. Wild creativity is now strictly forbidden. The Ghost is locked into an Ephemeral Outbox and must execute with surgical precision.

The Event Horizon is enforced mechanically. The engine will reject a `write code` payload if the outbox indicates Trinity 0.

---

## 1. The Macro-Phases (The Feature Lifecycle)

Every feature or issue must strictly pass through these five phases in order. Skipping phases is a framework violation.

### Phase 1: Scaffolding (Runs in Trinity 0)

- **Goal:** Conceptual alignment before a single line of code is committed.
- **Action:** Brainstorming, creating the Work Breakdown Structure (WBS), and defining architectural choices. The Ghost synthesizes the discussion into discrete `1:1:1` tickets — one issue per atomic deliverable. It outputs `===TOS_ISSUE_START===` blocks. **STOP.** The Architect selects ONE issue, runs `tos <project> sync trinity <ID>`, and provides the new branch context before any further work proceeds.
- **Output:** A set of GitHub Issues. No code.

### Phase 2: Red (Runs in Trinity 1+)

- **Goal:** Bounding the context with a verifiable, failing assertion.
- **Action:** The Ghost writes a failing test for *one* of the specific concepts discussed in Scaffolding. We follow the **5-3-2 Test Strategy**: 5 Unit tests, 3 Integration tests, 2 End-to-End tests. Writing a failing test forces the LLM to anchor its reasoning to a highly specific, verifiable goal before generating heavy implementation syntax. Tests must fail *functionally*, not structurally (i.e., they must import correctly and assert against a real interface, not a non-existent one).
- **Output:** A `write code` payload containing only test files. No implementation.

### Phase 3: Green (Runs in Trinity 1+)

- **Goal:** Passing the Red test with the minimum viable implementation.
- **Action:** The Ghost writes the absolute minimum code required to make the failing tests pass. No gold-plating, no premature abstraction. If the test passes with a naive implementation, that is the correct Green output.
- **Output:** A `write code` payload containing the implementation. Tests must pass.

### Phase 4: Refactor (Runs in Trinity 1+)

- **Goal:** Architectural hygiene without regression.
- **Action:** The Ghost cleans up the implementation: removes duplication, improves naming, adds docstrings, applies the project's style conventions. The constraint is absolute — the passing tests from Phase 3 must remain passing. If a refactor breaks a test, it is not a refactor, it is a new change and must go through a new Red phase.
- **Output:** A `write code` payload containing cleaned implementation and updated documentation. Test results unchanged.

### Phase 5: Retrospect (Runs in Trinity 1+)

- **Goal:** Wisdom Persistence — ensuring the Trinity's knowledge survives the session.
- **Action:** The Ghost evaluates the journey. If it discovered a new project-specific domain rule, encountered architectural friction, clarified an ambiguous convention, or identified technical debt deferred for later, it documents this knowledge in the target project's standard documentation (`README.md`, `docs/`, or wherever the project's conventions dictate). This phase is mandatory. A Trinity that ends without a Retrospect has failed to persist its value.
- **Output:** A `write code` payload updating documentation files. Optionally, `===TOS_ISSUE_START===` blocks for deferred work.

---

## 2. The Micro-Protocol (The HITL Engine)

To move through *any* of the Macro-Phases, the Ghost must execute a strict 4-step communication loop with the human Architect. The Ghost is never permitted to blindly act.

This protocol is not optional and is not subject to the Architect's preference to "just get it done." Execution without Mirroring and Planning is a critical violation of the framework.

For every single interaction, the Ghost must output:

### Step 1: Mirror
> "Here is what I understand you want to achieve in this phase."

The Ghost restates the Architect's intent in its own words, grounded in the current Outbox. This catches misalignment before any work is done. If the Mirror is wrong, the Architect corrects it here — before planning, before execution.

### Step 2: Challenge
> "Here are the logical flaws, pitfalls, or missing domain rules I see in this approach."

The Ghost acts as an adversarial reviewer of its own upcoming plan. It surfaces edge cases, architectural conflicts, missing test coverage, and gaps in the domain model as revealed by the Outbox. This is the Architect's primary safety check. A Ghost that never challenges is a Ghost that is hallucinating compliance.

### Step 3: Plan
> "Here is my step-by-step execution plan."

A numbered list of exactly what the Ghost intends to do — which files will be created or modified, what the test assertions will be, what the commit title will say. The Ghost must conclude with: *"Do I have your approval to execute this plan?"*

No payload is output yet.

### Step 4: Execute
> *[Requires explicit Human Approval]*

Only after the Architect replies with approval may the Ghost output the actual `write` payload. This is the `===TOS_META_START===` block and accompanying `===TOS_FILE_START===` blocks.

---

## 3. The Async Review Protocol

After the Ghost pushes code to a Pull Request, the Architect reviews on GitHub. When bringing feedback back into the chat, use these flags to route the Ghost's response precisely:

| Flag | Ghost Behaviour |
|---|---|
| `[FIXME]` | **STOP.** Generate a `write code` payload immediately to correct the issue. |
| `[CHALLENGE]` | **STOP.** Enter the Mirror Phase. Defend or adjust the logic before writing any code. |
| `[QUESTION]` | **INFO.** Answer using a `write comment` payload — the answer is posted to the GitHub PR/Issue thread. |
| `[TODO]` | **DEFER.** Generate a `===TOS_ISSUE_START===` payload for the next Trinity. Do not fix it now. |

**Example:**
> *"[FIXME] The test fails for division by zero. [QUESTION] Should we raise a `ValueError` or `ZeroDivisionError`?"*

The Ghost outputs a `TOS_META` + `TOS_FILE` block to fix the code, then a separate `TOS_COMMENT` block answering the question. The Architect routes each payload to the appropriate engine command.

---

## 4. Engine Command Reference

| Command | Action |
|---|---|
| `tos <project> sync start` | Clone repo into sandbox, list open issues |
| `tos <project> sync trinity 0` | Enter The Sanctuary — brainstorming mode, no Hard-Lock |
| `tos <project> sync trinity <ID>` | Cross the Event Horizon — acquire Hard-Lock, generate Ephemeral Outbox |
| `tos <project> sync peek <files...>` | Surgically append specific files to the active Outbox |
| `tos <project> write code` | Parse inbox `TOS_META` + `TOS_FILE` blocks, commit and push PR |
| `tos <project> write comment` | Parse inbox `TOS_COMMENT` blocks, post to GitHub PR/Issue |
| `tos <project> write tasks` | Parse inbox `TOS_ISSUE` blocks, create GitHub Issues |
| `tos <project> remove <ID>` | Merge PR, close issue, delete branch, drop Hard-Lock, return to Sanctuary |
