← [03-trinity.md](03-trinity.md) | Next: [05-workflow.md](05-workflow.md) →

---

# 04 — The Plaintext Protocol

The IPC protocol is the language the LLM speaks to TOS. It defines the format of payloads the Ghost accepts, how the Ghost parses them, and what each block type causes to happen. This document is a complete reference for the protocol.

---

## Design Philosophy

The protocol is deliberately minimal. Every block is delimited by uppercase marker lines. Fields are `KEY=VALUE` pairs. File content is raw text between markers. There are no nested structures, no JSON, no YAML, no XML.

This minimalism is a feature, not a limitation. The LLM must produce these payloads in its output, and the simpler the format, the more reliably it produces well-formed output. A format that requires balanced brackets, escaped quotes, or hierarchical nesting creates more surface area for malformation. A format that requires only that specific lines appear in a specific order is robust to the natural variability in LLM output.

The parsing is done with `awk` in `bin/utils/parse_blocks.sh`. The parser extracts blocks by scanning for start and end markers, collecting field lines and file content as it goes. Blocks are written to a temporary parse directory as individual files — one file per field — which the action scripts then read. This separation of parsing from execution means the parser can be read and understood independently, and malformed input fails at parse time rather than mid-execution.

> **Known limitation and future direction:** The current parser accepts any content between markers without schema validation. A malformed block — one with a missing required field, or a field value that does not match expected constraints — may parse successfully and produce empty or incorrect behaviour with no error surfaced to the Architect. A future improvement, currently on the roadmap, is to introduce language-aware validation using LSP tooling to validate payload content before execution. This would close the gap between a structurally valid block and a semantically valid one.

---

## The Meta Block

The meta block declares the Ghost's working context. It is required for all `write code` and `write comment` operations. It is the mechanism by which the hallucination checks in the gateway work.

```
===TOS_META_START===
TARGET_PROJECT=my-repo
TARGET_TRINITY=3
TITLE=Implement the add() function
BODY=Adds two integers using native Zsh arithmetic. Fixes #3.
===TOS_META_END===
```

**`TARGET_PROJECT`** must match the project name passed to the `tos` command. If they do not match, the gateway rejects the entire payload with a hallucination error. This catches the case where the LLM is writing a payload for a different project than the one currently active — a failure mode that is surprisingly common in long sessions where the project context shifts.

**`TARGET_TRINITY`** must match an existing lock owned by this Architect. If the declared trinity has no corresponding lock file, the gateway rejects the payload. This catches the case where the LLM is referencing a trinity that has already been merged and closed, or one that was never activated.

**`TITLE`** becomes the commit message (for code writes) or the PR comment body prefix (for comments).

**`BODY`** provides additional context for the commit or comment.

---

## The File Block

The file block declares a file to create or overwrite in the Ghost's sandbox. It appears after the meta block and may be repeated for multiple files in a single payload.

```
===TOS_FILE_START: path/to/file.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
```

The file path in the start marker is relative to the project root in the sandbox. The content between the markers is written verbatim to that path, creating any necessary parent directories. If the file already exists, it is overwritten.

Multiple file blocks in a single payload are processed in order. All files are written before the commit is made, so the commit captures the complete set of changes atomically.

**Important:** the file content is written exactly as it appears between the markers, including leading and trailing whitespace. The LLM must produce content that is valid for the target language — TOS does not add shebangs, fix indentation, or otherwise modify the content. This is by design: the payload is an explicit declaration of intent, and modifying it would introduce a gap between what the LLM declared and what was committed.

---

## The Issue Block

The issue block declares a GitHub issue to create. It is used with `tos <project> write tasks` and does not require a meta block — task creation is a planning operation permitted under a soft lock.

```
===TOS_ISSUE_START===
TITLE=Implement the subtract() function
BODY=Deferred from the current trinity. Should use native Zsh arithmetic.
===TOS_ISSUE_END===
```

Multiple issue blocks in a single payload create multiple issues. The issues are created in order. The inbox is cleared before the first issue is created — if the `gh issue create` command fails partway through a batch, any issues already created remain on GitHub and the inbox is empty. The Architect will need to re-write the remaining issues manually or restart the batch.

---

## The Comment Block

The comment block declares a comment to post to a GitHub issue or pull request.

```
===TOS_COMMENT_START===
TARGET=3
BODY=**[ANSWER]**: Yes, negative numbers are supported by native Zsh arithmetic.
===TOS_COMMENT_END===
```

**`TARGET`** can be an issue number (posts to that issue) or a branch name (posts to the PR for that branch). This allows the Ghost to respond to both issue threads and PR review threads from the same payload.

Multiple comment blocks in a single payload post multiple comments. They are posted in order.

---

## The Inbox and Outbox

The **inbox** (`$TOS_IPC/inbox.md`) is where the Architect writes payloads for the Ghost to execute. In normal usage, the LLM produces a payload as part of its chat output, and the Architect either pastes it into the inbox manually or uses the Neovim plugin to deliver it automatically. The inbox is cleared by the Ghost after reading — each `write` command truncates the inbox before executing, so a failed command does not re-execute on the next invocation.

The **outbox** (`$TOS_IPC/outbox.md`) is where the Ghost writes output. The gateway pipes all command output through `tee` to the outbox, so the complete output of every TOS command is always available there. Additionally, the Clean Room Snapshot — the context document regenerated on every trinity transition — is written to the outbox and replaces whatever was there before. This means the outbox always contains either the most recent command output or the most recent context snapshot, whichever is newer.

The Architect reads the outbox to see what the Ghost did, to review the current context snapshot, and to provide that context to the LLM in the next session. The Neovim plugin automates this — it reads the outbox and injects its content into the LLM context window before each prompt.

---

## A Complete Payload Example

The following is a complete payload for a code write operation — the meta block followed by two file blocks.

```
===TOS_META_START===
TARGET_PROJECT=tos-tutorial
TARGET_TRINITY=1
TITLE=Green: implement add() and its test
BODY=Implements the add() function and satisfies the failing test. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
# Adds two integers using native Zsh arithmetic.
# Supports negative numbers.
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh
log "Running tests..."
[[ "$(add 5 5)" == "10" ]] || { log "FAIL: add 5 5"; exit 1; }
[[ "$(add -3 7)" == "4" ]] || { log "FAIL: add -3 7"; exit 1; }
log "All tests passed."
===TOS_FILE_END===
```

When the Architect runs `tos tos-tutorial write code` with this payload in the inbox, the gateway will:

1. Verify the soft/hard lock policy (must be in Trinity 1, not Trinity 0)
2. Confirm `TARGET_PROJECT` matches `tos-tutorial`
3. Confirm a lock for Trinity 1 exists and is owned by this Architect
4. Write `calculator.zsh` and `test_calculator.zsh` to the sandbox
5. Commit both files with the message from `TITLE` and `BODY`
6. Push to `origin/tos-work-1`
7. Write the full output to the outbox

---

← [03-trinity.md](03-trinity.md) | Next: [05-workflow.md](05-workflow.md) →
