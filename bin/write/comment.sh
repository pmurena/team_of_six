#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && { echo "⚠️ Inbox empty."; exit 1; }

cd "$TOS_WORKING_DIR" || exit 1

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]]; then
    ISSUE_ID="${match[1]}"
else
    echo "🚨 ERROR: Not on a valid Ghost workspace branch (tos-work-#)."
    exit 1
fi

echo "💬 STAGE 1: POSTING COMMENT TO ISSUE #$ISSUE_ID"

if gh issue comment "$ISSUE_ID" --body-file "$TOS_INPUT"; then
    echo "✅ Comment posted."
    echo -e "\n## GHOST COMMENT POSTED:\n" >> "$TOS_CONTEXT"
    cat "$TOS_INPUT" >> "$TOS_CONTEXT"
    truncate -s 0 "$TOS_INPUT"
else
    echo "❌ ERROR: Failed to post comment."
    exit 1
fi
