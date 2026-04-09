#!/bin/zsh
# ==============================================================================
# Title: Lock Release
# Usage: release.zsh <project>
#
# Releases all locks owned by this Architect for the given project.
# ==============================================================================

PROJECT=$1

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"

for file in "$GLOBAL_LOCKS/${PROJECT}_trinity_"*.lock(N); do
    if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
        rm -f "$file"
    fi
done
