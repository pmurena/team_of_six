#!/bin/zsh
# ==============================================================================
# Title: Multi-Tenant Lock Manager
# Usage: lock_manager.sh <acquire|release|verify> <project> [trinity_id]
#
# Manages persistent session locks in the global control plane.
# - Trinity 0 = SOFT_LOCK (Shared access, read-only baseline)
# - Trinity X = HARD_LOCK (Exclusive write access per Architect)
# ==============================================================================

ACTION=$1
PROJECT=$2
TRINITY_ID=$3

# Use the GLOBAL locks directory provisioned by tos_deploy.sh
GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"
LOCK_FILE="$GLOBAL_LOCKS/${PROJECT}_trinity_${TRINITY_ID}.lock"

case "$ACTION" in
    acquire)
        if [[ "$TRINITY_ID" == "0" ]]; then
            LOCK_TYPE="SOFT_LOCK"
        else
            LOCK_TYPE="HARD_LOCK"
            # Ensure no one else holds this specific hard lock globally
            if [[ -f "$LOCK_FILE" ]] && ! grep -q "$SUDO_USER" "$LOCK_FILE"; then
                echo "[ERROR] Hard Lock held by another Architect: $(cat "$LOCK_FILE")"
                exit 1
            fi
        fi
        
        # Clear any existing locks for THIS Architect on THIS project globally
        for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
            if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
                rm -f "$file"
            fi
        done
        
        # Create the new lock mapping the Architect to the Lock Type
        echo "$SUDO_USER:$LOCK_TYPE" > "$LOCK_FILE"
        ;;
        
    release)
        # Release only locks owned by this specific Architect for this project
        for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
            if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
                rm -f "$file"
            fi
        done
        ;;
        
    verify)
        if [[ ! -f "$LOCK_FILE" ]]; then
            exit 1
        fi
        # Verify the current Architect owns this lock
        grep -q "$SUDO_USER" "$LOCK_FILE"
        ;;
        
    *)
        echo "Usage: lock_manager.sh <acquire|release|verify> <project> [trinity_id]"
        exit 1
        ;;
esac
