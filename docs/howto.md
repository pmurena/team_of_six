# Team of Six — How-To Guide

**Human-in-the-Loop Agentic Coding with the Ghost Engine**

This guide demonstrates the practical application of the **Cognitive Cadence** and the **Micro-Protocol** in a daily workflow, using a complete walkthrough example: building a Python calculator.

---

## How TOS Works

TOS operates on a strict separation of powers between three roles:

| Role | Responsibility |
|---|---|
| **Principal Architect** | You. Agrees on architecture in chat, transmits payloads to the engine, and reviews Pull Requests. Nothing executes without your trigger. |
| **The Ghost** | The LLM agent. Has zero shell access. Outputs structured protocol blocks as plain text. Cannot execute anything directly. |
| **The Engine** | The `tos` binary and its modules. Runs as a dedicated OS user via sudo. Parses inbox protocol blocks and executes Git and GitHub operations. |

TOS is editor-agnostic. All communication flows through two plain text files — `inbox.md` and `outbox.md` — the IPC ribbon. Any editor, IDE, or terminal can interact with TOS. The only requirement is the ability to read and write plain text files.

---

## Prerequisites

- TOS infrastructure deployed (`sudo ./inf/tos_deploy.sh`)
- GitHub token at `/mnt/team_of_six/.local/conf/.token` with `chmod 400`
- Your user added to engine users (`sudo ./inf/tos_add_user.sh <username>`)
- An initialized git repository with a GitHub remote (`git remote` must point to GitHub)
- GitHub CLI (`gh`) authenticated
- zsh (TOS is a collection of zsh scripts)

---

## The Anatomy of a Turn: The Micro-Protocol in Action

Before the walkthrough, understand the communication loop. The Ghost is forbidden from writing payloads until you approve its plan. Every interaction follows this structure:

**You (The Architect):**
> "Read the Outbox. We are in the Red Phase. Write a failing test for the User Login task we scaffolded earlier."

**The Ghost (Following the Micro-Protocol):**

> **[MIRROR]** I understand we are entering the Red Phase for Trinity #1. Based on `outbox.md`, I need to write a failing test for the User Login function.
>
> **[CHALLENGE]** I see in `docs/architecture.md` that we strictly use JWT tokens, but the scaffolding task mentions session cookies. If I write a test expecting a session cookie, it will violate our architectural baseline.
>
> **[PLAN]**
> 1. Write an integration test that sends valid credentials to `/login`.
> 2. Assert that the response returns a `200 OK` with a valid JWT payload in the body — NOT a cookie.
>
> Do I have your approval to execute this plan?

**You (The Architect):**
> "Excellent catch on the JWT rule. Approved. Execute."

**The Ghost (Execution):**
> *Outputs the `===TOS_META_START===` + `===TOS_FILE_START===` payload.*

---

## Walkthrough: Building a Python Calculator

We will scope all four arithmetic operations as GitHub Issues, but implement only addition — demonstrating the full TOS loop from issue creation through to a merged Pull Request.

---

### Step 0 — Initialize the Architect Repository

Before the engine can provision a sandbox, the project must exist on GitHub. The engine uses your local repository's `origin` remote to clone the code into the Ghost's secure chamber.

1. Create a local folder and initialize git
2. Establish a Git history with an initial `README.md`
3. Create a remote repository on GitHub and link it as `origin`
4. Push the initial commit

> **Why this matters:** The `tos calculator sync start` command relies on reading `git remote get-url origin`. If the remote does not exist, the engine will refuse to proceed.

---

### Step 1 — Provision the Project Sandbox

From within your Architect repository, run:

```sh
tos calculator sync start
```

This command:
1. Reads the GitHub remote URL from the current repo
2. Clones the repository into the locked sandbox at `/mnt/team_of_six/tos_home/${USER}/sandbox/calculator`
3. Configures the sandbox git identity as Team of Six (Ghost)
4. Lists all open GitHub Issues

> **What just happened?** The sandbox is owned by the `team_of_six` OS user (`chmod 700`). You cannot enter it directly. All file writes go through the engine gateway.

---

### Step 2 — Enter The Sanctuary and Scope the Work (Phase 1: Scaffolding)

Open Trinity 0 — The Sanctuary:

```sh
tos calculator sync trinity 0
```

Read the outbox into your Ghost session:

```sh
cat /mnt/team_of_six/tos_home/$USER/.ipc/outbox.md
```

Paste the outbox into a new conversation with your Ghost and begin the Scaffolding phase:

```text
We are building a basic Python calculator module.
I need one GitHub Issue for each of the four arithmetic operations:
addition, subtraction, multiplication, and division.
Each issue should describe the function signature and expected behaviour.
Before generating the payload, please outline your plan for these issues.
```

The Ghost will execute the Micro-Protocol: Mirror its understanding, Challenge any ambiguities (e.g., "Should division raise `ValueError` or `ZeroDivisionError` for zero?"), and present a Plan. Review it. Once satisfied:

```text
Agreed. Proceed with generating the issue blocks.
```

The Ghost outputs `===TOS_ISSUE_START===` blocks as raw text (never wrapped in markdown fences):

```
===TOS_ISSUE_START===
TITLE=Implement add(a, b) function
BODY=Implement a function add(a, b) that returns the sum of two numbers.
Function signature: def add(a: float, b: float) -> float
Must include a test file test_calculator.py with at least 3 test cases.
===TOS_ISSUE_END===
```

Write the Ghost's output to the inbox and create the issues:

```sh
cat > /mnt/team_of_six/tos_home/$USER/.ipc/inbox.md << 'EOF'
[paste Ghost output here]
EOF

tos calculator write tasks
```

You now have four GitHub Issues. We will work Issue #1 (addition) through to completion.

---

### Step 3 — Cross the Event Horizon (Open a Workspace)

Select Issue #1 and acquire the Hard-Lock:

```sh
tos calculator sync trinity 1
```

This command:
- Checks out branch `tos-work-1`
- Fetches the full Issue #1 thread from GitHub
- Generates a repository file map
- Writes everything to `outbox.md`

**Start every Ghost session by feeding it a fresh outbox.** The outbox is the Ghost's entire reality.

---

### Step 4 — Red Phase (Write the Failing Test)

TOS follows strict TDD. The first thing the Ghost writes is a failing test — no implementation yet.

Feed the Ghost the fresh outbox and prompt the Micro-Protocol:

```text
We are on Issue #1: add(a, b). We are in the Red Phase.
Before writing code, confirm your test strategy.
What test cases will you write and what will the file be called?
```

The Ghost will Mirror its understanding, Challenge any edge cases (e.g., "Should we test float precision or only integers?"), and propose a Plan. Once you approve:

```text
Approved. Execute.
```

The Ghost outputs the payload:

```
===TOS_META_START===
TARGET_PROJECT=calculator
TARGET_TRINITY=1
TITLE=Red: failing test for add(a, b)
BODY=Adds test_calculator.py with failing cases for the add function. No implementation exists yet.
===TOS_META_END===

===TOS_FILE_START: test_calculator.py===
import pytest
from calculator import add

def test_add_positive():
    assert add(2, 3) == 5

def test_add_negative():
    assert add(-1, -1) == -2

def test_add_floats():
    assert add(0.1, 0.2) == pytest.approx(0.3)
===TOS_FILE_END===
```

**Do not manually proofread this raw text.** You already agreed on the strategy in the Mirror phase. Copy the Ghost's output to the inbox and trigger the engine:

```sh
tos calculator write code
```

The engine writes the files to the sandbox, commits, and opens a Pull Request on GitHub. **Your review happens on the Pull Request, not in the chat.**

---

### Step 4.5 — PR Review and Async Feedback

After the Ghost pushes code, review on GitHub. When bringing feedback back to the Ghost, use Async Review Flags:

| Flag | Ghost Behaviour |
|---|---|
| `[FIXME]` | STOP. Generate a `write code` payload to fix the issue immediately. |
| `[CHALLENGE]` | STOP. Enter Mirror Phase. Defend or adjust logic before writing code. |
| `[QUESTION]` | INFO. Answer using a `write comment` payload — posted directly to the GitHub thread. |
| `[TODO]` | DEFER. Generate a `TOS_ISSUE_START` payload for a future Trinity. |

**Example:**
> *"[FIXME] The test fails for division by zero. [QUESTION] Should we raise `ValueError` or `ZeroDivisionError`?"*

The Ghost outputs a `TOS_META` + `TOS_FILE` block to fix the code, then a `TOS_COMMENT` block answering the question. Route each through the appropriate engine command.

---

### Step 5 — Green Phase (Implement Addition)

With the failing test merged into the PR, the Ghost writes the implementation.

Prompt the Micro-Protocol:

```text
We are in the Green Phase for Issue #1. Read the current outbox. Write the minimum implementation to make the tests pass.
```

Ghost: Mirror → Challenge → Plan → (await approval) → Execute.

After transmitting the payload via `tos calculator write code`, verify locally:

```sh
gh pr checkout 1
pytest test_calculator.py -v
```

All tests must be green before proceeding to Refactor.

---

### Step 6 — Refactor Phase

With tests green, clean up:

```text
Refactor phase: improve docstrings, apply type hints, add a README section for the add function.
Do not change test behaviour.
```

Ghost: Mirror → Challenge → Plan → (await approval) → Execute.

Transmit via `tos calculator write code`.

---

### Step 7 — Retrospect Phase

Before merging, the Ghost must persist its learnings:

```text
Retrospect phase: document any domain rules or architectural decisions made during this Trinity.
Update the project README and docs/ as needed.
```

If the Ghost discovered anything worth recording (e.g., "float precision must always use `pytest.approx`"), it outputs a `write code` payload updating the documentation.

---

### Step 8 — Merge and Close

Review the final PR on GitHub. The diff should show the test cases, the implementation, and the documentation. Merge from GitHub, then close the Trinity:

```sh
tos calculator remove 1
```

This closes the PR and Issue, deletes the branch (local and remote), and returns the engine to The Sanctuary.

For the next issue, repeat from Step 3: `tos calculator sync trinity <ID>`.

---

## Protocol Tag Reference

*(Must be output as raw text — never wrapped in markdown code fences)*

```
# Code update (tos <project> write code):
===TOS_META_START===
TARGET_PROJECT=projectA
TARGET_TRINITY=1
TITLE=Short commit and PR title
BODY=Detailed description of what was changed and why.
===TOS_META_END===

===TOS_FILE_START: path/to/file.py===
[raw file content — completely overwrites the target file]
===TOS_FILE_END===

# Batch issue creation (tos <project> write tasks):
===TOS_ISSUE_START===
TITLE=Issue title
BODY=Issue description.
===TOS_ISSUE_END===

# Comment on PR/Issue (tos <project> write comment):
===TOS_COMMENT_START===
TARGET=1
BODY=Your comment text here.
===TOS_COMMENT_END===
```

---

## Workflow Commands Quick Reference

| Command | What it does |
|---|---|
| `tos <project> sync start` | Clone repo into sandbox, list open issues |
| `tos <project> sync trinity 0` | Enter The Sanctuary (brainstorming mode) |
| `tos <project> sync trinity <ID>` | Cross Event Horizon — Hard-Lock, generate Outbox |
| `tos <project> sync peek <files>` | Inject specific files into the active Outbox |
| `tos <project> write code` | Parse `TOS_META` + `TOS_FILE` blocks, commit and push PR |
| `tos <project> write comment` | Parse `TOS_COMMENT` blocks, post to GitHub |
| `tos <project> write tasks` | Parse `TOS_ISSUE` blocks, create GitHub Issues |
| `tos <project> remove <ID>` | Merge PR, close issue, delete branch, drop lock |
