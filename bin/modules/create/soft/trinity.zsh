#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
TRINITY_ID="$2" 

if [[ -z "$TRINITY_ID" ]]; then
    echo "🚨 [ERROR] create trinity: Missing trinity ID." >&2
    exit 1
fi

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
echo "⚡ CREATING TRINITY #$TRINITY_ID (Branch: tos-work-$TRINITY_ID)"

git checkout -b "tos-work-$TRINITY_ID" -q 2>/dev/null || git checkout "tos-work-$TRINITY_ID" -q

# 1. Create the empty commit to satisfy GitHub's PR diff requirement
if ! git commit --allow-empty -m "chore: initialize trinity #$TRINITY_ID" -q; then
    echo "🚨 [ERROR] create trinity: Failed to create empty commit." >&2
    exit 1
fi

# 2. Ask GitHub exactly who the Ghost is, then build a bulletproof Auth URL
GHOST_USER=$(gh api user -q .login)
AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${GHOST_USER}/${TOS_ACTIVE_PROJECT}.git"

# Notice: The blindfold (2>/dev/null) is completely removed!
if ! git push -u "$AUTH_URL" "tos-work-$TRINITY_ID" -q; then
    echo "🚨 [ERROR] create trinity: Failed to push branch to remote." >&2
    exit 1
fi

# 3. Open the Draft PR
if ! gh pr create --draft --title "Trinity #$TRINITY_ID" --body "Fixes #$TRINITY_ID" --base main --head "tos-work-$TRINITY_ID"; then
    echo "🚨 [ERROR] create trinity: Failed to create pull request." >&2
    exit 1
fi
