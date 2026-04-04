# Team of Six — How-To Guide

**Human-in-the-Loop Agentic Coding with the Ghost Engine**

*Walkthrough example: Building a Calculator — scoping all four operations, implementing addition*

---

## Overview

Team of Six (tos) is a human-in-the-loop agentic coding framework. The LLM (called the Ghost) has no shell access. It outputs structured text blocks which you pass to the local engine via the inbox file. The engine parses and executes those blocks as a dedicated OS user.

tos is editor-agnostic. The engine communicates exclusively through two plain text files — `inbox.md` and `outbox.md` — referred to as the IPC ribbon. Any editor, IDE, script, or even a human typing by hand can interact with tos. The only requirement is the ability to read and write plain text files. Editor plugins are conveniences, not dependencies.

This guide walks through the complete workflow using a simple Python calculator as the example project. We will scope all four arithmetic operations as GitHub Issues, but only implement addition — demonstrating the full tos loop from issue creation through to a merged Pull Request.

---

## How tos Works

tos operates on a strict separation of powers between three roles:

| Role | Responsibility |
|---|---|
| **Principal Architect** | You. Agrees on architecture in chat, transmits payloads to the engine, and reviews Pull Requests. Nothing executes without your trigger. |
| **The Ghost** | The LLM agent. Has zero shell access. Outputs structured protocol blocks as plain text. Cannot execute anything directly. |
| **The Engine** | The `tos` binary and its modules. Runs as a dedicated OS user via sudo. Parses inbox protocol blocks and executes Git and GitHub operations. |

### The IPC Ribbon

All communication between you, the Ghost, and the engine flows through two files:

- **`inbox.md`** — You write here. Paste the Ghost's protocol block output into this file, then trigger the engine command. The engine reads, executes, and clears it.
- **`outbox.md`** — The engine writes here. Contains the current issue context, file map, and diff. You feed this to the Ghost as its working context.

Both files live at `/mnt/team_of_six/tos_home/${USER}/.ipc/`. Your editor plugin, script, or manual workflow reads and writes these files directly. The engine does not care what produced the inbox content.

---

## Prerequisites

Before starting this walkthrough, ensure the following are in place:

- tos is a collection of zsh scripts. Make sure you're running the engine in zsh for compliance.
- tos infrastructure deployed (`sudo ./inf/tos_deploy.sh`)
- GitHub token placed at `/mnt/team_of_six/.local/conf/.token` with `chmod 400`
- Your user added to the `team_of_six` engine users (`sudo ./inf/tos_add_user.sh <username>`)
- An initialized git repository for your project (`git remote` must point to GitHub)
- GitHub CLI (`gh`) authenticated
- A way to read and write plain text files — any editor, terminal, or script

---

## Step 0 — Initialize the Architect Repository

Before the engine can provision a sandbox, the project must exist on GitHub. The engine uses your local repository's `origin` remote to clone the code into the Ghost's secure chamber.

This setup sequence:
1. Creates a local folder for you (the Architect) to work in.
2. Establishes a Git history with an initial `README.md`.
3. Creates a remote repository on GitHub and links it as `origin`.

> **Why this matters:** The `tos calculator work start` command relies on reading `git remote get-url origin`. If the remote doesn't exist, the engine will refuse to proceed. By pushing this initial commit, you ensure the sandbox has a remote truth to clone.

---
## Step 1 — Provision the Project Sandbox

From within your Architect repository (the repo you want the Ghost to work on), run:

```sh
tos calculator work start
```

This command:
1. Reads the GitHub remote URL from the current repo
2. Clones the repository into the locked sandbox at `/mnt/team_of_six/tos_home/${USER}/sandbox/calculator`
3. Configures the sandbox git identity as Team of Six (Ghost)
4. Lists all open GitHub Issues so you can orient the Ghost

> **What just happened?** The sandbox is owned by the `team_of_six` OS user (`chmod 700`). You cannot enter it directly. All file writes go through the engine, which means every change the Ghost makes is mediated by the tos gateway. The project name — `calculator` in this case — is used by every subsequent `tos` command for context validation.

---

## Step 2 — Scope the Work (Create Issues)

tos is issue-driven. Before the Ghost writes a single line of code, the work must be broken down into GitHub Issues. 

### 2a — Load the Outbox and Initiate Scoping
Read the current outbox into your Ghost session as context:

```sh
cat /mnt/team_of_six/tos_home/$USER/.ipc/outbox.md
```

Paste this content into a new conversation with your Ghost (LLM). Then prompt it to begin the scoping phase:

```text
We are building a basic Python calculator module.
I need one GitHub Issue for each of the four arithmetic operations:
addition, subtraction, multiplication, and division.
Each issue should describe the function signature and expected behaviour.
Before generating the payload, please outline your plan for these issues.
```

### 2b — Mirror Phase (Negotiation)
The Ghost will respond in plain English (no `TOS_` tags yet). It will outline the proposed titles, function signatures, and testing constraints for the four issues.

Review this plan. If you want changes (e.g., "Add a note that division must raise a specific exception for zero"), tell the Ghost now. Once you are satisfied with the proposed scope, give the command to execute.

### 2c — Execute: Generate the Payload
Tell the Ghost to output the protocol blocks:

```text
Agreed. Proceed with generating the issue blocks.
```

The Ghost will now respond with the `TOS_ISSUE_START` blocks — raw text, not wrapped in markdown code fences:

```text
===TOS_ISSUE_START===
TITLE=Implement add(a, b) function
BODY=Implement a function add(a, b) that returns the sum of two numbers.
Function signature: def add(a: float, b: float) -> float
Must include a test file test_calculator.py with at least 3 test cases.
===TOS_ISSUE_END===

===TOS_ISSUE_START===
TITLE=Implement subtract(a, b) function
BODY=Implement subtract(a, b) returning a minus b.
Function signature: def subtract(a: float, b: float) -> float
Must include test_subtract.py with at least 3 test cases.
===TOS_ISSUE_END===
``` 
*(It will generate all four)*

### 2d — Write to the Inbox
Copy the Ghost's entire output and write it to the inbox:

```sh
cat > /mnt/team_of_six/tos_home/$USER/.ipc/inbox.md << 'EOF'
[paste Ghost output here]
EOF
```

### 2e — Trigger the Engine
Trigger the engine to parse the inbox and create the GitHub Issues:

```sh
tos calculator work new
```

You now have four GitHub Issues. We will work Issue #1 (addition) through to completion.

---

## Step 3 — Open a Workspace for Issue #1

tos workspaces are branch-scoped. Opening a workspace for Issue #1 creates a dedicated branch and loads the issue context into the outbox.

```sh
tos calculator work 1
```

This command checks out a branch named `tos-work-1`, fetches the full Issue #1 thread from GitHub, generates a repository file map, and writes everything to `/mnt/team_of_six/tos_home/${USER}/.ipc/outbox.md`.

Start every Ghost session by feeding it a fresh outbox.

---

## Step 4 — Red Phase (Write the Failing Test)

tos follows strict TDD. The first thing the Ghost writes is a failing test — no implementation yet.

### 4a — Mirror Phase (Negotiation)
Ask the Ghost to confirm the test strategy before writing anything:

```text
We are on Issue #1: add(a, b). Before writing code,
confirm your test strategy. What test cases will you write
and what will the file be called?
```
The Ghost should confirm its plan (e.g., `test_calculator.py`). Once you agree, proceed.

### 4b — Execute: Transmit the Payload
Ask the Ghost to produce the failing test payload:

```text
Write the failing test file now. Red phase only — no implementation.
```

The Ghost outputs a code payload:

```text
===TOS_META_START===
TITLE=Red: failing test for add(a, b)
BODY=Adds test_calculator.py with three failing cases for the add function.
No implementation exists yet — this commit is intentionally red.
===TOS_META_END===

===TOS_FILE_START: test_calculator.py===
import pytest
from calculator import add

def test_add_positive():
    assert add(2, 3) == 5
===TOS_FILE_END===
```

**Do not manually proofread this raw text.** Reviewing unlinted, contextless plaintext is highly prone to error. You already agreed on the strategy in the Mirror phase. Simply copy the Ghost's output into `inbox.md` and trigger the engine:

```sh
tos calculator write code
```

The engine writes the files to the sandbox, commits them, and opens a Pull Request on GitHub. **Your review happens on the Pull Request.**

---

## Step 4.5 — PR Review and Async Feedback (Git as Truth)

After the Ghost pushes code to the Pull Request, your review happens on GitHub (or your IDE). When you bring your review feedback back to the Ghost, you use specific flags to trigger exact behaviors. This ensures all architectural decisions and fixes are routed through the correct protocols and preserved in the repository history.

When prompting the Ghost with your review feedback, use these Async Review Flags:

* `[FIXME]`: The Ghost stops and immediately generates a `write code` payload to fix the issue.
* `[CHALLENGE]`: The Ghost enters the Mirror Phase to defend or adjust its logic before writing any code.
* `[QUESTION]`: The Ghost answers your question using plain markdown (no `===TOS_` tags). You transmit this via `tos calculator write comment` to post the answer directly to the GitHub PR/Issue.
* `[TODO]`: The Ghost defers the item and generates a `TOS_ISSUE_START` payload for you to transmit via `work new`.

**Example Review Workflow:**
You review the PR on GitHub, spot a missing edge case, and prompt the Ghost:
*"[FIXME] The test fails for division by zero. [QUESTION] Should we raise a ValueError or ZeroDivisionError?"*

The Ghost will output a `TOS_META` and `TOS_FILE` block to fix the code, followed by a markdown comment answering your question. You pass the code payload through `tos calculator write code`, and the text payload through `tos calculator write comment`.

---

## Step 5 — Green Phase (Implement Addition)

Now the Ghost writes the implementation that makes the test pass.

### 5a — Mirror Phase
Confirm the implementation plan for `add(a, b)`.

### 5b — Execute: Transmit the Implementation
Ask the Ghost for the code payload, copy it to the inbox, and execute:

```sh
tos calculator write code
```

### 5c — Manual Verification (Testing)
You must now verify the code works. Because the Ghost wrote the files inside the secure sandbox, your local Architect repository does not have the code yet. Pull the Ghost's PR branch to test it locally:

```sh
gh pr checkout 1
pytest test_calculator.py -v
```

Follow the PR review steps of 4.5

---

## Step 6 — Refactor and Merge

With tests green, ask the Ghost to clean up and document:

```text
Refactor phase: improve docstrings and add a README section for the add function.
```

Transmit the final payload via `tos calculator write code`. 

Review the final state of the Pull Request on GitHub. The diff should show the test cases, the implementation, and the documentation. Merge the PR from GitHub. The Ghost's work for Issue #1 is complete.

For the next issue, repeat from Step 3: run `tos calculator work <ID>`.

---

## Quick Reference

### Engine Commands

| Command | What it does |
|---|---|
| `tos <project> work start` | Clone repo into sandbox, list open issues |
| `tos <project> work <ID>` | Open workspace for issue ID, generate outbox context |
| `tos <project> work new` | Parse inbox `TOS_ISSUE` blocks, create GitHub Issues |
| `tos <project> work peek <files>` | Append specific file contents to the outbox |
| `tos <project> write code` | Parse inbox `TOS_META` + `TOS_FILE` blocks, push PR |
| `tos <project> write comment` | Post inbox content as a comment on the active GitHub Issue or Pull Request |

### Protocol Tags
*(Must be output as raw text, never wrapped in markdown code fences)*

```text
# Code update (tos <project> write code):
===TOS_META_START===
TITLE=Short commit and PR title
BODY=Detailed description of what was changed and why.
===TOS_META_END===

===TOS_FILE_START: path/to/file.py===
[raw file content — completely overwrites the target file]
===TOS_FILE_END===

# Batch issue creation (tos <project> work new):
===TOS_ISSUE_START===
TITLE=Issue title
BODY=Issue description.
===TOS_ISSUE_END===
```

### The TDD Loop

| Stage | Ghost action | Your role |
|---|---|---|
| **Scope** | Output `TOS_ISSUE` blocks | Transmit via `work new`. Review issues on GitHub. |
| **Mirror** | Discuss architecture / tests | Provide feedback in chat |
| **Red/Green**| Output `TOS_FILE` blocks | Transmit via `write code`. **Review the resulting PR on GitHub.** Verify locally. |

### Async Review Flags (For the Chat Prompt)

| Flag | Effect |
|---|---|
| `[FIXME]` | Ghost stops and generates a `write code` payload immediately |
| `[CHALLENGE]` | Ghost enters Mirror Phase and defends or adjusts its logic |
| `[QUESTION]` | Ghost generates a `write comment` payload to ask on GitHub |
| `[TODO]` | Ghost defers the item and generates a `TOS_ISSUE` block |
