#!/bin/zsh
# Team of Six - Project Creator (Distributed Genesis & Migration)
set -e

PROJECT_NAME=$1
if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: team_of_six new <project_name>"
    exit 1
fi

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ Error: Missing token in $TOS_DIR/.token"; exit 1; }

ARCHITECT_DIR="$(pwd)/$PROJECT_NAME"
SANDBOX_BASE="/mnt/team_of_six"
SANDBOX_DIR="$SANDBOX_BASE/$PROJECT_NAME"

echo "🚀 Initiating Genesis/Migration for '$PROJECT_NAME'..."

# --- 1. ARCHITECT WORKSPACE (Local Scaffolding) ---
echo "📂 1. Setting up Architect workspace at $ARCHITECT_DIR..."
mkdir -p "$ARCHITECT_DIR/.tos"
cd "$ARCHITECT_DIR"

# Only create if they don't exist to prevent overwriting custom migrations
[ ! -f ".tos/state" ] && echo "Scaffolding" > ".tos/state"
[ ! -f ".tos/objections.md" ] && touch ".tos/objections.md"
if [ ! -f ".tos/features.md" ]; then
    cat <<BACKLOG > ".tos/features.md"
# 📋 Project Backlog: $PROJECT_NAME
* [ ] Initial Architecture (Current)
BACKLOG
fi

# --- 2. GIT PUBLICATION ---
echo "🌱 2. Syncing with Git..."
IS_EXISTING_REPO=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_EXISTING_REPO=true
    echo "   -> Existing Git repository detected."
else
    echo "   -> Initializing new Git repository..."
    git init -b main
fi

git add .tos/
if ! git diff --cached --quiet; then
    git commit -m "chore: Team of Six (V56) migration & scaffolding"
fi

# Determine Remote & Push
if [ "$IS_EXISTING_REPO" = true ] && git remote get-url origin >/dev/null 2>&1; then
    echo "   -> Pushing migration to existing origin..."
    git push origin HEAD
    # Extract the repository path (user/repo) using gh cli
    REPO_PATH=$(gh repo view --json nameWithOwner -q .nameWithOwner)
else
    echo "   -> Creating new private repository on GitHub..."
    GITHUB_USER=$(gh api user -q ".login")
    if [ -z "$GITHUB_USER" ]; then
        echo "❌ Error: Could not determine GitHub user. Ensure you are logged in via 'gh auth login'."
        exit 1
    fi
    gh repo create "$PROJECT_NAME" --private --source=. --remote=origin --push
    REPO_PATH="$GITHUB_USER/$PROJECT_NAME"
fi

# --- 3. GHOST SANDBOX (Independent Pull) ---
echo "👻 3. Provisioning Ghost Sandbox at $SANDBOX_DIR..."

if [ ! -d "$SANDBOX_BASE" ]; then
    echo "❌ Error: Sandbox base $SANDBOX_BASE missing."
    exit 1
fi

# Execute clone strictly as the AI_USER
sudo -u "$AI_USER" zsh <<GHOST
    export GH_TOKEN="$GITHUB_TOKEN"
    cd "$SANDBOX_BASE"
    
    if [ -d "$PROJECT_NAME/.git" ]; then
        echo "   -> Sandbox already exists. Pulling latest migration state..."
        cd "$PROJECT_NAME"
        git pull origin HEAD
    else
        echo "   -> Cloning repository into sandbox..."
        git clone "https://x-access-token:\$GH_TOKEN@github.com/$REPO_PATH.git" "$PROJECT_NAME"
        
        # Configure the Ghost's local identity for this repo
        cd "$PROJECT_NAME"
        git config --local user.name "Team of Six (V56)"
        git config --local user.email "agent@teamofsix.bot"
        git config --local url."https://x-access-token:\$GH_TOKEN@github.com/".insteadOf "https://github.com/"
    fi
GHOST

echo "✅ Migration/Genesis Complete!"
echo "   -> Architect Clone: $ARCHITECT_DIR"
echo "   -> Ghost Sandbox:   $SANDBOX_DIR"
