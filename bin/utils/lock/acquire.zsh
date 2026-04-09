#!/bin/zsh
# ==============================================================================
# Title: Lock Acquire
# Usage: acquire.zsh <project> <trinity_id>
#
# Acquires a persistent session lock in the global control plane.
# - Trinity 0 = SOFT_LOCK (shared baseline, read-only for code)
# - Trinity N = HARD_LOCK (exclusive write access per Architect)
#
# The active trinity is derived by the gateway from the lock file directly —
# nothing is written to the sandbox. Zero proprietary pollution.
#
# NOTE: Hard-lock contention check is not atomic. Two Architects racing the
# exact same trinity acquisition simultaneously could both pass. This is an
# acknowledged limitation — in normal multi-user operation this window is
# negligible and flock complexity is not warranted here.
# ==============================================================================

PROJECT=$1
TRINITY_ID=$2

if [[ -z "$PROJECT" || -z "$TRINITY_ID" ]]; then
    echo "🚨 [ERROR] acquire.zsh: Missing arguments. Usage: acquire.zsh <project> <trinity_id>" >&2
    exit 1
fi

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"
LOCK_FILE="$GLOBAL_LOCKS/${PROJECT}_trinity_${TRINITY_ID}.lock"

if [[ "$TRINITY_ID" == "0" ]]; then
    LOCK_TYPE="SOFT_LOCK"
else
    LOCK_TYPE="HARD_LOCK"
    # Ensure no other Architect holds this specific trinity
    if [[ -f "$LOCK_FILE" ]] && ! grep -q "$SUDO_USER" "$LOCK_FILE"; then
        echo "🚨 [ERROR] Hard Lock on trinity $TRINITY_ID is held by another Architect: $(cat "$LOCK_FILE")" >&2
        exit 1
    fi
fi

# Clear all existing locks this Architect holds on this project
for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
    if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
        rm -f "$file"
    fi
done

# Write the new lock to the control plane
echo "$SUDO_USER:$LOCK_TYPE" > "$LOCK_FILE"
echo "🔒 [$LOCK_TYPE] Trinity $TRINITY_ID locked for $SUDO_USER"
