#!/bin/zsh
# Team of Six - Publisher V58 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"

HAS_REF=false;    [ -s "$TARGET_DIR/.tos/ref" ] && HAS_REF=true
HAS_BRANCH=false; [ -s "$TARGET_DIR/.tos/branch" ] && HAS_BRANCH=true
HAS_TITLE=false;  [ -s "$TARGET_DIR/.tos/title" ] && HAS_TITLE=true
HAS_BODY=false;   [ -s "$TARGET_DIR/.tos/body" ] && HAS_BODY=true

if [ "$HAS_BODY" = false ]; then
    echo "⛔ PUBLISH FAILED: Missing .tos/body. The AI must provide context for the action."
    exit 1
fi

echo "🚀 Governor: Evaluating State & Routing to GitHub..."

sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"
    BODY=\$(cat .tos/body)

    # Git Auth
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    # --- 1. CODEBASE MODIFICATION (PR ROUTE) ---
    if [ "$HAS_BRANCH" = true ]; then
        if [ "$HAS_TITLE" = false ]; then
            echo "⛔ PUBLISH FAILED: Code changes require a .tos/title for the commit message."
            exit 1
        fi
        
        BRANCH=\$(cat .tos/branch)
        TITLE=\$(cat .tos/title)

        echo "📦 Branch detected. Committing and pushing..."
        git checkout -B "\$BRANCH"
        git add .
        git commit -m "\$TITLE" -m "\$BODY"
        git push -u origin "\$BRANCH"

        if [ "$HAS_REF" = true ]; then
            REF=\$(cat .tos/ref)
            echo "💬 Updating PR #\$REF..."
            gh pr comment "\$REF" --body "\$BODY"
        else
            echo "✨ Creating new Pull Request..."
            NEW_REF=\$(gh pr create --title "\$TITLE" --body "\$BODY" --head "\$BRANCH" | grep -oE '[0-9]+$')
            echo "\$NEW_REF" > .tos/ref
        fi

    # --- 2. DISCUSSION ONLY (ISSUE ROUTE) ---
    else
        echo "📝 No branch detected. Routing to GitHub Issues..."
        if [ "$HAS_REF" = true ]; then
            REF=\$(cat .tos/ref)
            echo "💬 Commenting on Issue #\$REF..."
            gh issue comment "\$REF" --body "\$BODY"
        else
            if [ "$HAS_TITLE" = false ]; then
                echo "⛔ PUBLISH FAILED: Creating a new issue requires a .tos/title."
                exit 1
            fi
            echo "✨ Creating new Issue..."
            NEW_REF=\$(gh issue create --title "\$TITLE" --body "\$BODY" | grep -oE '[0-9]+$')
            echo "\$NEW_REF" > .tos/ref
        fi
    fi
SANDBOX

# Unlock Mutex
> "$TARGET_DIR/.tos/title"
> "$TARGET_DIR/.tos/body"
# Clean up legacy V57 files if they exist
rm -f "$TARGET_DIR/.tos/commit_msg" "$TARGET_DIR/.tos/pr_summary.md" 2>/dev/null

echo "✅ Published & Synced to GitHub. Sandbox unlocked for next task."
