#!/bin/zsh
# Team of Six - Publisher V56 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"
STATE_FILE="$TARGET_DIR/.tos/state"

CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "Unknown")
if [[ "$CURRENT_STATE" == "Red" || "$CURRENT_STATE" == "Requirement" ]]; then
    echo "⛔ GOVERNANCE VETO: Cannot publish in state [$CURRENT_STATE]"
    exit 1
fi

echo "🚀 Governor: Initiating Sandboxed Publication..."

# [FIXED] Git operations sandboxed under AI_USER
# [FIXED] Logic re-ordered: Init/Check -> Config -> Action
sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"

    # 1. Ensure Repo Exists
    if [ ! -d ".git" ]; then
        echo "🌱 Initializing new repository..."
        git init -b main
        IS_NEW=true
    else
        IS_NEW=false
    fi

    # 2. Configure Identity (Now safe as .git exists)
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    # 3. Execute Actions
    if [ "\$IS_NEW" = true ]; then
        git add .
        git commit -m "scaff: project genesis"
        REPO_NAME=\$(basename "\$(pwd)")
        gh repo create "\$REPO_NAME" --private --source=. --remote=origin --push
    else
        BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
        git checkout -b "\$BRANCH_NAME"
        git add .
        if ! git diff --cached --quiet; then
            git commit -m "feat: updates for state [$CURRENT_STATE]"
            git push origin "\$BRANCH_NAME"
            gh pr create --title "tos: \$BRANCH_NAME" --body "Automated release from state $CURRENT_STATE" --fill
        else
            echo "no changes detected"
        fi
    fi
SANDBOX

echo "✅ Publication Complete."
