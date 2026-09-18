#!/bin/zsh
PROJECT_NAME="$1"
PURGE="false"
[[ "$2" == "--purge" ]] && PURGE="true"
GLOBAL_LOCKS="${TOS_LOCKS:-$TOS_MNT_ROOT/.ipc/locks}"
LOCK_FOUND=false

# The (N) qualifier tells zsh not to crash if no files are found
for file in "$GLOBAL_LOCKS/${PROJECT_NAME}_trinity_"*.lock(N); do
    [[ -f "$file" ]] || continue
    LOCK_FOUND=true
    if grep -q "^${SUDO_USER}:" "$file"; then
        # A lock is a CLAIM on a Trinity. The manifest visa and the phase record are
        # properties of the Trinity itself, and they outlive any particular claim.
        #
        # sync trinity releases and re-acquires during the Atomic Handover. When
        # this deleted all three, every sync destroyed the Intent Lock and the
        # phase record of a Trinity that was still very much open.
        #
        # --purge is for the two commands that genuinely end a Trinity:
        # write trinity (merged) and close trinity (abandoned).
        if [[ "$PURGE" == "true" ]]; then
            rm -f "$file" "${file%.lock}.manifest" "${file%.lock}.phase"
        else
            rm -f "$file"
        fi
        echo "🔓 Lock released for $PROJECT_NAME."
        exit 0
    else
        echo "🚨 [ERROR] Cannot release lock owned by another architect." >&2
        exit 1
    fi
done

[[ "$LOCK_FOUND" == "false" ]] && exit 0
