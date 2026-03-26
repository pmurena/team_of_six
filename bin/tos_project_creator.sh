#!/bin/zsh
# Team of Six - Project Creator (Architect-First Genesis)
set -e

echo "🚀 Initiating Sandbox linkage for Architect repository..."

# 1. Verify we are in an initialized Git repository
if [ ! -d ".git" ]; then
    echo "⛔ ERROR: No .git directory found in the current folder."
    echo "Please initialize the repository (git init) and set up the remote first."
    exit 1
fi

# 2. Extract Remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$REMOTE_URL" ]; then
    echo "⛔ ERROR: No remote 'origin' found."
    echo "Please add a remote (e.g., git remote add origin <url>) before linking to the Ghost Sandbox."
    exit 1
fi

# Use the current directory name as the project name
PROJECT_NAME=$(basename "$(pwd)")
SANDBOX_DIR="$TOS_SANDBOX/$PROJECT_NAME"

echo "📂 Project: $PROJECT_NAME"
echo "🔗 Remote:  $REMOTE_URL"

# 3. Prevent overwriting existing sandbox instances
if [ -d "$SANDBOX_DIR" ]; then
    echo "⛔ ERROR: The repository is already cloned in the sandbox at $SANDBOX_DIR."
    echo "Aborting to prevent state corruption."
    exit 1
fi

# 4. Provision the Ghost Sandbox (As AI_USER)
echo "👻 Provisioning Ghost Sandbox at $SANDBOX_DIR..."

# Resolve Token (Checking standard V68/V64 locations if not already exported)
if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f "$TOS_MNT_ROOT/.local/conf/.token" ]; then
        GITHUB_TOKEN=$(cat "$TOS_MNT_ROOT/.local/conf/.token" | tr -d '\n\r ')
    elif [ -f "$TOS_SANDBOX/.tos/.token" ]; then
        GITHUB_TOKEN=$(cat "$TOS_SANDBOX/.tos/.token" | tr -d '\n\r ')
    else
        echo "⛔ ERROR: GITHUB_TOKEN is not set or found in the configuration files."
        exit 1
    fi
fi

# Extract the "user/repo" path from either SSH or HTTPS URLs
REPO_PATH=$(echo "$REMOTE_URL" | sed -e 's/.*github.com[:/]//' -e 's/\.git$//')
AUTH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"

# Navigate to sandbox and clone
cd "$TOS_SANDBOX" || exit 1
git clone "$AUTH_URL" "$PROJECT_NAME"

# Configure the local Git identity inside the sandbox
cd "$PROJECT_NAME"
git config --local user.name "Team of Six"
git config --local user.email "agent@teamofsix.bot"

echo "✅ Project '$PROJECT_NAME' successfully linked and checked out in the Ghost Sandbox!"
