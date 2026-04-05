#!/bin/zsh
# ==============================================================================
# Title: The Global Lock Manager
#
# Usage: lock_manager.sh <acquire|check|release> <project> <trinity_id>
#
# Provides safe, file-based locking scoped to a specific project:trinity pair.
# The lock file is created under $TOS_LOCKS/ and contains the locking user's
# name so the engine can report who holds the lock on contention.
# ==============================================================================

ACTION="$1"
PROJECT="$2"
TRINITY_ID="$3"

[[ -z "$ACTION" || -z "$PROJECT" || -z "$TRINITY_ID" ]] && {
    echo "🚨 ERROR: lock_manager requires <acquire|check|release> <project> <trinity_id>" >&2
    exit 1
}

LOCK_FILE="$TOS_LOCKS/${PROJECT}_trinity_${TRINITY_ID}.lock"

case "$ACTION" in
    acquire)
        # Reject if any lock for this project already exists (serialise per project)
        EXISTING=$(ls "$TOS_LOCKS/${PROJECT}_trinity_"*.lock 2>/dev/null | head -1)
        if [[ -n "$EXISTING" ]]; then
            HOLDER=$(cat "$EXISTING" 2>/dev/null || echo "unknown")
            LOCKED_TRINITY=$(basename "$EXISTING" | sed 's/.*_trinity_//;s/\.lock//')
            echo "⏳ Engine is busy. Trinity #${LOCKED_TRINITY} is currently locked by: ${HOLDER}." >&2
            exit 1
        fi

        mkdir -p "$TOS_LOCKS"
        echo "$SUDO_USER" > "$LOCK_FILE"
        ;;

    check)
        if [[ -f "$LOCK_FILE" ]]; then
            cat "$LOCK_FILE"
            exit 0
        fi
        exit 1
        ;;

    verify)
        # Assert that the lock exists AND is owned by the current user.
        # Used by the gateway before dispatching any write command.
        if [[ ! -f "$LOCK_FILE" ]]; then
            echo "🚨 No active lock for Trinity #${TRINITY_ID} in project '${PROJECT}'. Run 'sync trinity ${TRINITY_ID}' first." >&2
            exit 1
        fi
        HOLDER=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ "$HOLDER" != "$SUDO_USER" ]]; then
            echo "🚨 Lock for Trinity #${TRINITY_ID} is held by '${HOLDER}', not '${SUDO_USER}'. Cannot write." >&2
            exit 1
        fi
        # Lock is valid and owned by us — silently succeed
        exit 0
        ;;

    release)
        rm -f "$LOCK_FILE"
        ;;

    *)
        echo "🚨 ERROR: Unknown lock action '$ACTION'" >&2
        exit 1
        ;;
esac
