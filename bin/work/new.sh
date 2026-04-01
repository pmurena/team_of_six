#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
PROJECT_NAME="$1"

if [ ! -s "$TOS_INPUT" ]; then
    echo "⚠️  Inbox is empty. Ask the Ghost to provide ===TOS_ISSUE_START=== blocks first."
    exit 1
fi

cd "$TOS_WORKING_DIR" || exit 1
umask 077

echo "⚡ STAGE 1: PARSING BATCH ISSUES"

ISSUE_DIR="$TOS_IPC/tmp_issues_$(date +%s)"
mkdir -p "$ISSUE_DIR"

awk -v outdir="$ISSUE_DIR" '
BEGIN { issue_count=0; state="none" }
/^===TOS_ISSUE_START===/ {
    issue_count++
    state="issue"
    filepath = outdir "/issue_" issue_count ".env"
    printf "" > filepath
    next
}
/^===TOS_ISSUE_END===/ { state="none"; close(filepath); next }
state=="issue" { print $0 >> filepath }
' "$TOS_INPUT"

ISSUE_FILES=("$ISSUE_DIR"/issue_*.env(N))

if [[ ${#ISSUE_FILES[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_ISSUE_START=== blocks found in the inbox."
    rm -rf "$ISSUE_DIR"
    exit 1
fi

echo "🚀 STAGE 2: CREATING ${#ISSUE_FILES[@]} GITHUB ISSUES"

for file in "${ISSUE_FILES[@]}"; do
    source "$file"
    if [[ -n "$TITLE" ]]; then
        echo "✨ Creating: $TITLE"
        gh issue create --title "$TITLE" --body "$BODY"
    else
        echo "⚠️ Warning: Skipping malformed issue block (Missing TITLE)."
    fi
done

rm -rf "$ISSUE_DIR"
truncate -s 0 "$TOS_INPUT"
echo "🏁 BATCH ISSUE CREATION COMPLETE"
