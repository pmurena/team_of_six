#!/bin/zsh
source "$TOS_MNT_ROOT/.local/conf/error_trap.sh"

# --- 1. UX & Dependency Check ---
if [ ! -s "$TOS_INPUT" ]; then
    touch "$TOS_INPUT"
    chmod 660 "$TOS_INPUT"
    echo "⚠️  Awaiting Instructions."
    echo "Please write your execution script to: $TOS_INPUT"
    echo "Then re-run this command."
    exit 1
fi

# --- 2. Mutex Lock Check ---
if [ -n "$(find "$TOS_OUTBOX" -type f -name "branch" -print -quit 2>/dev/null)" ]; then
    echo "⛔ EXECUTION BLOCKED: Pending code payloads (branch) found in $TOS_OUTBOX."
    exit 1
fi

# --- 3. Execution ---
{
    echo "⚡ TASK INPUT STARTED"
    cat "$TOS_INPUT"

    # V70: Contextual Drop-in
    mkdir -p "$TOS_WORKING_DIR"
    cd "$TOS_WORKING_DIR" || exit 1
    
    source "$TOS_INPUT"
    
    EXIT_CODE=$?
    echo "🏁 TASK FINISHED WITH EXIT CODE: $EXIT_CODE"

} 2>&1 | logger -t tos_ghost

# Clear the input file on success
[ ${EXIT_CODE:-0} -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit ${EXIT_CODE:-0}
