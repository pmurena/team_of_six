#!/bin/zsh
# ==============================================================================
# Title: Trinity Workspace Activator
# Usage: tos <project> sync trinity <ID>
#
# Acquires the global project:trinity lock, checks out the dedicated branch,
# pulls the PR thread, and generates the full context map in the outbox.
# The lock is released on exit via the gateway's trap.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"
TRINITY_ID="$2"
[[ -z "$TRINITY_ID" ]] && { echo "Usage: tos <project> sync trinity <ID>"; exit 1; }

BRANCH_NAME="tos-work-$TRINITY_ID"

export GH_PAGER=cat
export GH_PROMPT_DISABLED=1
export NO_COLOR=1

# --- Lock Acquisition ---
"$TOS_BIN/utils/lock_manager.sh" acquire "$PROJECT_NAME" "$TRINITY_ID" || exit 1
# Lock is released by the gateway trap on exit

cd "$TOS_SANDBOX/$PROJECT_NAME" || exit 1

echo "🧹 Enforcing Remote Truth..."
git fetch origin --prune &>/dev/null
git reset --hard HEAD &>/dev/null
git clean -fd &>/dev/null

git checkout main && git pull origin main &>/dev/null
echo "🚀 Routing Ghost to Workspace: $BRANCH_NAME"

if git rev-parse --verify "origin/$BRANCH_NAME" >/dev/null 2>&1; then
    git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME" &>/dev/null
else
    git checkout -b "$BRANCH_NAME" &>/dev/null
fi

{
    echo "# TRINITY CONTEXT: #${TRINITY_ID} (Branch: $BRANCH_NAME)\n"
    echo "TARGET_PROJECT=$PROJECT_NAME"
    echo "TARGET_TRINITY=$TRINITY_ID"
    gh issue view "$TRINITY_ID" --comments 2>&1

    if gh pr view "$BRANCH_NAME" &>/dev/null; then
        echo -e "\n## PULL REQUEST CONTEXT & COMMENTS"
        gh pr view "$BRANCH_NAME" --comments 2>&1
    fi

    echo -e "\n## CURRENT DIFF (origin/main...HEAD)"
    git diff origin/main...HEAD
    echo -e "\n## REPOSITORY SIGNATURE MAP"
    if command -v ctags &>/dev/null; then
        ctags -x -R --exclude=.git . 2>/dev/null
    else
        git ls-files
    fi
} > "$TOS_CONTEXT"

echo "✅ Context staged at $TOS_CONTEXT"
