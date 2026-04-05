#!/bin/zsh
set -e
trap 'catch_error $LINENO $?' ZERR

catch_error() {
    local line=$1
    local code=$2
    echo "🚨 FATAL ERROR: Execution failed at line $line (Exit Code: $code)" >&2
    echo "--- Stack Trace ---" >&2
    print -l $funcfiletrace >&2
    exit $code
}
