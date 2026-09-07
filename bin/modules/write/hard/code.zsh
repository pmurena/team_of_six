#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
umask 077

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]] || {
    echo "🚨 ERROR: Not on a tos-work-# branch."
    exit 1
}
ACTIVE_TRINITY="${TOS_ACTIVE_TRINITY:-${match[1]}}"

META_DIR="$TOS_PARSE_DIR/meta"
FILE_DIR="$TOS_PARSE_DIR/files"

echo "⚡ STAGE 1: PARSING METADATA"
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "META" "$META_DIR" "TARGET_PROJECT" "TARGET_TRINITY" "TITLE" "BODY"

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
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "FILE" "$FILE_DIR"

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

        # [SECURITY] Manifest Visa Verification (ADR 9)
        # Delegated to the shared util: word-exact matching, not substring.
        # A manifest listing "src/config.zsh" must NOT authorise "config.zsh".
        "$TOS_BIN/utils/check_manifest_visa.zsh" \
            "$FILE_PATH" "$TOS_ACTIVE_PROJECT" "$ACTIVE_TRINITY" || exit 1

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
COMMIT_MSG=$(printf '%s\n\n%s\n\nFixes #%s\n' "$TITLE" "$BODY" "$ACTIVE_TRINITY")
git commit -m "$COMMIT_MSG"

# --- ARCHITECTURE FIX: Abort immediately if push fails ---
git push origin "$CURRENT_BRANCH" --force-with-lease || {
    echo "🚨 FATAL: Push failed. Halting publication." >&2
    exit 1
}

if gh pr view "$CURRENT_BRANCH" &>/dev/null; then
    gh pr edit "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$BODY"
else
    gh pr create --title "$PR_TITLE" --body "$BODY" --head "$CURRENT_BRANCH"
fi

echo "🏁 CODE WRITE COMPLETE"

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
