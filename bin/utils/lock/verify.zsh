#!/bin/zsh
# ==============================================================================
# Title: Lock Verify
# Usage: verify.zsh <project> <trinity_id>
#
# Exits 0 if this Architect owns the lock for the given project and trinity.
# Exits 1 otherwise.
# ==============================================================================

PROJECT=$1
TRINITY_ID=$2

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"
LOCK_FILE="$GLOBAL_LOCKS/${PROJECT}_trinity_${TRINITY_ID}.lock"

[[ ! -f "$LOCK_FILE" ]] && exit 1
grep -q "$SUDO_USER" "$LOCK_FILE"
