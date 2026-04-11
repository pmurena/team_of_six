← [04-protocol.md](04-protocol.md) | Next: [06-security.md](06-security.md) →

---

# 05 — The Development Workflow

This document walks through the complete TOS development lifecycle in the order you will encounter each step, following the five-phase taxonomy: **create**, **sync**, **write**, **close**, **delete**.

The interactive tutorial at `test/interactive_tutorial.zsh` demonstrates the same lifecycle with a real GitHub repository. Read this document first.

---

## Before You Begin

TOS assumes:

- `inf/tos_deploy.zsh` has been run as root on the machine where the Ghost will operate.
- Your user account has been added to the `team_of_six` group via `inf/tos_add_user.zsh`. Log out and back in for group membership to take effect.
- A GitHub personal access token with repository and issue permissions — but **without** `delete_repo` scope — has been placed at `/mnt/team_of_six/.local/conf/.token`.
- The `gh` CLI is installed and authenticated.

---

## Phase 0 — Establishing Remote Truth (create project)

TOS works against a real GitHub repository. If you are starting a new project, you must first create the remote repository. The Architect works with the Agent to define the project, and the Agent produces a payload:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TITLE=myproject
BODY=A fast integer calculator in Zsh.
===TOS_META_END===
```

Write this to the inbox and run:

```zsh
tos myproject create project
```

The Ghost runs `git init`, `gh repo create`, and establishes the remote repository entirely from within the sandbox. The Architect's own working tree is not touched.

---

## Phase 1 — Provisioning the Sandbox (sync start)

```zsh
tos myproject sync start
```

This provisions the Ghost's isolated sandbox. It clones the repository from GitHub into `/mnt/team_of_six/sandbox/<your-user>/myproject/`, configures the Ghost's Git identity, and acquires a Trinity 0 soft lock. The sandbox is entirely separate from your own working copy of the repository.

After this command, `tos myproject sync start` will reject if called again — the sandbox already exists.

---

## Phase 2 — Scoping (create issue)

The Ghost cannot start writing code until there is an issue to work against. The Agent produces a batch of Issue blocks:

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

Write to the inbox, then run:

```zsh
tos myproject create issue
```

The Ghost creates each issue on GitHub and clears the inbox. Each issue number becomes a Trinity ID. Verify with `gh issue list`.

---

## Phase 3 — Opening a Workspace (create trinity + sync trinity)

First, create the remote architecture for the Trinity:

```zsh
tos myproject create trinity 1
```

This creates branch `tos-work-1` from `origin/main` and opens a Draft PR linked to Issue #1.

Then align the sandbox and generate the Clean Room Snapshot:

```zsh
tos myproject sync trinity 1
```

This triggers the **Atomic Handover**: any existing hard lock is safely pushed and released, a new hard lock is acquired for Trinity 1, the branch is checked out, and the Clean Room Snapshot is written to the outbox. The outbox now contains the full issue description, any comments, the diff against main, and the repository file signature map.

Provide this outbox content to the Agent as context for the next session.

---

## Phase 4 — Injecting Existing Context (sync peek)

Before asking the Agent to write new code, you can inject specific file content from the sandbox:

```zsh
tos myproject sync peek utils.zsh
```

The outbox will contain both the Clean Room Snapshot and the full content of `utils.zsh`. The Agent can see the existing `log()` function and know to use it, rather than inventing its own.

Peek appends to the outbox — it does not reset the snapshot. Run `sync trinity <N>` to get a clean snapshot before starting a new session.

---

## Phase 5 — Declaring Intent (write plan)

Before the Agent is permitted to write code, it must declare the exact set of files it intends to touch. This is the **Intent Lock**. After the Agent produces its Plan step in the Micro-Protocol, it outputs a Plan block:

```
===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh
===TOS_PLAN_END===
```

Write to the inbox and run:

```zsh
tos myproject write plan
```

The Gateway writes these filenames to a `.manifest` visa in the control plane. From this point, any `write code` payload attempting to touch a file not in this list will be rejected with a `SEC-FAULT` before the sandbox is touched. The Intent Lock is set.

---

## Phase 6 — The Red Phase (write code, failing tests)

The Agent produces the failing test payload. Because the Intent Lock is active, only `calculator.zsh` and `test_calculator.zsh` are permitted:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Test suite for add(). Will fail until implementation exists.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./calculator.zsh 2>/dev/null || true
[[ "$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
```

Write to the inbox and run:

```zsh
tos myproject write code
```

The Ghost validates the payload against the manifest, truncates the inbox, writes the test file to the sandbox, commits it to `tos-work-1`, and pushes to origin. Verify:

```zsh
git fetch origin
git diff origin/main...origin/tos-work-1
```

---

## Phase 7 — Review and Routing

The Architect reviews the Ghost's work directly on the branch:

```zsh
git checkout tos-work-1 && zsh test_calculator.zsh
```

Add inline review tags (`[FIXME]`, `[QUESTION]`, `[CHALLENGE]`, `[TODO]`), commit and push, then sync back to the Agent's context:

```zsh
tos myproject sync trinity 1
```

The regenerated snapshot includes the Architect's review comments and the updated diff. The Agent reads the updated outbox and produces response payloads — answers via `write comment`, fixes via `write code`.

---

## Phase 8 — The Green Phase (write code, implementation)

The Agent produces the implementation payload. Both files are in the manifest:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=1
TITLE=Green: implement add()
BODY=Implements add() to satisfy the failing test. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
```

After `tos myproject write code`, the Architect checks out the branch, runs the tests locally, and verifies they pass.

---

## Phase 9 — Refactor and Retrospective (write code)

With passing tests, the Agent refactors and updates documentation. The same `write code` command applies — the manifest visa remains active. During the mandatory Retrospective phase, the Agent commits updates to `docs/` and `llm_agents/code.md`, encoding session learnings as versioned rules for future Trinities.

---

## Phase 10 — Trinity Closure (write trinity)

When the Architect is satisfied, the Agent produces a Trinity block. The `MANIFEST` field must exactly match `git diff --name-only origin/main...HEAD`:

```
===TOS_TRINITY_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=1
MANIFEST=calculator.zsh test_calculator.zsh
===TOS_TRINITY_END===
```

Write to the inbox and run:

```zsh
tos myproject write trinity
```

The Gateway audits the MANIFEST against the actual diff. If they match, it posts a `[VERIFIED]` closing comment to the issue, closes the PR, closes the issue as "completed", deletes the remote branch, checks out main, releases the hard lock, and transitions to Trinity 0. The `.manifest` visa is consumed and deleted.

The Ghost is back in the sanctuary state, ready to begin Trinity 2.

---

## Phase 11 — Sandbox Teardown (close project)

When all work on a project is complete and the sandbox is no longer needed:

```zsh
tos myproject close project
```

The Gateway verifies no active hard lock exists, then runs `rm -rf` on the local sandbox directory. The remote repository on GitHub is untouched.

---

## Phase 12 — The Nuclear Purge (delete project)

If a project needs to be completely eradicated from GitHub:

```
===TOS_META_START===
TARGET_PROJECT=myproject
TARGET_TRINITY=0
TITLE=Delete myproject
BODY=Project complete. Remove remote repository.
CONFIRM=TRUE
===TOS_META_END===
```

Write to the inbox and run:

```zsh
tos myproject delete project
```

**PAT MFA Isolation:** The Ghost's token deliberately lacks `delete_repo` scope. The command will pause and require interactive browser-based OAuth authentication (`gh auth refresh -s delete_repo`). This is an out-of-band MFA step that cannot be completed non-interactively — automated processes cannot destroy repositories.

Once authenticated, the GitHub repository is deleted, the local sandbox is wiped, and the elevated scope is revoked immediately via the gateway's `EXIT` trap — regardless of whether the deletion succeeded or failed.

---

## The Out-of-Band Recovery Doctrine

If any operation fails at a critical boundary — a `git push` rejection during the Atomic Handover, a GitHub API failure during trinity closure — TOS halts immediately. It logs the full error to the outbox and makes no attempt to self-heal, rebase, or resolve the conflict automatically.

Automated self-healing violates the physical isolation barrier. The Architect reads the outbox, resolves the truth manually (e.g., via `close trinity` to abort cleanly, or by resolving the conflict on GitHub's remote interface before re-running `sync trinity`), and reissues the command.

The system's state is always recoverable by explicit Architect action. The Ghost never silently changes state.

---

← [04-protocol.md](04-protocol.md) | Next: [06-security.md](06-security.md) →
