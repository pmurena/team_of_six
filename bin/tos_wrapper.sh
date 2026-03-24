#!/bin/zsh
source "$TOS_MNT_ROOT/.local/conf/error_trap.sh"

{
    echo "⚡ TASK INPUT STARTED"
    
    # [FIXED] Mutex strictly looks for 'branch' files (code payloads). Allows non-code payloads to stack.
    if [ -n "$(find "$TOS_OUTBOX" -type f -name "branch" -print -quit 2>/dev/null)" ]; then
        echo "⛔ EXECUTION BLOCKED: Pending code payloads (branch) found in $TOS_OUTBOX."
        exit 1
    fi

    cat "$TOS_INPUT"

    # [TODO] find a solution to be able to cd into the project folder to avoid context pollution on error.
    cd "$TOS_SANDBOX" || exit 1
    source "$TOS_INPUT"
    
    EXIT_CODE=$?
    echo "🏁 TASK FINISHED WITH EXIT CODE: $EXIT_CODE"

} 2>&1 | logger -t tos_ghost

[ ${EXIT_CODE:-0} -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit ${EXIT_CODE:-0}
