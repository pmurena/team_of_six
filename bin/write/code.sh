#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && { echo "⚠️ Inbox empty."; exit 1; }

cd "$TOS_WORKING_DIR" || exit 1
umask 077

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]] || { echo "🚨 ERROR: Not on a tos-work-# branch."; exit 1; }
ISSUE_ID="${match[1]}"

echo "⚡ STAGE 1: PARSING CODE INBOX"

awk '
BEGIN { state="none" }
/^===TOS_META_START===/ { state="meta"; next }
/^===TOS_META_END===/   { state="none"; next }
/^===TOS_FILE_START:/ {
    state="file"
    filepath = $0
    sub(/^===TOS_FILE_START:[ \t]*/, "", filepath)
    sub(/===$/, "", filepath)
    system("mkdir -p \"$(dirname \"" filepath "\")\"")
    printf "" > filepath
    next
}
/^===TOS_FILE_END===/ { state="none"; close(filepath); next }
state=="meta" { print $0 >> "tos_meta.env" }
state=="file" { print $0 >> filepath }
' "$TOS_INPUT"

[[ ! -f "tos_meta.env" ]] && { echo "🚨 FATAL: Missing ===TOS_META_START==="; exit 1; }
source "tos_meta.env"
rm "tos_meta.env"
[[ -z "$TITLE" ]] && { echo "🚨 ERROR: Missing TITLE."; exit 1; }

echo "🚀 STAGE 2: PUBLISHING CODE"

export GIT_AUTHOR_NAME="Team of Six (Ghost)"
export GIT_AUTHOR_EMAIL="ghost@teamofsix.local"

PR_TITLE="[Ghost] Issue #$ISSUE_ID: $TITLE"

git add .
git commit -m "$TITLE\n\n$BODY\n\nFixes #$ISSUE_ID"

set -x
if git push origin "$CURRENT_BRANCH" --force; then
    if gh pr view "$CURRENT_BRANCH" &>/dev/null; then
        gh pr edit "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$BODY"
    else
        gh pr create --title "$PR_TITLE" --body "$BODY" --head "$CURRENT_BRANCH"
    fi
fi
set +x

truncate -s 0 "$TOS_INPUT"
echo "🏁 CODE WRITE COMPLETE"
