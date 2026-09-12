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

# 4. PHASE GATE — initialise the phase record at red.
# Written only after the PR exists: the record refers to reviews on that PR,
# and a record without a PR is unvalidatable from birth.
GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
PHASE_FILE="${GLOBAL_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TRINITY_ID}.phase"
umask 077
{
    echo "current=red"
    echo "red="
    echo "green="
    echo "refactor="
    echo "retrospect="
} > "$PHASE_FILE"
echo "🔴 Phase record initialised at red."
echo "   Advance with a tagged review, then: tos $TOS_ACTIVE_PROJECT write phase"
echo "     gh pr review tos-work-$TRINITY_ID --approve --body \"[PHASE:RED->GREEN] ...\""
