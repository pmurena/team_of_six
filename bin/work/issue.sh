#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"
ISSUE_ID="$2"
BRANCH_NAME="tos-work-$ISSUE_ID"

export GH_PAGER=cat
export GH_PROMPT_DISABLED=1
export NO_COLOR=1

cd "$TOS_WORKING_DIR" || exit 1

echo "🧹 Enforcing Remote Truth..."
git fetch origin --prune &>/dev/null
git reset --hard HEAD &>/dev/null
git clean -fd &>/dev/null

git checkout main && git pull origin main &>/dev/null
echo "🚀 Routing Ghost to Workspace: $BRANCH_NAME"
git checkout -B "$BRANCH_NAME"

{
    echo "# WORK CONTEXT: ISSUE $ISSUE_ID (Branch: $BRANCH_NAME)\n"
    gh issue view "$ISSUE_ID" --comments 2>&1
    echo -e "\n## CURRENT DIFF (origin/main...HEAD)"
    git diff origin/main...HEAD
    echo -e "\n## REPOSITORY SIGNATURE MAP"
    if command -v ctags &> /dev/null; then ctags -x -R --exclude=.git . 2>/dev/null; else git ls-files; fi
} > "$TOS_CONTEXT"

echo "✅ Context staged at $TOS_CONTEXT"
