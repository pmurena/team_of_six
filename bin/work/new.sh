#!/bin/zsh
# ==============================================================================
# Team of Six - Batch Issue Creator
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
PROJECT_NAME="$1"

if [ ! -s "$TOS_INPUT" ]; then
    echo "⚠️  Inbox is empty. Ask the Ghost to provide ===TOS_ISSUE_START=== blocks first."
    exit 1
fi

cd "$TOS_WORKING_DIR" || exit 1
umask 077

echo "⚡ STAGE 1: PARSING BATCH ISSUES (SECURE)"

ISSUE_DIR="$TOS_IPC/tmp_issues_$(date +%s)"
mkdir -p "$ISSUE_DIR"

# Secure AWK Parser: Writes separate text files instead of executable scripts
awk -v outdir="$ISSUE_DIR" '
BEGIN { issue_count=0; state="none"; in_body=0 }
/^===TOS_ISSUE_START===/ {
    issue_count++
    state="issue"
    title_file = outdir "/issue_" issue_count "_title.txt"
    body_file = outdir "/issue_" issue_count "_body.txt"
    printf "" > title_file
    printf "" > body_file
    next
}
/^===TOS_ISSUE_END===/ { state="none"; in_body=0; next }

state=="issue" && /^TITLE=/ { sub(/^TITLE=/, ""); print $0 > title_file; next }
state=="issue" && /^BODY=/  { in_body=1; sub(/^BODY=/, ""); print $0 > body_file; next }
state=="issue" && in_body==1 { print $0 >> body_file }
' "$TOS_INPUT"

# Use the generated title files to drive the loop
TITLE_FILES=("$ISSUE_DIR"/issue_*_title.txt(N))

if [[ ${#TITLE_FILES[@]} -eq 0 ]]; then
    echo "🚨 ERROR: No valid ===TOS_ISSUE_START=== blocks found in the inbox."
    rm -rf "$ISSUE_DIR"
    exit 1
fi

echo "🚀 STAGE 2: CREATING ${#TITLE_FILES[@]} GITHUB ISSUES"

for title_file in "${TITLE_FILES[@]}"; do
    # Resolve the matching body file path
    base=${title_file%_title.txt}
    body_file="${base}_body.txt"

    # Read safely using cat
    TITLE=$(cat "$title_file" 2>/dev/null)
    BODY=$(cat "$body_file" 2>/dev/null)

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
