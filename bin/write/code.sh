#!/bin/zsh
# ==============================================================================
# Title: The Code Publisher
#
# Usage Explanation: Triggered by `tos <project> write code`. It acts in a 
# two-stage process:
# 1. Metadata: It calls the Universal Reader to extract exactly one `META` block 
#    (for the commit `TITLE` and `BODY`). It halts execution if multiple meta 
#    blocks are found, enforcing a strict "one PR update per turn" rule.
# 2. Files: It calls the Universal Reader a second time in "Raw File Mode" to 
#    parse all `FILE` blocks. It reads the target paths, safeguards against 
#    directory traversal attacks, overwrites the files in the secure sandbox, 
#    and finally commits and pushes the changes to GitHub.
# ==============================================================================

[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_WORKING_DIR" || exit 1
umask 077

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]] || { echo "🚨 ERROR: Not on a tos-work-# branch."; exit 1; }
ISSUE_ID="${match[1]}"

echo "⚡ STAGE 1: PARSING PAYLOAD"

META_DIR="$TOS_PARSE_DIR/meta"
FILE_DIR="$TOS_PARSE_DIR/files"

# 1. Parse Metadata (Requires TITLE and BODY)
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "META" "$META_DIR" "TITLE" "BODY"

META_ITEMS=("$META_DIR"/*(/N))
if [[ ${#META_ITEMS[@]} -eq 0 ]]; then
    echo "🚨 ERROR: Missing ===TOS_META_START=== block."
    exit 1
elif [[ ${#META_ITEMS[@]} -gt 1 ]]; then
    echo "🚨 ERROR: Multiple META blocks detected. Only one PR update allowed per turn."
    exit 1
fi

TITLE=$(cat "${META_ITEMS[1]}/TITLE.txt" 2>/dev/null)
BODY=$(cat "${META_ITEMS[1]}/BODY.txt" 2>/dev/null)
[[ -z "$TITLE" ]] && { echo "🚨 ERROR: Missing TITLE in metadata."; exit 1; }

# 2. Parse Files (Raw Body Mode - No keys expected)
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "FILE" "$FILE_DIR"

# Inbox is fully parsed and validated — consume it now, before any side effects.
# A failure during git/gh operations will not leave a stale payload in the inbox.
truncate -s 0 "$TOS_INPUT"

FILE_ITEMS=("$FILE_DIR"/*(/N))
if [[ ${#FILE_ITEMS[@]} -gt 0 ]]; then
    echo "⚡ STAGE 2: WRITING ${#FILE_ITEMS[@]} FILES"
    for item_dir in "${FILE_ITEMS[@]}"; do
        FILE_PATH=$(cat "$item_dir/_TARGET.txt" 2>/dev/null)
        
        # [SECURITY] Path Traversal Protection - Fixed for native Zsh
        if [[ -z "$FILE_PATH" || "$FILE_PATH" == *..* || "$FILE_PATH" == /* ]]; then
            echo "🚨 SEC-FAULT: Illegal or missing file path detected."
            exit 1
        fi
        
        echo "📝 Overwriting: $FILE_PATH"
        mkdir -p "$(dirname "$FILE_PATH")"
        cat "$item_dir/RAW_BODY.txt" > "$FILE_PATH"
    done
else
    echo "⚠️ Warning: No file blocks detected. Proceeding with metadata only."
fi

echo "🚀 STAGE 3: PUBLISHING CODE"

export GIT_AUTHOR_NAME="Team of Six (Ghost)"
export GIT_AUTHOR_EMAIL="ghost@teamofsix.local"

PR_TITLE="[Ghost] Issue #$ISSUE_ID: $TITLE"

git add .
git commit -m "$TITLE\n\n$BODY\n\nFixes #$ISSUE_ID"

set -x
if git push origin "$CURRENT_BRANCH" --force-with-lease; then
    # The GH_TOKEN is safely provided by the master bin/tos gateway
    if gh pr view "$CURRENT_BRANCH" &>/dev/null; then
        gh pr edit "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$BODY"
    else
        gh pr create --title "$PR_TITLE" --body "$BODY" --head "$CURRENT_BRANCH"
    fi
fi
set +x

echo "🏁 CODE WRITE COMPLETE"

# === JOURNAL: Record committed files into the outbox context ===
# This allows the Ghost to see what it just wrote on its next turn,
# rather than working from a stale pre-commit context.
{
    echo ""
    echo "## GHOST COMMITTED: Issue #$ISSUE_ID — $TITLE"
    echo "Branch: $CURRENT_BRANCH"
    echo ""
    if [[ ${#FILE_ITEMS[@]} -gt 0 ]]; then
        for item_dir in "${FILE_ITEMS[@]}"; do
            WRITTEN_PATH=$(cat "$item_dir/_TARGET.txt" 2>/dev/null)
            echo "### \`$WRITTEN_PATH\`"
            echo '```'
            cat "$item_dir/RAW_BODY.txt"
            echo '```'
            echo ""
        done
    fi
} >> "$TOS_CONTEXT"
