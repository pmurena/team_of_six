#!/bin/zsh
# ==============================================================================
# Team of Six - Repo cleaner after test session.
# ==============================================================================

if ! gh auth status -s delete_repo >/dev/null 2>&1; then
    echo "⚠️  Scope 'delete_repo' required. Authorizing..."
    gh auth refresh -s delete_repo
fi

GIT_USER=$(gh api user -q .login)
SANDBOX_ROOT="/mnt/team_of_six/sandbox/$USER"

for repo in tos-trinity-test-*; do
    if [ -d "$repo" ]; then
        echo "Trying to delete remote: $GIT_USER/$repo"

        if gh repo delete "$GIT_USER/$repo" --yes; then
            echo "✅ Remote deleted."

            echo "🧹 Removing Architect local folder..."
            rm -rf "$repo"

            if [ -d "$SANDBOX_ROOT/$repo" ]; then
                echo "🧹 Removing Ghost sandbox clone..."
                sudo rm -rf "$SANDBOX_ROOT/$repo"
            fi
        else
            echo "❌ Failed to delete remote $repo. Keeping local folders for safety."
        fi
        echo "---------------------------------------"
    fi
done

read -q "REPLY?Cleanup finished. Revoke 'delete_repo' scope? (y/n) "
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh auth refresh --remove-scopes delete_repo
    echo "\n✅ Permissions reset."
fi
