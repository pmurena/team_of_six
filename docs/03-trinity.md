← [02-architecture.md](02-architecture.md) | Next: [04-protocol.md](04-protocol.md) →

---

# 03 — The Contextual Trinity

The Trinity is the central concept of TOS. Everything else in the system — the lock hierarchy, the IPC ribbon, the hallucination checks, the Clean Room Snapshot — exists to enforce, support, or recover from the Trinity mandate. Understanding it deeply is understanding TOS.

---

## The Mandate: 1:1:1

At any given moment, the Ghost operates within exactly one **issue**, one **branch**, and one **feature**. Not approximately one — mechanically, enforced-at-the-lock-level, one. This constraint is called the 1:1:1 mandate, and it is the direct architectural answer to the cognitive collapse problem described in [01-llm-pitfalls.md](01-llm-pitfalls.md).

The reasoning is straightforward. LLM reliability degrades non-linearly as task scope expands. A model asked to implement one function according to one specification, with one test to satisfy, will perform significantly better than the same model asked to refactor a module. The Trinity mandate keeps the Ghost's task surface at its theoretical minimum: one thing at a time, always.

This is not merely good practice enforced by convention. The system will not let the Ghost commit code outside of an active hard-lock context. It will not let the Ghost write to a trinity that does not match its declared payload. The constraint is structural, not advisory.

---

## Trinity Numbers and Branches

Each Trinity is identified by a number. The numbers correspond directly to GitHub issue numbers. Trinity 1 means issue #1, branch `tos-work-1`. Trinity 7 means issue #7, branch `tos-work-7`. This mapping is intentional: the issue is the single source of truth for what the Trinity is about. The branch name makes the relationship between code and issue explicit and permanent in the Git history.

Trinity 0 is a special case: it maps to the `main` branch and represents the baseline — no active work, no open issue, the read-only sanctuary state. An Architect who has just provisioned a sandbox is in Trinity 0. An Architect who has merged their last feature and returned to baseline is in Trinity 0.

---

## The Lock Hierarchy

The lock hierarchy is the mechanical enforcement of the Trinity mandate. It has two levels:

**Soft Lock (Trinity 0)** — acquired automatically when a sandbox is provisioned or when the Architect returns to baseline after a merge. Under a soft lock, the Ghost can create GitHub issues, post comments, and read repository state. It cannot commit code. The soft lock represents a coordination and planning phase — scoping work, reviewing issues, setting up context for the next feature.

**Hard Lock (Trinity N)** — acquired when the Architect transitions to an active feature trinity. Under a hard lock, the Ghost has full write access to the `tos-work-N` branch: it can commit files, update the PR, and post review comments. The hard lock is exclusive per trinity: only one Architect can hold a hard lock on a given trinity at a time. Different Architects can hold hard locks on different trinities simultaneously.

The lock files live in `/mnt/team_of_six/.ipc/locks/` and take the form `<project>_trinity_<N>.lock`. The content of each file is `<SUDO_USER>:<LOCK_TYPE>`, for example `pat:HARD_LOCK`. This format makes it possible to determine at a glance who holds what lock on which project without any tooling beyond `cat`.

---

## Lock Acquisition

Locks are acquired by any command that puts the Architect into a working context. The two commands that acquire locks are:

**`tos <project> sync start`** — provisions the sandbox (clones the repository) and immediately acquires Trinity 0 on the new project. The lock is acquired *after* the clone succeeds. If the clone fails, no lock is created and no sandbox directory exists — the system is left in a clean state.

**`tos <project> sync trinity <N>`** — transitions to a specific trinity. If N is 0, acquires a soft lock. If N is greater than 0, acquires a hard lock. Before acquiring the new lock, this command checks whether the Architect currently holds a hard lock on this project. If they do, and they are transitioning to a different trinity, it first pushes the current branch to remote — ensuring no work is lost — before releasing the old lock and writing the new one.

The lock acquisition logic in `bin/utils/lock/acquire.sh` is atomic in the sense that it clears the Architect's old lock before writing the new one. There is a narrow race condition between checking for an existing hard lock held by another Architect and writing the new one — this is acknowledged and documented but not mechanically closed, as the practical risk on a single-machine multi-user setup is negligible.

---

## The Atomic Handover

The transition between trinities — going from working on issue #3 to working on issue #7, for example — involves a sequence that TOS calls the Atomic Handover. The steps are:

1. Find the Architect's current lock on this project
2. If it is a hard lock on a different trinity, push that branch to remote
3. Release the old lock
4. Acquire the new lock
5. Check out the new branch (or create it if it does not exist)
6. Pull the latest state of main
7. Regenerate the Clean Room Snapshot

The push in step 2 is the critical safety guarantee. The Ghost's work is preserved in the remote repository before the local state changes. If anything goes wrong after step 2, the work is not lost — it is on the remote branch and can be recovered.

---

## The Clean Room Snapshot

Every trinity transition regenerates the context document in the Architect's outbox from scratch. This document — the Clean Room Snapshot — contains:

- The trinity header (project name, trinity number, branch name)
- The full content of the GitHub issue, including all comments
- The pull request description and review comments, if a PR exists
- The complete diff between the current branch and `origin/main`
- The repository's file signature map (either from ctags if available, or a plain `git ls-files`)

The Ghost starts every session by reading this document. It contains everything the Ghost needs to understand the current state of the work: what was asked for, what has been discussed, what has already been implemented, and what files exist in the repository.

The reason this is called a Clean Room Snapshot is that it contains *only* information derived from the source of truth — GitHub and the Git history. Nothing from a previous session's conversation, nothing from the Architect's memory, nothing that could have drifted. The LLM is not asked to remember what it was doing. It is given a complete, current, verified picture of reality and asked to continue from there.

---

## The Write Policy

The gateway enforces a write policy based on the active lock type. The rules are:

- **Soft lock + `write tasks`** → permitted. Creating issues is a planning operation, appropriate in Trinity 0.
- **Soft lock + `write comment`** → permitted. Posting comments is a coordination operation, appropriate in Trinity 0.
- **Soft lock + `write code`** → blocked. The gateway returns an error: "Trinity 0 is a read-only soft-lock. Sync to a feature Trinity to write code."
- **Hard lock + any write** → permitted, subject to the hallucination checks.

The hallucination checks run for all write operations regardless of lock type. The gateway reads the payload from the inbox and extracts any `TARGET_PROJECT` and `TARGET_TRINITY` declarations. If the declared project does not match the active project, the operation is rejected. If the declared trinity does not match an existing lock, the operation is rejected. These checks are the last line of defence against a confused LLM writing to the wrong place.

---

## Releasing Locks

Locks are released explicitly by `tos <project> sync remove <N>`, which finalises a trinity (closes the issue and PR, deletes the local branch) and returns to Trinity 0. The release happens in two steps: first an explicit call to `release.sh` clears the hard lock, then `sync trinity 0` acquires the soft lock. This two-step approach means that if the trinity-0 acquisition fails (a network error fetching the Clean Room Snapshot from GitHub, for example), the hard lock has already been released. The system may be left without a lock momentarily, but it will not be left with a stale hard lock blocking another Architect.

---

← [02-architecture.md](02-architecture.md) | Next: [04-protocol.md](04-protocol.md) →
