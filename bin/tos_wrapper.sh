#!/bin/zsh
# Team of Six - Wrapper V62.5 (Thin Client)
set -o pipefail

if [ -z "$TOS_CONF" ]; then
    echo "⛔ ERROR: TOS_CONF not set. Wrapper must be executed via tos_controller.sh"
    exit 1
fi

INPUT_ABS="$TOS_CONF/tos_input.sh"
LOG_ABS="$TOS_CONF/tos_output.log"

mkdir -p "$TOS_OUTBOX"

if [ -n "$(find "$TOS_OUTBOX" -mindepth 2 -maxdepth 2 -type d -print -quit 2>/dev/null)" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished payloads detected in $TOS_OUTBOX"
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    export TOS_SANDBOX="$TOS_SANDBOX"
    export TOS_OUTBOX="$TOS_OUTBOX"
    
    cd "$TOS_SANDBOX" || exit 1
    if [ -s "$INPUT_ABS" ]; then
        source "$INPUT_ABS"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$INPUT_ABS"
exit $EXIT_CODE
