#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

NEW_TRINITY="$2"

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

echo "🔄 Syncing Trinity..."

# --- BUG FIX: Only push if we are syncing from an active Trinity (ID > 0) ---
if [[ -n "$TOS_ACTIVE_TRINITY" && "$TOS_ACTIVE_TRINITY" -gt 0 ]]; then
    git push origin "tos-work-$TOS_ACTIVE_TRINITY" || {
        echo "🚨 FATAL: Push failed. Halting sync." >&2
        exit 1
    }
else
    echo "⏭️ Project Soft Lock detected (Trinity 0). Skipping push."
fi
# ----------------------------------------------------------------------------

"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT" >/dev/null 2>&1
"$TOS_BIN/utils/lock/acquire.zsh" "$TOS_ACTIVE_PROJECT" "$NEW_TRINITY" "$SUDO_USER" >/dev/null 2>&1

echo "✅ Sync complete. Handed over to trinity $NEW_TRINITY."

# --- [TOS 1.0 PATCH] CLEAN ROOM SNAPSHOT ---
echo ""
echo "=== SYSTEM SNAPSHOT ==="
echo "TARGET_PROJECT=$TOS_ACTIVE_PROJECT"
echo "TARGET_TRINITY=$NEW_TRINITY"
echo "--- Branch Status ---"
git status -s
echo "--- Recent Commits ---"
git log --oneline -5
