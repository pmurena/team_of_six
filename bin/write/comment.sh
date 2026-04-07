#!/bin/zsh
# ==============================================================================
# Title: The Batch Comment Publisher
# Usage: tos <project> write comment
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
umask 077

echo "⚡ PARSING BATCH COMMENTS"

"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "COMMENT" "$TOS_PARSE_DIR" "TARGET" "BODY"

ITEM_DIRS=("$TOS_PARSE_DIR"/*(/N))
if [[ ${#ITEM_DIRS[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_COMMENT_START=== blocks found."
    exit 1
fi

# Consume inbox before posting to GitHub
truncate -s 0 "$TOS_INPUT"

echo "💬 POSTING ${#ITEM_DIRS[@]} COMMENTS"

for item_dir in "${ITEM_DIRS[@]}"; do
    TARGET=$(cat "$item_dir/TARGET.txt" 2>/dev/null)
    BODY_FILE="$item_dir/BODY.txt"

    if [[ -n "$TARGET" && -f "$BODY_FILE" ]]; then
        echo "✨ Posting comment to #$TARGET"

        if gh pr view "$TARGET" &>/dev/null; then
            if gh pr comment "$TARGET" --body-file "$BODY_FILE"; then
                echo -e "\n## GHOST COMMENT POSTED TO PR #$TARGET:\n"
                cat "$BODY_FILE" 
            else
                echo "❌ ERROR: Failed to post comment to PR #$TARGET."
            fi
        else
            if gh issue comment "$TARGET" --body-file "$BODY_FILE"; then
                echo -e "\n## GHOST COMMENT POSTED TO ISSUE #$TARGET:\n" 
                cat "$BODY_FILE" 
            else
                echo "❌ ERROR: Failed to post comment to Issue #$TARGET."
            fi
        fi
    else
        echo "⚠️  Warning: Skipping malformed comment block."
    fi
done

echo "🏁 BATCH COMMENT POSTING COMPLETE"
