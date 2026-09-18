#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

# HITL Gate (ADR 12)
grep -q "CONFIRM=TRUE" "$TOS_INPUT" || { echo "🚨 [ERROR] Safety gate: CONFIRM=TRUE required." >&2; exit 1; }

if [[ "$TOS_ACTIVE_TRINITY" != "0" ]]; then
    echo "🚨 [ERROR] Cannot close project while a hard lock is active." >&2
    exit 1
fi

truncate -s 0 "$TOS_INPUT"
rm -rf "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT"
echo "🏁 Project $TOS_ACTIVE_PROJECT closed (local sandbox removed)."
