#!/bin/zsh
# ==============================================================================
# Title: Validated Trinity Finalizer
# Usage: tos <project> write trinity
#
# The most defensive script in the system. Merges and closes a trinity only
# after passing a gauntlet of hallucination and lock integrity checks:
#
#   1. Inbox must not be empty
#   2. TRINITY block must be present and parseable
#   3. TARGET_PROJECT must match the active project
#   4. TARGET_TRINITY must match the active hard lock
#   5. Lock state must be clean — one HARD_LOCK owned by this Architect, nothing else
#   6. Manifest must match the actual sandbox diff exactly
#
# Any failure aborts with a clear diagnostic. Nothing is merged until all
# six checks pass.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

# === CHECK 1: INBOX MUST NOT BE EMPTY ===
if [[ ! -s "$TOS_INPUT" ]]; then
    echo "🚨 [ERROR] write trinity: Inbox is empty." >&2
    echo "    The Agent must declare a TRINITY block before this command is called." >&2
    echo "    Expected payload:" >&2
    echo "      ===TOS_TRINITY_START===" >&2
    echo "      TARGET_PROJECT=<project>" >&2
    echo "      TARGET_TRINITY=<id>" >&2
    echo "      MANIFEST=<space-separated list of changed files>" >&2
    echo "      ===TOS_TRINITY_END===" >&2
    exit 1
fi

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

# === CHECK 2: PARSE THE TRINITY BLOCK ===
PARSE_DIR="$TOS_PARSE_DIR/trinity"
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "TRINITY" "$PARSE_DIR" "TARGET_PROJECT" "TARGET_TRINITY" "MANIFEST"

PAYLOAD_PROJECT=$(cat "$PARSE_DIR/1/TARGET_PROJECT.txt" 2>/dev/null)
PAYLOAD_TRINITY=$(cat "$PARSE_DIR/1/TARGET_TRINITY.txt" 2>/dev/null)
PAYLOAD_MANIFEST=$(cat "$PARSE_DIR/1/MANIFEST.txt" 2>/dev/null)

if [[ -z "$PAYLOAD_PROJECT" || -z "$PAYLOAD_TRINITY" || -z "$PAYLOAD_MANIFEST" ]]; then
    echo "🚨 [ERROR] write trinity: Malformed TRINITY block — missing TARGET_PROJECT, TARGET_TRINITY, or MANIFEST." >&2
    exit 1
fi

# === CHECK 3: TARGET_PROJECT MUST MATCH ===
if [[ "$PAYLOAD_PROJECT" != "$TOS_ACTIVE_PROJECT" ]]; then
    echo "🚨 [HALLUCINATION] TARGET_PROJECT mismatch." >&2
    echo "    Payload declares: '$PAYLOAD_PROJECT'" >&2
    echo "    Active project:   '$TOS_ACTIVE_PROJECT'" >&2
    exit 1
fi

# === CHECK 4: TARGET_TRINITY MUST MATCH THE ACTIVE HARD LOCK ===
if [[ "$PAYLOAD_TRINITY" != "$TOS_ACTIVE_TRINITY" ]]; then
    echo "🚨 [HALLUCINATION] TARGET_TRINITY mismatch." >&2
    echo "    Payload declares: '$PAYLOAD_TRINITY'" >&2
    echo "    Active trinity:   '$TOS_ACTIVE_TRINITY'" >&2
    exit 1
fi

# === CHECK 5: LOCK STATE MUST BE CLEAN ===
# Exactly one lock must exist for this project: a HARD_LOCK owned by this Architect.
# Any other lock pattern indicates a dirty or inconsistent state.
GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"
ALL_LOCKS=("$GLOBAL_LOCKS/${TOS_ACTIVE_PROJECT}_trinity_"*.lock(N))
LOCK_COUNT=${#ALL_LOCKS[@]}

if [[ "$LOCK_COUNT" -eq 0 ]]; then
    echo "🚨 [ERROR] Lock state is dirty: no lock found for '$TOS_ACTIVE_PROJECT'." >&2
    echo "    Run: tos $TOS_ACTIVE_PROJECT sync trinity $TOS_ACTIVE_TRINITY" >&2
    exit 1
fi

if [[ "$LOCK_COUNT" -gt 1 ]]; then
    echo "🚨 [ERROR] Lock state is dirty: multiple locks found for '$TOS_ACTIVE_PROJECT'." >&2
    for f in "${ALL_LOCKS[@]}"; do echo "    $(basename $f): $(cat $f)"; done >&2
    exit 1
fi

LOCK_CONTENT=$(cat "${ALL_LOCKS[1]}")
LOCK_OWNER=$(echo "$LOCK_CONTENT" | cut -d: -f1)
LOCK_TYPE=$(echo "$LOCK_CONTENT" | cut -d: -f2)

if [[ "$LOCK_OWNER" != "$SUDO_USER" ]]; then
    echo "🚨 [ERROR] Lock is owned by '$LOCK_OWNER', not '$SUDO_USER'." >&2
    exit 1
fi

if [[ "$LOCK_TYPE" != "HARD_LOCK" ]]; then
    echo "🚨 [ERROR] Lock is a $LOCK_TYPE — a HARD_LOCK is required to finalize." >&2
    exit 1
fi

# === CHECK 6: MANIFEST MUST MATCH ACTUAL SANDBOX DIFF ===
echo "🔍 Auditing Context Integrity..."
AGENT_MANIFEST=$(echo "$PAYLOAD_MANIFEST" | tr ' ' '\n' | sed '/^$/d' | sort)
ACTUAL_DIFF=$(git diff --name-only origin/main...HEAD | sort)

if [[ "$AGENT_MANIFEST" != "$ACTUAL_DIFF" ]]; then
    echo "🚨 [CONTEXT HALLUCINATION] Manifest mismatch." >&2
    echo "    --- Agent Declared Manifest ---" >&2
    echo "$AGENT_MANIFEST" >&2
    echo "    --- Actual Sandbox Diff ---" >&2
    echo "$ACTUAL_DIFF" >&2
    exit 1
fi

echo "✅ All checks passed. Finalizing Trinity #$TOS_ACTIVE_TRINITY..."

# === FINALIZE ===
truncate -s 0 "$TOS_INPUT"
REV_HASH=$(git rev-parse --short HEAD)
ISSUE_URL=$(gh issue view "$TOS_ACTIVE_TRINITY" --json url -q .url 2>/dev/null || echo "Unknown URL")
COMMENT="[VERIFIED] Trinity #$TOS_ACTIVE_TRINITY finalized at rev $REV_HASH. Audit Manifest match: OK.\nContext: $ISSUE_URL"

gh issue comment "$TOS_ACTIVE_TRINITY" -b "$COMMENT" 2>/dev/null || true

# Attempt to merge the PR. Do NOT swallow errors here.
if gh pr merge "tos-work-$TOS_ACTIVE_TRINITY" --merge --delete-branch; then
    # ONLY close the issue if the PR merge was successful
    gh issue close "$TOS_ACTIVE_TRINITY" -r "completed" 2>/dev/null || true
else
    echo "🚨 [ERROR] write trinity: PR merge failed (GitHub API may be calculating mergeability)." >&2
    echo "    Issue #$TOS_ACTIVE_TRINITY remains OPEN." >&2
    echo "    Wait a few seconds and run 'tos write trinity' again." >&2
    exit 1
fi

git fetch origin -q
git checkout main -q
git pull origin main -q
git branch -D "tos-work-$TOS_ACTIVE_TRINITY" -q 2>/dev/null || true

"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT"
"$TOS_BIN/modules/sync/soft/trinity.zsh" "$TOS_ACTIVE_PROJECT" "0"
echo "🏁 Trinity #$TOS_ACTIVE_TRINITY Finalized."
