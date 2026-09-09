#!/bin/zsh
# ==============================================================================
# Team of Six — Test session cleaner
#
# The interactive tutorial works in a mktemp directory under /tmp, so globbing
# the current directory finds nothing. This queries GitHub for the authoritative
# list of test repositories instead, then removes each one's remote, Ghost
# sandbox, and control-plane locks.
# ==============================================================================

set -e

if ! gh auth status >/dev/null 2>&1; then
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

if ! gh auth status 2>&1 | grep -q "delete_repo"; then
    echo "⚠️  Scope 'delete_repo' required. Authorizing..."
    gh auth refresh -h github.com -s delete_repo
fi

GIT_USER=$(gh api user -q .login)
SANDBOX_ROOT="${TOS_MNT_ROOT}/sandbox/${SUDO_USER:-$USER}"
LOCKS_ROOT="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"

# Authoritative list from the remote, not from whatever happens to be in cwd.
REPOS=($(gh repo list "$GIT_USER" --limit 200 --json name -q \
    '.[].name | select(startswith("tos-trinity-test-") or startswith("tos-e2e-test-"))'))

if (( ${#REPOS[@]} == 0 )); then
    echo "✅ No test repositories found on GitHub. Nothing to clean."
else
    echo "Found ${#REPOS[@]} test repositor$( (( ${#REPOS[@]} == 1 )) && echo y || echo ies ):"
    for repo in $REPOS; do echo "   $GIT_USER/$repo"; done
    echo ""
    read -q "REPLY?Delete all of these? (y/n) " || true
    echo ""

    if [[ "$REPLY" == [yY] ]]; then
        for repo in $REPOS; do
            echo "──────────────────────────────────────────"
            echo "Deleting remote: $GIT_USER/$repo"

            if gh repo delete "$GIT_USER/$repo" --yes; then
                echo "✅ Remote deleted."

                SANDBOX_REPO="$SANDBOX_ROOT/$repo"
                if [[ -d "$SANDBOX_REPO" ]]; then
                    echo "🧹 Removing Ghost sandbox @ $SANDBOX_REPO"
                    sudo -u "${AI_USER:-team_of_six}" rm -rf "$SANDBOX_REPO"
                fi

                for lock in "$LOCKS_ROOT/${repo}_trinity_"*(N); do
                    echo "🔓 Removing stale lock: $(basename "$lock")"
                    sudo -u "${AI_USER:-team_of_six}" rm -f "$lock"
                done

                # Architect-side copy, if the tutorial was run from cwd.
                [[ -d "$repo" ]] && { echo "🧹 Removing local folder ./$repo"; rm -rf "$repo"; }
            else
                echo "❌ Failed to delete $repo. Leaving local state intact for safety."
            fi
        done
    else
        echo "Skipped remote deletion."
    fi
fi

echo ""
echo "Note: tutorial working directories live under /tmp/tos_tutorial_* and"
echo "      are reclaimed on reboot. Remove them now with:"
echo "      rm -rf /tmp/tos_tutorial_*"
echo ""

read -q "REPLY?Revoke the 'delete_repo' scope? (y/n) " || true
echo ""
if [[ "$REPLY" == [yY] ]]; then
    gh auth refresh -h github.com --remove-scopes delete_repo
    echo "✅ Permissions reset."
fi
