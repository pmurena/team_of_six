#!/bin/zsh
# ==============================================================================
# bin/utils/error_trap.zsh
# ==============================================================================
set -e

# Function to redact tokens from any string or stream
redact_tokens() {
    local input="${1:-$(cat)}"
    # Use parameter expansion to replace token values if they exist
    [[ -n "$GH_TOKEN" ]] && input="${input//"$GH_TOKEN"/"[REDACTED]"}"
    [[ -n "$GITHUB_TOKEN" ]] && input="${input//"$GITHUB_TOKEN"/"[REDACTED]"}"
    echo "$input"
}

catch_error() {
    local line=$1
    local code=$2
    # Capture trace, redact it, then pipe to stderr
    {
        echo "🚨 FATAL ERROR: Execution failed at line $line (Exit Code: $code)"
        echo "--- Stack Trace ---"
        print -l $funcfiletrace
    } | redact_tokens >&2
    exit $code
}

trap 'catch_error $LINENO $?' ZERR
