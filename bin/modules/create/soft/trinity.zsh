#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
TRINITY_ID="$2" 

if [[ -z "$TRINITY_ID" ]]; then
    echo "🚨 [ERROR] create trinity: Missing trinity ID." >&2
    exit 1
fi

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1
echo "⚡ CREATING TRINITY #$TRINITY_ID (Branch: tos-work-$TRINITY_ID)"

# --- align before branching ---------------------------------------------------
# A Trinity branched from a stale main carries nothing GitHub can open a pull
# request against:
#     No commits between main and tos-work-N
# The sandbox is behind origin/main any time the Architect has pushed since the
# last sync, which is most of the time. Relying on the Architect to run
# `sync trinity 0` first works only while somebody remembers.
git fetch origin --prune -q || {
    echo "🚨 [ERROR] create trinity: git fetch failed." >&2
    exit 1
}
# Distinguish a missing base branch from a divergent one. They need
# completely different responses, and reporting the second for the first
# sends the Architect looking for a conflict that does not exist.
if ! git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "🚨 [ERROR] create trinity: origin/main does not exist." >&2
    echo "    The repository has no commits on its default branch, so there is" >&2
    echo "    nothing to branch a Trinity from. TOS does not initialise" >&2
    echo "    repositories — push a first commit to main and retry:" >&2
    echo "      git push -u origin main" >&2
    exit 1
fi
git checkout main -q 2>/dev/null || git checkout -b main --track origin/main -q
git pull --ff-only origin main -q || {
    echo "🚨 [ERROR] create trinity: main has diverged from origin/main." >&2
    echo "    Resolve it out of band, then retry." >&2
    exit 1
}

git checkout -b "tos-work-$TRINITY_ID" -q 2>/dev/null || git checkout "tos-work-$TRINITY_ID" -q

# 1. Create the empty commit to satisfy GitHub's PR diff requirement
if ! git commit --allow-empty -m "chore: initialize trinity #$TRINITY_ID" -q; then
    echo "🚨 [ERROR] create trinity: Failed to create empty commit." >&2
    exit 1
fi

# 2. Ask GitHub exactly who the Ghost is, then build a bulletproof Auth URL
REPO_FULL=$("$TOS_BIN/utils/resolve_repo.zsh" "$TOS_ACTIVE_PROJECT") || exit 1
AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_FULL}.git"

# Notice: The blindfold (2>/dev/null) is completely removed!
if ! git push -u "$AUTH_URL" "tos-work-$TRINITY_ID" -q; then
    echo "🚨 [ERROR] create trinity: Failed to push branch to remote." >&2
    exit 1
fi

# --- guarantee one commit -----------------------------------------------------
# GitHub will not open a pull request between two identical refs. An empty
# commit is the honest marker that a Trinity has been opened and nothing has
# been built in it yet.
if [[ "$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)" == "0" ]]; then
    git commit --allow-empty -q -m "chore: open Trinity #$TRINITY_ID"
    git push origin "tos-work-$TRINITY_ID" -q || {
        echo "🚨 [ERROR] create trinity: could not push the opening commit." >&2
        exit 1
    }
fi

# 3. Open the Draft PR
if ! gh pr create --draft --title "Trinity #$TRINITY_ID" --body "Fixes #$TRINITY_ID" --base main --head "tos-work-$TRINITY_ID"; then
    echo "🚨 [ERROR] create trinity: Failed to create pull request." >&2
    echo "    Rolling back — a half-built Trinity is worse than none." >&2

    # The branch was pushed before this point. Left behind, it is a Trinity
    # that exists enough to block the next attempt and not enough to use:
    # sync trinity refuses it for having no phase record, and the recovery it
    # names (close trinity) currently squash-merges. So undo it here.
    git checkout main -q 2>/dev/null || true
    git branch -D "tos-work-$TRINITY_ID" -q 2>/dev/null || true
    git push origin --delete "tos-work-$TRINITY_ID" -q 2>/dev/null || true
    echo "    Branch tos-work-$TRINITY_ID removed locally and on the remote." >&2
    echo "    Nothing else was created. Retry when the cause is fixed." >&2
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
