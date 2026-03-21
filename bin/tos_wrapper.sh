#!/bin/zsh
# Team of Six - Wrapper V64 (Logic Only)
# Identity and CD are pre-managed by the Controller.

[ -z "$TOS_OUTBOX" ] && exit 1

# Mutex Check
if [ -n "$(find "$TOS_OUTBOX" -mindepth 2 -maxdepth 2 -type d -print -quit)" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished payloads in $TOS_OUTBOX"
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$TOS_LOG"
[ -s "$TOS_INPUT" ] && cat "$TOS_INPUT" >> "$TOS_LOG"
[ -s "$TOS_INPUT" ] && source "$TOS_INPUT"

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit $EXIT_CODE
