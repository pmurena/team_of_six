← [04-protocol.md](04-protocol.md) | Next: [06-security.md](06-security.md) →

---

# 05 — The Development Workflow

This document walks through the complete TOS development lifecycle — from initialising a project to merging finished work — in the order you will actually encounter each step. It is written as a narrative rather than a command reference, because understanding *why* each step happens is as important as knowing *what* to type.

The tutorial at `test/interactive_tutorial.zsh` walks through the same lifecycle interactively. Reading this document first will make the tutorial much easier to follow.

---

## Before You Begin: Prerequisites

TOS operates on the assumption that:

- You have run `inf/tos_deploy.sh` as root on the machine where the Ghost will operate. This creates the `team_of_six` system user, provisions the control plane at `/mnt/team_of_six/`, installs the TOS binaries, and writes the sudoers entry that allows group members to escalate to the Ghost without a password.
- Your user account has been added to the `team_of_six` group via `inf/tos_add_user.sh`. You will need to log out and back in for the group membership to take effect.
- A GitHub personal access token (or GitHub App token) with repository and issue permissions has been placed at `/mnt/team_of_six/.local/conf/.token`.
- The `gh` CLI tool is installed and you have confirmed it can authenticate with the token.

---

## Phase 0: Establishing Remote Truth

TOS works against a real GitHub repository. Before the Ghost can do anything, there must be a repository to work on. If you are starting a new project:

```zsh
mkdir myproject && cd myproject
git init
echo "# My Project" > README.md
git add . && git commit -m "Initial commit"
git branch -M main
gh repo create myproject --private --source=. --remote=origin --push
```

This is the Architect's domain — creating the repository, establishing the initial structure, pushing to GitHub. TOS calls this "establishing Remote Truth": the GitHub repository is the authoritative state that the Ghost will mirror and work against. Everything the Ghost does is eventually reflected back to this remote.

Run all TOS commands from within this repository directory. The gateway reads the remote URL from `git remote get-url origin` to know where to clone from.

---

## Phase 1: Provisioning the Sandbox

```zsh
tos myproject sync start
```

This command provisions the Ghost's isolated sandbox for your project. It clones the repository from GitHub into `/mnt/team_of_six/sandbox/<your-user>/myproject/`, configures the Git identity for the Ghost's commits, and acquires a Trinity 0 soft lock.

You will see the sandbox being created and a list of open issues (likely empty at this point). After this command completes, the Ghost has a clean, isolated copy of the repository and an active soft lock. The gateway's workspace safety audit will now pass on every subsequent invocation.

The sandbox is entirely separate from your own working copy of the repository. You may continue to work in your local checkout normally — the Ghost's sandbox does not interfere with it.

---

## Phase 2: Scoping (Creating Issues)

The Ghost cannot start writing code until there is an issue to work against. The Architect works with the LLM to define the work, then the LLM produces a payload that creates the issues:

Ask your LLM: *"I need to implement a calculator module in Zsh. Scope this into atomic issues."*

The LLM should produce a payload like:

```
===TOS_ISSUE_START===
TITLE=Implement add() function
BODY=Implement integer addition using native Zsh arithmetic. Should handle negative numbers.
===TOS_ISSUE_END===
===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Implement integer subtraction using native Zsh arithmetic.
===TOS_ISSUE_END===
```

Write this payload to the inbox (or use the Neovim plugin — see [07-neovim-plugin.md](07-neovim-plugin.md)), then run:

```zsh
tos myproject write tasks
```

The Ghost reads the inbox, creates the issues on GitHub, and clears the inbox. You can verify with `gh issue list`. Each issue now has a number — these are your trinity IDs.

Note that this command runs under the soft lock (Trinity 0) and does not require a hard lock. Creating issues is a planning operation, and the write policy permits it in the baseline state.

---

## Phase 3: Opening a Workspace

```zsh
tos myproject sync trinity 1
```

This transitions from the sanctuary state (Trinity 0) to active work on issue #1. The Atomic Handover sequence runs: any existing hard lock is pushed and released, a new hard lock is acquired for Trinity 1, the branch `tos-work-1` is checked out (or created if it does not exist), and the Clean Room Snapshot is generated and written to the outbox.

The outbox now contains a complete picture of the current state: the issue description and any comments, the diff against main (empty at this point), and the repository file list. This is what you provide to the LLM as context for the next session.

From this point, `tos myproject write code` is permitted. The Ghost is locked into Trinity 1 and can only commit to `tos-work-1`.

---

## Phase 4: Injecting Existing Context (Peek)

Before asking the LLM to write new code, it is often useful to show it what already exists. The peek command reads a specific file from the sandbox and appends it to the outbox:

```zsh
tos myproject sync peek utils.zsh
```

After this, the outbox contains both the Clean Room Snapshot and the full content of `utils.zsh`. The LLM can see the existing `log()` function and know to use it in any new code it produces, rather than inventing its own logging mechanism.

This is the surgical context injection pattern: rather than pasting entire files into the chat, you inject exactly what the LLM needs to know, nothing more.

---

## Phase 5: The Red Phase (Failing Tests)

TOS encourages a TDD cycle: write the failing test first, then implement, then refactor. The LLM produces a payload for the test:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Test suite for the add() function. Tests will fail until implementation exists.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log "Running tests..."
[[ "$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
```

Write to inbox, then:

```zsh
tos myproject write code
```

The Ghost validates the payload, writes the test file to the sandbox, commits it to `tos-work-1`, and pushes to origin. You can verify:

```zsh
git fetch origin
git diff origin/main...origin/tos-work-1
```

---

## Phase 6: Review and Routing

The Architect reviews the Ghost's work directly on the branch. This may involve:

- Checking out the branch locally to run the test: `git checkout tos-work-1 && zsh test_calculator.zsh`
- Adding inline review tags to files: comments marked `[FIXME]`, `[QUESTION]`, `[CHALLENGE]`, `[TODO]`
- Posting questions to the issue thread: `gh issue comment 1 -b "[QUESTION] Should we handle non-integer inputs?"`

After adding review tags, commit and push:

```zsh
git commit -am "Architect review: inline tags" && git push origin tos-work-1
```

Then sync the changes back to the Ghost's context:

```zsh
tos myproject sync trinity 1
```

This regenerates the Clean Room Snapshot, which now includes the Architect's review comments from the issue thread and the updated diff showing the inline tags. The LLM reads the updated outbox and produces response payloads — answers to questions, proposed fixes for the flagged items — using `write comment` for discussion and `write code` for fixes.

---

## Phase 7: The Green Phase (Implementation)

The LLM has seen the failing test and the review feedback. It now produces the implementation:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=1
TITLE=Green: implement add()
BODY=Implements add() to satisfy the failing test. Resolves [FIXME] from review.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
```

After `tos myproject write code`, the Architect checks out the branch, runs the tests locally, and verifies they pass. The Green phase is complete when the tests pass on the branch.

---

## Phase 8: Refactor and Documentation

With passing tests, the LLM can safely refactor — improving code clarity, adding documentation, tightening up edge cases — without breaking functionality. The same `write code` command applies. Each refactor payload includes updated files; the Ghost commits them to the same branch.

The Retrospective is a special refactor: the LLM updates its own rule files in `llm_agents/` based on what it learned during the trinity. These files are committed to the repository and become part of the context for all future sessions. The Agent's constraints evolve with the project.

---

## Phase 9: Merge and Teardown

When the Architect is satisfied with the work:

```zsh
tos myproject remove 1
```

This runs the Traceable Finality sequence: posts a closing comment to the issue thread with the final revision hash, closes the PR, closes the issue, deletes the local branch, releases the hard lock, and transitions back to Trinity 0 via `sync trinity 0`. The outbox is refreshed with a new Clean Room Snapshot reflecting the current state of main.

The repository now contains the merged work. Issue #1 is closed. The Ghost is back in the sanctuary state, ready to begin Trinity 2.

---

## The Retrospective Pattern

Before closing a trinity, it is worth having the LLM review what it learned and propose updates to `llm_agents/code.md`. This file contains rules that will be included in the context snapshot for all future sessions. If the LLM discovered during this trinity that a particular pattern causes problems, or that a particular approach works well for this codebase, it can encode that knowledge in its own rule file — which the Ghost will then commit and which will persist across all future work.

This is the self-improvement loop: the Agent's constraints evolve with the project, becoming increasingly calibrated to the specific patterns and requirements of the codebase over time.

---

← [04-protocol.md](04-protocol.md) | Next: [06-security.md](06-security.md) →
