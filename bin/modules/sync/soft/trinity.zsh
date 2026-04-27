#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

NEW_TRINITY="$1"
cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

echo "🔄 Syncing Trinity..."
git push origin "tos-work-$TOS_ACTIVE_TRINITY" || {
    echo "🚨 FATAL: Push failed. Halting sync." >&2
    exit 1
}

"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT" >/dev/null 2>&1
# FIX: Correct argument ordering to match <project> <trinity_id> <architect>
"$TOS_BIN/utils/lock/acquire.zsh" "$TOS_ACTIVE_PROJECT" "$NEW_TRINITY" "$SUDO_USER" >/dev/null 2>&1

echo "✅ Sync complete. Handed over to trinity $NEW_TRINITY."
