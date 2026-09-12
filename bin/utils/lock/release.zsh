#!/bin/zsh
PROJECT_NAME="$1"
GLOBAL_LOCKS="${TOS_LOCKS:-$TOS_MNT_ROOT/.ipc/locks}"
LOCK_FOUND=false

# The (N) qualifier tells zsh not to crash if no files are found
for file in "$GLOBAL_LOCKS/${PROJECT_NAME}_trinity_"*.lock(N); do
    [[ -f "$file" ]] || continue
    LOCK_FOUND=true
    if grep -q "^${SUDO_USER}:" "$file"; then
        rm -f "$file" "${file%.lock}.manifest" "${file%.lock}.phase"
        echo "🔓 Lock released for $PROJECT_NAME."
        exit 0
    else
        echo "🚨 [ERROR] Cannot release lock owned by another architect." >&2
        exit 1
    fi
done

[[ "$LOCK_FOUND" == "false" ]] && exit 0
