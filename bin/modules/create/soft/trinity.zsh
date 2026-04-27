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
gh pr create --draft --title "Trinity #$TRINITY_ID" --body "Fixes #$TRINITY_ID" --base main --head "tos-work-$TRINITY_ID"
