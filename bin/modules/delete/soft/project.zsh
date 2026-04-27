#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

# HITL Gate (ADR 12)
grep -q "CONFIRM=TRUE" "$TOS_INPUT" || { echo "🚨 [ERROR] Safety gate: CONFIRM=TRUE required." >&2; exit 1; }

# PAT MFA Isolation (ADR 13)
trap 'gh auth refresh --remove-scopes delete_repo >/dev/null 2>&1' EXIT
gh auth refresh -s delete_repo

truncate -s 0 "$TOS_INPUT"
gh repo delete "$TOS_ACTIVE_PROJECT" --yes
rm -rf "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT"
echo "☢️  Project $TOS_ACTIVE_PROJECT purged."
