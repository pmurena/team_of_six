#!/bin/zsh

# ==============================================================================
# Team of Six - Repo cleaner after test session.
# ==============================================================================

# Check for necessary permissions first
if ! gh auth status -s delete_repo >/dev/null 2>&1; then
    echo "⚠️  Scope 'delete_repo' required. Authorizing..."
    gh auth refresh -s delete_repo
fi

GIT_USER=$(gh api user -q .login)
SANDBOX_ROOT="/mnt/team_of_six/tos_home/$USER/sandbox"

for repo in tos-trinity-test-*; do
    if [ -d "$repo" ]; then
        echo "Trying to delete remote: $GIT_USER/$repo"
        
        # We use && so local/sandbox rm ONLY happens if gh succeeds
        if gh repo delete "$GIT_USER/$repo" --yes; then
            echo "✅ Remote deleted."
            
            echo "🧹 Removing Architect local folder..."
            rm -rf "$repo"
            
            # --- NEW: Clean the Ghost's secure sandbox ---
            if [ -d "$SANDBOX_ROOT/$repo" ]; then
                echo "🧹 Removing Ghost sandbox clone..."
                # Requires sudo because the sandbox is owned by the AI user
                sudo rm -rf "$SANDBOX_ROOT/$repo"
            fi
        else
            echo "❌ Failed to delete remote $repo. Keeping local folders for safety."
        fi
        echo "---------------------------------------"
    fi
done

# Optional: Cleanup permissions
read -q "REPLY?Cleanup finished. Revoke 'delete_repo' scope? (y/n) "
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh auth refresh --remove-scopes delete_repo
    echo "\n✅ Permissions reset."
fi
