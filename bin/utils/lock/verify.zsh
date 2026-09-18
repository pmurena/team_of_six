#!/bin/zsh
# ==============================================================================
# Title: Lock Verify
# Usage: verify.zsh <project> <trinity_id> [architect] [expected_lock_type]
#
# Exits 0 if the lock file exists, is owned by the given architect, and
# (if supplied) matches the expected lock type. Exits 1 otherwise.
#
# When invoked via the gateway, architect defaults to $SUDO_USER.
# Tests pass explicit values for both architect and expected type.
# ==============================================================================

PROJECT="$1"
TRINITY_ID="$2"
ARCHITECT="${3:-${SUDO_USER}}"
EXPECTED_TYPE="${4:-}"    # optional: SOFT_LOCK or HARD_LOCK

GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
LOCK_FILE="${GLOBAL_LOCKS}/${PROJECT}_trinity_${TRINITY_ID}.lock"

# Lock file must exist
if [[ ! -f "$LOCK_FILE" ]]; then
    echo "🚨 [VERIFY FAIL] No lock file for ${PROJECT} trinity ${TRINITY_ID}." >&2
    exit 1
fi

# Architect must match
if ! grep -q "^${ARCHITECT}:" "$LOCK_FILE"; then
    OWNER=$(cut -d: -f1 "$LOCK_FILE")
    echo "🚨 [VERIFY FAIL] Lock owned by '${OWNER}', not '${ARCHITECT}'." >&2
    exit 1
fi

# Lock type must match (if specified)
if [[ -n "$EXPECTED_TYPE" ]]; then
    ACTUAL_TYPE=$(cut -d: -f2 "$LOCK_FILE")
    if [[ "$ACTUAL_TYPE" != "$EXPECTED_TYPE" ]]; then
        echo "🚨 [VERIFY FAIL] Lock type is '${ACTUAL_TYPE}', expected '${EXPECTED_TYPE}'." >&2
        exit 1
    fi
fi

exit 0
