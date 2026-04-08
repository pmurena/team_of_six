#!/bin/zsh
# ==============================================================================
# Title: The Code Publisher
# Usage: tos <project> write code
#
# Hallucination control and lock verification are enforced by the gateway
# (bin/tos) before this module is ever reached. This module is a dumb executor:
#
# Stage 1 — Metadata: extracts the single META block (TITLE + BODY).
# Stage 2 — Files: extracts all FILE blocks and overwrites sandbox targets.
# Stage 3 — Publish: commits and pushes; creates/updates the PR.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
umask 077

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]] || {
    echo "🚨 ERROR: Not on a tos-work-# branch."
    exit 1
}
# TOS_ACTIVE_TRINITY is exported by the gateway — use it directly
ACTIVE_TRINITY="${TOS_ACTIVE_TRINITY:-${match[1]}}"

META_DIR="$TOS_PARSE_DIR/meta"
FILE_DIR="$TOS_PARSE_DIR/files"

echo "⚡ STAGE 1: PARSING METADATA"
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "META" "$META_DIR" "TARGET_PROJECT" "TARGET_TRINITY" "TITLE" "BODY"

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

echo "⚡ STAGE 2: PARSING FILES"
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "FILE" "$FILE_DIR"

# Inbox fully parsed — consume before side effects
truncate -s 0 "$TOS_INPUT"

FILE_ITEMS=("$FILE_DIR"/*(/N))
if [[ ${#FILE_ITEMS[@]} -gt 0 ]]; then
    echo "⚡ WRITING ${#FILE_ITEMS[@]} FILES"
    for item_dir in "${FILE_ITEMS[@]}"; do
        FILE_PATH=$(cat "$item_dir/_TARGET.txt" 2>/dev/null)

        # [SECURITY] Path Traversal Protection
        if [[ -z "$FILE_PATH" || "$FILE_PATH" == *..* || "$FILE_PATH" == /* ]]; then
            echo "🚨 SEC-FAULT: Illegal or missing file path detected."
            exit 1
        fi

        echo "📝 Overwriting: $FILE_PATH"
        mkdir -p "$(dirname "$FILE_PATH")"
        cat "$item_dir/RAW_BODY.txt" > "$FILE_PATH"
    done
else
    echo "⚠️  Warning: No file blocks detected. Proceeding with metadata only."
fi

echo "🚀 STAGE 3: PUBLISHING CODE"

export GIT_AUTHOR_NAME="Team of Six (Ghost)"
export GIT_AUTHOR_EMAIL="ghost@teamofsix.local"

PR_TITLE="[Ghost] Trinity #${ACTIVE_TRINITY}: $TITLE"

git add .
git commit -m "$TITLE\n\n$BODY\n\nFixes #$ACTIVE_TRINITY"

if git push origin "$CURRENT_BRANCH" --force-with-lease; then
    if gh pr view "$CURRENT_BRANCH" &>/dev/null; then
        gh pr edit "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$BODY"
    else
        gh pr create --title "$PR_TITLE" --body "$BODY" --head "$CURRENT_BRANCH"
    fi
fi

echo "🏁 CODE WRITE COMPLETE"

# === JOURNAL: Record committed files into the outbox ===
echo ""
echo "## GHOST COMMITTED: Trinity #${ACTIVE_TRINITY} — $TITLE"
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

# --- Context Note ---
# The Outbox is ephemeral. The Architect must explicitely 'sync peek' or 'sync trinity' to refresh context after writing.
