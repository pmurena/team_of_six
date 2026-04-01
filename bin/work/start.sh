#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
PROJECT_NAME="$1"

echo "🚀 Provisioning Sandbox for $PROJECT_NAME..."
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
[[ -z "$REMOTE_URL" ]] && { echo "⛔ ERROR: Run this from an initialized Architect repo."; exit 1; }

SANDBOX_DIR="$TOS_SANDBOX/$PROJECT_NAME"
[[ -d "$SANDBOX_DIR" ]] && { echo "⛔ ERROR: Sandbox already exists."; exit 1; }

GITHUB_TOKEN=$(cat "$TOS_CONF/.token" | tr -d '\n\r ')
REPO_PATH=$(echo "$REMOTE_URL" | sed -e 's/.*github.com[:/]//' -e 's/\.git$//')
AUTH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"

umask 077
mkdir -p "$TOS_SANDBOX" && cd "$TOS_SANDBOX" || exit 1
git clone "$AUTH_URL" "$PROJECT_NAME"

cd "$PROJECT_NAME"
git config --local user.name "Team of Six (Ghost)"
git config --local user.email "ghost@teamofsix.local"

echo "✅ Sandbox Ready. Open Issues:"
gh issue list
