#!/bin/zsh
# ==============================================================================
# Title: The Batch Issue Creator
# Usage: tos <project> create issue
# Parses ISSUE blocks from the inbox and creates GitHub Issues for each one.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
umask 077

echo "⚡ PARSING BATCH ISSUES"

"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "ISSUE" "$TOS_PARSE_DIR" "TITLE" "BODY"

ITEM_DIRS=("$TOS_PARSE_DIR"/*(/N))
if [[ ${#ITEM_DIRS[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_ISSUE_START=== blocks found."
    exit 1
fi

# Consume inbox before creating GitHub Issues
truncate -s 0 "$TOS_INPUT"

echo "🚀 CREATING ${#ITEM_DIRS[@]} GITHUB ISSUES"

for item_dir in "${ITEM_DIRS[@]}"; do
    TITLE=$(cat "$item_dir/TITLE.txt" 2>/dev/null)
    BODY=$(cat "$item_dir/BODY.txt" 2>/dev/null)

    if [[ -n "$TITLE" ]]; then
        echo "✨ Creating: $TITLE"
        gh issue create --title "$TITLE" --body "$BODY"
    else
        echo "⚠️  Warning: Skipping malformed issue block (Missing TITLE)."
    fi
done

echo "🏁 BATCH ISSUE CREATION COMPLETE"
