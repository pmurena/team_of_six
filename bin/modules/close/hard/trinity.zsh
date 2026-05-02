#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

# HITL Gate (ADR 12)
grep -q "CONFIRM=TRUE" "$TOS_INPUT" || { echo "🚨 [ERROR] Safety gate: CONFIRM=TRUE required." >&2; exit 1; }

truncate -s 0 "$TOS_INPUT"
gh pr merge "tos-work-$TOS_ACTIVE_TRINITY" --squash --delete-branch
"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT"
echo "🏁 Trinity #$TOS_ACTIVE_TRINITY closed."
gh issue close "$TOS_ACTIVE_TRINITY" -r "completed" 2>/dev/null || true
