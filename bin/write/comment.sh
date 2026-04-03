#!/bin/zsh
# ==============================================================================
# Title: The Batch Comment Publisher
#
# Usage Explanation: Triggered by `tos <project> write comment`. It calls the 
# Universal Reader to extract `COMMENT` blocks into `$TOS_PARSE_DIR`, looking 
# for `TARGET` (the Issue/PR ID) and `BODY`. It iterates through the objects, 
# posting each comment to the corresponding GitHub thread using `gh issue comment`, 
# and safely appends the posted text to the local `outbox.md` context.
# ==============================================================================

[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_WORKING_DIR" || exit 1
umask 077

echo "⚡ PARSING BATCH COMMENTS"

"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "COMMENT" "$TOS_PARSE_DIR" "TARGET" "BODY"

ITEM_DIRS=("$TOS_PARSE_DIR"/*(/N))
if [[ ${#ITEM_DIRS[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_COMMENT_START=== blocks found."
    exit 1
fi

# Inbox parsed and validated — consume before posting to GitHub.
truncate -s 0 "$TOS_INPUT"

echo "💬 POSTING ${#ITEM_DIRS[@]} COMMENTS"

for item_dir in "${ITEM_DIRS[@]}"; do
    TARGET=$(cat "$item_dir/TARGET.txt" 2>/dev/null)
    BODY_FILE="$item_dir/BODY.txt"

    if [[ -n "$TARGET" && -f "$BODY_FILE" ]]; then
        echo "✨ Posting comment to #$TARGET"
        if gh issue comment "$TARGET" --body-file "$BODY_FILE"; then
            echo -e "\n## GHOST COMMENT POSTED TO #$TARGET:\n" >> "$TOS_CONTEXT"
            cat "$BODY_FILE" >> "$TOS_CONTEXT"
        else
            echo "❌ ERROR: Failed to post comment to #$TARGET."
        fi
    else
        echo "⚠️ Warning: Skipping malformed comment block."
    fi
done

echo "🏁 BATCH COMMENT POSTING COMPLETE"
