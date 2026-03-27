#!/bin/zsh
REF=$1
CONTEXT_FILE="/run/${AI_USER}/${SUDO_USER}_work_context.md"

if [[ -z "$REF" ]]; then
    echo "Usage: tos <project_name> work <issue_or_pr_id>"
    exit 1
fi

cd "$TOS_WORKING_DIR" || exit 1

echo "📡 Fetching Remote Truth for $REF in $TOS_WORKING_DIR..."
git fetch origin --prune

{
    echo "# WORK CONTEXT: $REF"
    if gh pr view "$REF" &>/dev/null; then
        gh pr view "$REF" --json title,body,comments
        echo "## CURRENT DIFF"
        git diff origin/main...HEAD
    else
        gh issue view "$REF"
    fi
} > "$CONTEXT_FILE"

echo "✅ Context staged at $CONTEXT_FILE"
echo "Launch NeoVim and run :TosWork"
