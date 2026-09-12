#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"

echo "🚀 Provisioning Sandbox for $PROJECT_NAME..."
# Derive the remote from GitHub, NOT from the Architect's working directory.
# This module runs as the Ghost; reading the Architect's tree here would
# breach sandbox isolation and fails outright on a non-traversable directory.
REPO_FULL=$(gh repo view "$PROJECT_NAME" --json nameWithOwner -q .nameWithOwner 2>/dev/null)
[[ -z "$REPO_FULL" ]] && { echo "⛔ ERROR: No GitHub repository named '$PROJECT_NAME' is visible to the Ghost."; exit 1; }
REMOTE_URL="https://github.com/${REPO_FULL}.git"

SANDBOX_DIR="$TOS_SANDBOX/$PROJECT_NAME"
[[ -d "$SANDBOX_DIR" ]] && { echo "⛔ ERROR: Sandbox already exists."; exit 1; }

[[ -z "$GH_TOKEN" ]] && { echo "⛔ ERROR: GH_TOKEN is not set by the gateway."; exit 1; }

AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_FULL}.git"

umask 077
mkdir -p "$TOS_SANDBOX" && cd "$TOS_SANDBOX" || exit 1
git clone "$AUTH_URL" "$PROJECT_NAME"

cd "$PROJECT_NAME"
git config --local user.name "Team of Six (Ghost)"
git config --local user.email "ghost@teamofsix.local"

# Fix: Correctly pass 3 arguments (Project, Trinity, Architect)
"$TOS_BIN/utils/lock/acquire.zsh" "$PROJECT_NAME" "0" "$SUDO_USER" || {
    echo "⛔ ERROR: Failed to acquire Trinity 0 soft-lock."
    exit 1
}

echo "✅ Sandbox Ready. Trinity 0 soft-lock acquired. Open Issues:"
gh issue list
