#!/bin/zsh
# ==============================================================================
# Title: The Incubator
# Usage: tos <project> create project
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT="$1"
SANDBOX_DIR="$TOS_SANDBOX/$PROJECT"

if [[ -d "$SANDBOX_DIR" ]]; then
    echo "🚨 [ERROR] Sandbox already exists for $PROJECT." >&2
    exit 1
fi

# Parse META block for repository description (if provided)
BODY=""
if [[ -s "$TOS_INPUT" ]]; then
    "$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "META" "$TOS_PARSE_DIR" "BODY"
    BODY=$(cat "$TOS_PARSE_DIR/1/BODY.txt" 2>/dev/null)
    
    # ADR 10: Truncate immediately after parsing, before any network calls
    truncate -s 0 "$TOS_INPUT"
fi

echo "🚀 Incubating Project: $PROJECT..."

REMOTE_URL=""

# Check Remote Truth
if gh repo view "$PROJECT" &>/dev/null; then
    echo "✨ Remote repository found. Provisioning sandbox..."
    
    # Scenario A: Clone Existing
    GHOST_USER=$(gh api user -q .login)
    AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${GHOST_USER}/${PROJECT}.git"
    
    umask 077
    mkdir -p "$TOS_SANDBOX" && cd "$TOS_SANDBOX" || exit 1
    git clone "$AUTH_URL" "$PROJECT" -q
    
    cd "$PROJECT"
    git config --local user.name "Team of Six (Ghost)"
    git config --local user.email "ghost@teamofsix.local"
    
    REMOTE_URL=$(gh repo view "$PROJECT" --json sshUrl -q .sshUrl 2>/dev/null)

else
    echo "✨ No remote found. Creating blank slate repository..."
    
    # Scenario B: Initialize New
    umask 077
    mkdir -p "$SANDBOX_DIR" && cd "$SANDBOX_DIR" || exit 1
    
    git init -q
    git checkout -b main -q
    git config --local user.name "Team of Six (Ghost)"
    git config --local user.email "ghost@teamofsix.local"
    
    echo "# ${PROJECT}" > README.md
    [[ -n "$BODY" ]] && echo "\n$BODY" >> README.md
    
    git add README.md
    git commit -m "chore: initial commit by Ghost" -q
    
    if ! gh repo create "$PROJECT" --private --description "$BODY" --source=. --remote=origin --push; then
        echo "🚨 [ERROR] GitHub CLI failed to create and push the repository." >&2
        exit 1
    fi
    
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)
fi

# Acquire Trinity 0 Soft-Lock
"$TOS_BIN/utils/lock/acquire.zsh" "$PROJECT" "0" "$SUDO_USER" >/dev/null 2>&1 || {
    echo "🚨 [ERROR] Failed to acquire Trinity 0 soft-lock." >&2
    exit 1
}

# Output for the Architect
echo "✅ Incubation Complete."
echo ""
echo "REMOTE_URL=$REMOTE_URL"

# Generate clone suggestions
REPO_FULL=$(gh repo view "$PROJECT" --json nameWithOwner -q .nameWithOwner 2>/dev/null)
echo "CLONE_HTTPS=\"git clone https://github.com/${REPO_FULL}.git .\""
echo "CLONE_SSH=\"git clone git@github.com:${REPO_FULL}.git .\""
