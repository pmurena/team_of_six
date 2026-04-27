#!/bin/zsh
# ==============================================================================
# Title: Manifest Visa Check
# Usage: check_manifest_visa.zsh <file_path> <project> <trinity_id>
#
# Verifies that <file_path> is authorised by the .manifest visa created by
# `write plan` for the given project+trinity slot.
#
# Returns 0 if the file is on the approved list.
# Returns 1 (SEC-FAULT) if:
#   - the path contains ".." (traversal attempt)
#   - the path is absolute (starts with /)
#   - no manifest file exists
#   - the file is not on the approved list
# ==============================================================================

FILE_PATH="$1"
PROJECT="$2"
TRINITY_ID="$3"

if [[ -z "$FILE_PATH" || -z "$PROJECT" || -z "$TRINITY_ID" ]]; then
    echo "🚨 SEC-FAULT: check_manifest_visa.zsh: Missing arguments." >&2
    exit 1
fi

# Reject path traversal unconditionally — before any filesystem access
if [[ "$FILE_PATH" == *..* ]]; then
    echo "🚨 SEC-FAULT: Path traversal detected in '${FILE_PATH}'. Rejected." >&2
    exit 1
fi

# Reject absolute paths
if [[ "$FILE_PATH" == /* ]]; then
    echo "🚨 SEC-FAULT: Absolute path '${FILE_PATH}' rejected. Sandbox paths must be relative." >&2
    exit 1
fi

GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
MANIFEST_FILE="${GLOBAL_LOCKS}/${PROJECT}_trinity_${TRINITY_ID}.manifest"

# No manifest means write plan was never run — block entirely
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "🚨 SEC-FAULT: No manifest visa found for ${PROJECT} trinity ${TRINITY_ID}." >&2
    echo "    Run: tos ${PROJECT} write plan   to establish an intent lock first." >&2
    exit 1
fi

# Check the file against the space-separated approved list
APPROVED="$(<"$MANIFEST_FILE")"
for approved_file in ${(z)APPROVED}; do
    if [[ "$approved_file" == "$FILE_PATH" ]]; then
        exit 0
    fi
done

echo "🚨 SEC-FAULT: '${FILE_PATH}' is not authorised by the manifest visa for ${PROJECT} trinity ${TRINITY_ID}." >&2
echo "    Approved files: ${APPROVED}" >&2
exit 1
