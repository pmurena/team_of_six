#!/bin/zsh
# ==============================================================================
# Title: Lock Status
# Usage: status.zsh <project>
#
# Prints all active locks for the given project across all Architects.
# ==============================================================================

PROJECT=$1

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"

FOUND=0
for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
    if [[ -f "$file" ]]; then
        TRINITY=$(basename "$file" | sed -n 's/.*_trinity_\([0-9]*\)\.lock/\1/p')
        CONTENT=$(cat "$file")
        echo "Trinity $TRINITY: $CONTENT"
        FOUND=1
    fi
done

[[ "$FOUND" -eq 0 ]] && echo "[UNLOCKED] No active locks for project '$PROJECT'."
