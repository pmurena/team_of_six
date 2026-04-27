#!/bin/zsh
# ==============================================================================
# Title: Lock Status
# Usage: status.zsh <project> [architect]
#
# Reports the active lock for the given project.
# If an architect is supplied, only shows locks owned by that architect.
# Exits 0 in all cases — "no lock" is not an error condition.
# ==============================================================================

PROJECT="$1"
ARCHITECT="${2:-}"

GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"

FOUND=0
for file in "${GLOBAL_LOCKS}/${PROJECT}_trinity_"*.lock(N); do
    [[ -f "$file" ]] || continue
    CONTENT="$(<"$file")"
    # If an architect filter is set, skip locks owned by others
    if [[ -n "$ARCHITECT" ]] && ! grep -q "^${ARCHITECT}:" "$file"; then
        continue
    fi
    TRINITY=$(basename "$file" | sed -n 's/.*_trinity_\([0-9]*\)\.lock/\1/p')
    LOCK_TYPE=$(echo "$CONTENT" | cut -d: -f2)
    echo "${LOCK_TYPE} on trinity ${TRINITY}"
    FOUND=1
done

if [[ "$FOUND" -eq 0 ]]; then
    echo "no active lock for project '${PROJECT}'"
fi
