← [03-trinity.md](03-trinity.md) | Next: [05-workflow.md](05-workflow.md) →

---

# 04 — The Plaintext Protocol

The IPC protocol is the language the LLM speaks to TOS. It defines the format of payloads the Ghost accepts, how the Ghost parses them, and what each block type causes to happen. This document is a complete reference for the protocol.

---

## Design Philosophy

The protocol is deliberately minimal. Every block is delimited by uppercase marker lines. Fields are `KEY=VALUE` pairs. File content is raw text between markers. There are no nested structures, no JSON, no YAML, no XML.

This minimalism is a feature, not a limitation. The LLM must produce these payloads in its output, and the simpler the format, the more reliably it produces well-formed output. A format that requires balanced brackets, escaped quotes, or hierarchical nesting creates more surface area for malformation.

Parsing is done with `awk` in `bin/utils/parse_blocks.zsh`. The parser operates in two modes:

- **Key-Value Mode** — extracts named `KEY=VALUE` fields into individual text files, one file per field, within a numbered subdirectory per block.
- **Raw-Body Mode** — for `FILE` blocks, writes the path to `_TARGET.txt` and the full block content verbatim to `RAW_BODY.txt`.

Multiple blocks of the same type in a single payload are processed in order, each producing its own numbered subdirectory.

> **Known limitation:** The parser accepts any content between markers without schema validation. A malformed block with a missing required field may parse successfully and produce silent empty-field behaviour. LSP-driven schema validation is on the roadmap.

---

## The Meta Block

The Meta block declares the Ghost's working context. It is required for `write code`, `write comment`, and all `close` and `delete` operations.

```
===TOS_META_START===
TARGET_PROJECT=my-repo
TARGET_TRINITY=3
TITLE=Implement the add() function
BODY=Adds two integers using native Zsh arithmetic. Fixes #3.
===TOS_META_END===
```

**`TARGET_PROJECT`** must match the project name passed to the `tos` command. A mismatch causes a hallucination rejection before any execution.

**`TARGET_TRINITY`** must match an existing lock owned by this Architect. A mismatch — referencing a trinity that has already been closed or was never activated — causes a hallucination rejection.

**`TITLE`** becomes the commit message title (for `write code`) or the PR comment prefix (for `write comment`).

**`BODY`** provides additional context for the commit or comment.

---

## The CONFIRM Gate

For any `close` or `delete` operation, the Meta block must additionally contain the exact field:

```
CONFIRM=TRUE
```

The gateway checks for this string before evaluating any further logic. Its absence causes an immediate abort with a loud security warning. This is the **HITL Destructive Gate** — a mechanical enforcement of human intent for all finality and purge operations.

A complete destructive Meta block looks like:

```
===TOS_META_START===
TARGET_PROJECT=my-repo
TARGET_TRINITY=3
TITLE=Close Trinity 3
BODY=All tests pass. Squash and merge.
CONFIRM=TRUE
===TOS_META_END===
```

---

## The Plan Block (The Intent Lock)

Before the Agent is permitted to write code, it must declare the exact set of files it intends to create or modify. This is done with a Plan block:

```
===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh
===TOS_PLAN_END===
```

When the Architect executes `tos <project> write plan`, the gateway extracts this block and writes the approved file list to a `.manifest` visa in the control plane at `.ipc/locks/<project>_trinity_<N>.manifest`. This directory is mode `0700`, Ghost-exclusive — the Architect cannot edit the visa from their own account after it is written. The only way to change it is to issue a new `write plan`.

From this moment on, the **Intent Lock** is active. Every subsequent `write code` payload for this Trinity is mechanically checked against this visa.

A payload touching *fewer* files than the manifest authorises will pass. A payload touching any file *not in the manifest* causes a `SEC-FAULT` rejection before the gateway writes a single byte to the sandbox.

The `.manifest` is consumed and deleted when the Trinity is finalised via `write trinity` or `close trinity`.

---

## The File Block

The File block declares a file to create or overwrite in the Ghost's sandbox.

```
===TOS_FILE_START: path/to/file.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
```

The file path in the start marker is relative to the project root in the sandbox. The content between the markers is written verbatim to that path, creating parent directories as needed. If the file already exists, it is overwritten.

Multiple File blocks in a single payload are processed in order. All files are written before the commit is made, so the commit captures the complete change atomically.

**Security:** Two validations apply to every file path. First, paths containing `..` or starting with `/` are rejected immediately as path traversal attempts. Second, the path is checked against the active `.manifest` visa — a file not listed in the visa causes a `SEC-FAULT` rejection of the entire payload.

The file content is written exactly as it appears between the markers. TOS does not add shebangs, fix indentation, or otherwise modify the content. The payload is an explicit declaration of intent.

---

## The Issue Block

The Issue block declares a GitHub issue to create. It is used with `write issue` and does not require a Meta block — issue creation is a soft-lock planning operation.

```
===TOS_ISSUE_START===
TITLE=Implement the subtract() function
BODY=Deferred from the current trinity. Should use native Zsh arithmetic.
===TOS_ISSUE_END===
```

Multiple Issue blocks in a single payload create multiple issues in order. The inbox is truncated before the first issue is created. If `gh issue create` fails partway through a batch, already-created issues remain on GitHub and the inbox is empty — the Architect must resubmit the remaining blocks manually.

---

## The Comment Block

The Comment block declares a comment to post to a GitHub issue or pull request.

```
===TOS_COMMENT_START===
TARGET=3
BODY=**[ANSWER]**: Yes, negative numbers are supported by native Zsh arithmetic.
===TOS_COMMENT_END===
```

**`TARGET`** can be an issue number or a branch name. The gateway attempts `gh pr view` first — if a PR exists for that target, the comment goes to the PR. Otherwise it goes to the issue. Multiple Comment blocks in a single payload post in order.

---

## The Trinity Block (Closure MANIFEST)

The Trinity block is used exclusively with `write trinity` to trigger the MANIFEST-verified closure sequence.

```
===TOS_TRINITY_START===
TARGET_PROJECT=my-repo
TARGET_TRINITY=3
MANIFEST=calculator.zsh test_calculator.zsh
===TOS_TRINITY_END===
```

**`MANIFEST`** must list every file that differs between the current branch and `origin/main`, matching exactly the output of `git diff --name-only origin/main...HEAD`. The gateway sorts both lists before comparing. Any mismatch — a file the Agent forgot to declare, or a file it claims to have changed but did not — causes a `CONTEXT HALLUCINATION DETECTED` rejection.

This is a retrospective integrity check: the Agent must prove it knows precisely what it has done before the system will finalise the Trinity. It is distinct from the Intent Lock (which is prospective — authorising what the Agent *will* do).

---

## The Inbox and Outbox

The **inbox** (`$TOS_IPC/inbox.md`) is where the Architect writes payloads for the Ghost to execute. In normal usage, the LLM produces a payload in the chat output, and the Architect either delivers it manually or uses the Neovim plugin's smart-yanking keymaps.

**The Inbox Truncation Invariant:** The inbox is truncated to zero bytes immediately after the payload is parsed, before any Git or filesystem side effects occur. This is not an oversight — it is a deliberate guarantee of exact-once execution. If a `git push` fails after truncation, the payload is gone. The Architect must resubmit. This eliminates all risk of double-commits or duplicate API calls on retry.

The **outbox** (`$TOS_IPC/outbox.md`) is where the Ghost writes output. The gateway pipes all command output through `tee` to the outbox, so the complete output of every TOS command is always available there. The Clean Room Snapshot — regenerated on every `sync trinity` — replaces whatever was there before. The outbox always contains either the most recent command output or the most recent context snapshot, whichever is newer.

> **Note:** `write` commands append raw engine output to the outbox for visibility but do not regenerate the context snapshot. Always run `sync trinity <N>` to get a clean snapshot before starting a new Agent session.

---

## A Complete Payload Sequence (Red/Green Phase)

**Step 1 — Declare intent (`write plan`):**

```
===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh
===TOS_PLAN_END===
```

**Step 2 — Write the Red test (`write code`):**

```
===TOS_META_START===
TARGET_PROJECT=tos-tutorial
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

**Step 3 — Write the Green implementation (`write code`):**

```
===TOS_META_START===
TARGET_PROJECT=tos-tutorial
TARGET_TRINITY=1
TITLE=Green: implement add()
BODY=Implements add() to satisfy the failing test. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./calculator.zsh
[[ "$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
```

**Step 4 — Close the Trinity (`write trinity`):**

```
===TOS_TRINITY_START===
TARGET_PROJECT=tos-tutorial
TARGET_TRINITY=1
MANIFEST=calculator.zsh test_calculator.zsh
===TOS_TRINITY_END===
```

When the Architect runs `tos tos-tutorial write code` with the Green payload, the gateway will:

1. Validate `TARGET_PROJECT` and `TARGET_TRINITY` against the active lock.
2. Check the `.manifest` — both `calculator.zsh` and `test_calculator.zsh` must be listed.
3. Truncate the inbox to zero bytes.
4. Write both files to the sandbox.
5. Run `git add . && git commit` and `git push --force-with-lease`.
6. Create or update the PR on GitHub.
7. Write the Ghost Journal to the outbox.

---

← [03-trinity.md](03-trinity.md) | Next: [05-workflow.md](05-workflow.md) →
