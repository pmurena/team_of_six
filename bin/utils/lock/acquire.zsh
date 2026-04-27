#!/bin/zsh
# ==============================================================================
# Title: Lock Acquire
# Usage: acquire.zsh <project> <trinity_id> [architect]
#
# Acquires a persistent session lock in the global control plane.
# - Trinity 0 = SOFT_LOCK (shared baseline, read-only for code)
# - Trinity N = HARD_LOCK (exclusive write access per Architect)
#
# The architect argument defaults to $SUDO_USER when invoked via the gateway.
# Tests may pass an explicit architect name as the third argument.
# ==============================================================================

PROJECT="$1"
TRINITY_ID="$2"
ARCHITECT="${3:-${SUDO_USER}}"

if [[ -z "$PROJECT" || -z "$TRINITY_ID" || -z "$ARCHITECT" ]]; then
    echo "🚨 [ERROR] acquire.zsh: Missing arguments. Usage: acquire.zsh <project> <trinity_id> [architect]" >&2
    exit 1
fi

GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
LOCK_FILE="${GLOBAL_LOCKS}/${PROJECT}_trinity_${TRINITY_ID}.lock"

if [[ "$TRINITY_ID" == "0" ]]; then
    LOCK_TYPE="SOFT_LOCK"
else
    LOCK_TYPE="HARD_LOCK"
    # Ensure no other Architect holds this specific trinity
    if [[ -f "$LOCK_FILE" ]] && ! grep -q "^${ARCHITECT}:" "$LOCK_FILE"; then
        echo "🚨 [ERROR] Hard Lock on trinity $TRINITY_ID is already locked by another Architect: $(<"$LOCK_FILE")" >&2
        exit 1
    fi
fi

# Clear all existing locks this Architect holds on this project
for file in "${GLOBAL_LOCKS}/${PROJECT}_trinity_"*.lock(N); do
    if [[ -f "$file" ]] && grep -q "^${ARCHITECT}:" "$file"; then
        rm -f "$file"
    fi
done

# Write the new lock to the control plane
echo "${ARCHITECT}:${LOCK_TYPE}" > "$LOCK_FILE"
echo "🔒 [${LOCK_TYPE}] Trinity $TRINITY_ID locked for $ARCHITECT"
