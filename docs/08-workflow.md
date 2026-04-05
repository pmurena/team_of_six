# Workflow: The TDD Cycle

Every task follows a structured loop to ensure the **Contextual Trinity** remains intact.

### Stage 1: Scoping (The Intent)
* **Action:** Architect and Ghost discuss the WBS in chat.
* **Result:** Ghost outputs `===TOS_ISSUE_START===` blocks.
* **Engine:** `tos work new` creates the GitHub Issues.

### Stage 2: Red Phase (The Change)
* **Action:** Architect selects one issue: `tos work <ID>`.
* **Protocol:** Ghost outputs a failing test (5-3-2 Strategy) using `===TOS_FILE_START===`.
* **Engine:** `tos write code` pushes a PR.

### Stage 3: Async Review
* **Action:** Architect reviews the PR on GitHub or in Neovim.
* **Flags:** Use `[FIXME]`, `[CHALLENGE]`, or `[QUESTION]` in chat to route the Ghost's next action.

### Stage 4: Green & Refactor (The Baseline)
* **Action:** Ghost outputs implementation and documentation updates.
* **Result:** Tests pass; PR is merged; the Baseline is updated.
