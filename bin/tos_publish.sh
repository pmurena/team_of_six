#!/bin/zsh
# Team of Six - Publisher V57 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"
STATE_FILE="$TARGET_DIR/.tos/state"
COMMIT_FILE="$TARGET_DIR/.tos/commit_msg"
SUMMARY_FILE="$TARGET_DIR/.tos/pr_summary.md"

# 1. MUTEX CHECK
if [ ! -s "$COMMIT_FILE" ]; then
    echo "⛔ PUBLISH FAILED: Missing or empty .tos/commit_msg. The AI must provide a commit message."
    exit 1
fi
MSG=$(cat "$COMMIT_FILE")

if [ ! -s "$SUMMARY_FILE" ]; then
    echo "⛔ PUBLISH FAILED: Missing or empty .tos/pr_summary.md. The AI must provide context for the PR."
    exit 1
fi
SUMMARY=$(cat "$SUMMARY_FILE")

# 2. GOVERNANCE CHECK (Allowing Red PRs)
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "Unknown")
if [[ "$CURRENT_STATE" == "Requirement" ]]; then
    echo "⛔ GOVERNANCE VETO: Cannot publish in state [$CURRENT_STATE]"
    exit 1
fi

echo "🚀 Governor: Initiating Sandboxed Publication..."

# 3. SANDBOXED EXECUTION & GITHUB SYNC
sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"
    
    # Git Auth & Identity
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    CURRENT_BRANCH=\$(git branch --show-current)
    
    if [[ "\$CURRENT_BRANCH" == "main" ]]; then
        BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
        git checkout -b "\$BRANCH_NAME"
        IS_NEW_PR=true
    else
        BRANCH_NAME="\$CURRENT_BRANCH"
        IS_NEW_PR=false
    fi

    git add .
    git commit -m "$MSG"
    git push origin "\$BRANCH_NAME"

    # GitHub Sync
    if [ "\$IS_NEW_PR" = true ] || ! gh pr view "\$BRANCH_NAME" >/dev/null 2>&1; then
        gh pr create --title "tos: \$BRANCH_NAME" --body "\$SUMMARY" --fill
    else
        gh pr comment "\$BRANCH_NAME" --body "\$SUMMARY"
    fi
SANDBOX

# 4. UNLOCK MUTEX
> "$COMMIT_FILE"
> "$SUMMARY_FILE"

echo "✅ Published & Synced to GitHub. Sandbox unlocked for next task."
