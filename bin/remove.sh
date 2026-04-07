#!/bin/zsh
# ==============================================================================
# Title: Trinity Finalizer
# Usage: tos <project> remove <trinity_id> "<close_comment>"
#
# Closes the GitHub issue and PR for the given trinity, cleans the local
# branch, explicitly releases the hard-lock, then returns to Trinity 0.
#
# <close_comment> is mandatory — it is appended to the closing audit entry
# and recorded in the GitHub issue thread for traceability.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT=$1
shift
TARGET_TRINITY=$1
shift
CLOSE_COMMENT="$*"

if [[ -z "$TARGET_TRINITY" || "$TARGET_TRINITY" == "0" ]]; then
    echo "[ERROR] Cannot remove Trinity 0 (main)."
    exit 1
fi

if [[ -z "$CLOSE_COMMENT" ]]; then
    echo "[ERROR] A closing comment is required."
    echo "Usage: tos <project> remove <trinity_id> \"<close_comment>\""
    exit 1
fi

echo "[INFO] Initiating Traceable Finality for Trinity $TARGET_TRINITY..."
cd "$TOS_SANDBOX/$PROJECT" || exit 1

REV_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMENT="Removed at revision $REV_HASH on branch tos-work-$TARGET_TRINITY. $CLOSE_COMMENT"

# Post to GitHub Knowledge Base
gh issue comment "$TARGET_TRINITY" -b "$COMMENT" 2>/dev/null || true
gh pr close "tos-work-$TARGET_TRINITY" -c "$COMMENT" 2>/dev/null || true
gh issue close "$TARGET_TRINITY" -r "completed" 2>/dev/null || true

# Remote Cleanup
git push origin --delete "tos-work-$TARGET_TRINITY" 2>/dev/null || true

# Local Cleanup
git checkout main -q
git branch -D "tos-work-$TARGET_TRINITY" 2>/dev/null || true

# Explicitly release the hard-lock before transitioning.
# This ensures no stale lock persists if the trinity-0 acquisition below fails.
"$TOS_BIN/utils/lock/release.sh" "$PROJECT"

echo "[INFO] Returning to Trinity 0..."
"$TOS_BIN/sync/trinity.sh" "$PROJECT" "0"
