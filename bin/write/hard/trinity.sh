#!/bin/zsh
# ==============================================================================
# Title: Validated Trinity Finalizer
# Usage: tos <project> write trinity
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

PARSE_DIR="$TOS_PARSE_DIR/trinity"
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "TRINITY" "$PARSE_DIR" "TARGET_PROJECT" "TARGET_TRINITY" "MANIFEST"

PAYLOAD_TRINITY=$(cat "$PARSE_DIR/1/TARGET_TRINITY.txt" 2>/dev/null)
[[ "$PAYLOAD_TRINITY" != "$TOS_ACTIVE_TRINITY" ]] && { echo "🚨 Hallucination: Trinity ID mismatch."; exit 1; }

echo "🔍 Auditing Context Integrity..."
AGENT_MANIFEST=$(cat "$PARSE_DIR/1/MANIFEST.txt" 2>/dev/null | tr ' ' '\n' | sed '/^$/d' | sort)
ACTUAL_DIFF=$(git diff --name-only origin/main...HEAD | sort)

if [[ "$AGENT_MANIFEST" != "$ACTUAL_DIFF" ]]; then
    echo "🚨 CONTEXT HALLUCINATION DETECTED"
    echo "--- Agent Declared Manifest ---"
    echo "$AGENT_MANIFEST"
    echo "--- Actual Sandbox Diff ---"
    echo "$ACTUAL_DIFF"
    exit 1
fi

truncate -s 0 "$TOS_INPUT"
REV_HASH=$(git rev-parse --short HEAD)
ISSUE_URL=$(gh issue view "$TOS_ACTIVE_TRINITY" --json url -q .url 2>/dev/null || echo "Unknown URL")
COMMENT="[VERIFIED] Trinity #$TOS_ACTIVE_TRINITY finalized at rev $REV_HASH. Audit Manifest match: OK.\nContext: $ISSUE_URL"

gh issue comment "$TOS_ACTIVE_TRINITY" -b "$COMMENT" 2>/dev/null || true
gh pr close "tos-work-$TOS_ACTIVE_TRINITY" -c "$COMMENT" 2>/dev/null || true
gh issue close "$TOS_ACTIVE_TRINITY" -r "completed" 2>/dev/null || true

git push origin --delete "tos-work-$TOS_ACTIVE_TRINITY" 2>/dev/null || true
git checkout main -q && git branch -D "tos-work-$TOS_ACTIVE_TRINITY" -q 2>/dev/null || true

"$TOS_BIN/utils/lock/release.sh" "$TOS_ACTIVE_PROJECT"
"$TOS_BIN/sync/soft/trinity.sh" "$TOS_ACTIVE_PROJECT" "0"
echo "🏁 Trinity Turn Finalized."
