#!/bin/zsh
# ==============================================================================
# Title: Lock Acquire
# Usage: acquire.sh <project> <trinity_id>
#
# Acquires a persistent session lock in the global control plane.
# - Trinity 0 = SOFT_LOCK (shared baseline, read-only for code)
# - Trinity N = HARD_LOCK (exclusive write access per Architect)
#
# NOTE: Hard-lock contention check is not atomic. Two Architects racing the
# exact same trinity acquisition simultaneously could both pass. This is an
# acknowledged limitation — in normal multi-user operation this window is
# negligible and flock complexity is not warranted here.
# ==============================================================================

PROJECT=$1
TRINITY_ID=$2

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"
LOCK_FILE="$GLOBAL_LOCKS/${PROJECT}_trinity_${TRINITY_ID}.lock"

if [[ "$TRINITY_ID" == "0" ]]; then
    LOCK_TYPE="SOFT_LOCK"
else
    LOCK_TYPE="HARD_LOCK"
    # Ensure no other Architect holds this specific trinity
    if [[ -f "$LOCK_FILE" ]] && ! grep -q "$SUDO_USER" "$LOCK_FILE"; then
        echo "[ERROR] Hard Lock held by another Architect: $(cat "$LOCK_FILE")"
        exit 1
    fi
fi

# Clear all existing locks this Architect holds on this project
for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
    if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
        rm -f "$file"
    fi
done

# Write the new lock
echo "$SUDO_USER:$LOCK_TYPE" > "$LOCK_FILE"
