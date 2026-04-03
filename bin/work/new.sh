#!/bin/zsh
# ==============================================================================
# Title: The Batch Issue Creator
#
# Usage Explanation: Triggered by `tos <project> work new`. It calls the 
# Universal Reader to extract `ISSUE` blocks into `$TOS_PARSE_DIR` looking for 
# `TITLE` and `BODY`. It then iterates through the resulting object directories 
# and executes the GitHub CLI command (`gh issue create`) for each one.
# ==============================================================================

[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_WORKING_DIR" || exit 1
umask 077

echo "⚡ PARSING BATCH ISSUES"

"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "ISSUE" "$TOS_PARSE_DIR" "TITLE" "BODY"

ITEM_DIRS=("$TOS_PARSE_DIR"/*(/N))
if [[ ${#ITEM_DIRS[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_ISSUE_START=== blocks found."
    exit 1
fi

# Inbox parsed and validated — consume before creating GitHub issues.
truncate -s 0 "$TOS_INPUT"

echo "🚀 CREATING ${#ITEM_DIRS[@]} GITHUB ISSUES"

for item_dir in "${ITEM_DIRS[@]}"; do
    TITLE=$(cat "$item_dir/TITLE.txt" 2>/dev/null)
    BODY=$(cat "$item_dir/BODY.txt" 2>/dev/null)

    if [[ -n "$TITLE" ]]; then
        echo "✨ Creating: $TITLE"
        gh issue create --title "$TITLE" --body "$BODY"
    else
        echo "⚠️ Warning: Skipping malformed issue block (Missing TITLE)."
    fi
done

echo "🏁 BATCH ISSUE CREATION COMPLETE"
