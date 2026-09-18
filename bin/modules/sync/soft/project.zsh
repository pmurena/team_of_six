#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"

echo "🚀 Provisioning Sandbox for $PROJECT_NAME..."
# Derive the remote from GitHub, NOT from the Architect's working directory.
# This module runs as the Ghost; reading the Architect's tree here would
# breach sandbox isolation and fails outright on a non-traversable directory.
REPO_FULL=$("$TOS_BIN/utils/resolve_repo.zsh" "$PROJECT_NAME")
[[ -z "$REPO_FULL" ]] && { echo "⛔ ERROR: No GitHub repository named '$PROJECT_NAME' is visible to the Ghost."; exit 1; }
REMOTE_URL="https://github.com/${REPO_FULL}.git"

# An empty repository has no default branch. Attaching to one succeeds and
# then fails three commands later, at create trinity, with an error naming a
# branch the Architect never made. Refuse here, where the cause is visible.
DEFAULT_BRANCH=$(gh repo view "$REPO_FULL" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
if [[ -z "$DEFAULT_BRANCH" ]]; then
    echo "⛔ ERROR: '$REPO_FULL' has no commits, so it has no default branch." >&2
    echo "    TOS attaches to repositories; it does not initialise them." >&2
    echo "" >&2
    echo "    From your own clone:" >&2
    echo "      echo \"# $PROJECT_NAME\" > README.md" >&2
    echo "      git add README.md && git commit -m \"chore: initialise main\"" >&2
    echo "      git push -u origin main" >&2
    echo "" >&2
    echo "    Or create the repository with content next time:" >&2
    echo "      gh repo create $PROJECT_NAME --private --add-readme" >&2
    exit 1
fi

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
