#!/bin/zsh
# ==============================================================================
# Team of Six - Code Publisher
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && { echo "⚠️ Inbox empty."; exit 1; }

cd "$TOS_WORKING_DIR" || exit 1
umask 077

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$CURRENT_BRANCH" =~ ^tos-work-([0-9]+)$ ]] || { echo "🚨 ERROR: Not on a tos-work-# branch."; exit 1; }
ISSUE_ID="${match[1]}"

echo "⚡ STAGE 1: PARSING CODE INBOX (SECURE)"

# Secure AWK Parser: Extracts variables without creating executable bash files
awk '
BEGIN { state="none"; in_body=0 }
/^===TOS_META_START===/ { state="meta"; next }
/^===TOS_META_END===/   { state="none"; in_body=0; next }

/^===TOS_FILE_START:/ {
    state="file"
    filepath = $0
    sub(/^===TOS_FILE_START:[ \t]*/, "", filepath)
    sub(/===$/, "", filepath)
    
    # [SECURITY] Path Traversal Protection
    if (filepath ~ /\.\./ || filepath ~ /^\//) {
        print "🚨 SEC-FAULT: Illegal file path detected (" filepath ")." > "/dev/stderr"
        exit 1
    }
    
    system("mkdir -p \"$(dirname \"" filepath "\")\"")
    printf "" > filepath
    next
}
/^===TOS_FILE_END===/ { state="none"; close(filepath); next }

# Securely route TITLE and BODY to safe plaintext files
state=="meta" && /^TITLE=/ { sub(/^TITLE=/, ""); print $0 > "tos_title.txt"; next }
state=="meta" && /^BODY=/  { in_body=1; sub(/^BODY=/, ""); print $0 > "tos_body.txt"; next }
state=="meta" && in_body==1 { print $0 >> "tos_body.txt" }

state=="file" { print $0 >> filepath }
' "$TOS_INPUT"

# Fail fast if awk threw a security exception
[[ $? -ne 0 ]] && exit 1

# Safely load the extracted text
[[ ! -f "tos_title.txt" ]] && { echo "🚨 FATAL: Missing TITLE in metadata."; rm -f tos_*.txt; exit 1; }
TITLE=$(cat "tos_title.txt")
BODY=$(cat "tos_body.txt" 2>/dev/null || echo "")
rm -f "tos_title.txt" "tos_body.txt"

echo "🚀 STAGE 2: PUBLISHING CODE"

export GIT_AUTHOR_NAME="Team of Six (Ghost)"
export GIT_AUTHOR_EMAIL="ghost@teamofsix.local"

PR_TITLE="[Ghost] Issue #$ISSUE_ID: $TITLE"

git add .
git commit -m "$TITLE\n\n$BODY\n\nFixes #$ISSUE_ID"

# [SECURITY] Upgraded to --force-with-lease to prevent overwriting human commits
set -x
if git push origin "$CURRENT_BRANCH" --force-with-lease; then
    if gh pr view "$CURRENT_BRANCH" &>/dev/null; then
        gh pr edit "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$BODY"
    else
        gh pr create --title "$PR_TITLE" --body "$BODY" --head "$CURRENT_BRANCH"
    fi
fi
set +x

truncate -s 0 "$TOS_INPUT"
echo "🏁 CODE WRITE COMPLETE"
