#!/bin/zsh
# Team of Six - Wrapper V63 (XDG Native)
set -o pipefail

if [ -z "$TOS_CONF" ]; then
    echo "⛔ ERROR: TOS_CONF not set. Wrapper must be executed via tos_controller.sh"
    exit 1
fi

mkdir -p "$TOS_OUTBOX"

if [ -n "$(find "$TOS_OUTBOX" -mindepth 2 -maxdepth 2 -type d -print -quit 2>/dev/null)" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished payloads detected in $TOS_OUTBOX"
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$TOS_LOG"
cat "$TOS_INPUT" >> "$TOS_LOG"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$TOS_LOG" 2>&1
    export TOS_SANDBOX="$TOS_SANDBOX"
    export TOS_OUTBOX="$TOS_OUTBOX"
    
    cd "$TOS_SANDBOX" || exit 1
    if [ -s "$TOS_INPUT" ]; then
        source "$TOS_INPUT"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit $EXIT_CODE
