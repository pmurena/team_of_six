#!/bin/zsh

# --- 0. Load Global Error Trapping ---
if [[ -f "$TOS_CONF/error_trap.sh" ]]; then
    source "$TOS_CONF/error_trap.sh"
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: tos <project> peek <file1> [file2...]"
    exit 1
fi

# Ensure we are in the right directory
cd "$TOS_WORKING_DIR" || {
    echo "❌ Error: Could not cd into $TOS_WORKING_DIR"
    exit 1
}

# Use OVERWRITE (>) instead of append.
# The Neovim Chat Buffer handles the persistent history.
# The Outbox is strictly a transient transfer medium.
{
    echo "## SURGICAL CONTEXT INJECTION (PEEK)"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "The Architect has provided the following implementation details:"

    for req_file in "$@"; do
        if [[ -f "$req_file" ]]; then
            logger -t tos_ghost -p user.info "Peeking into file: $req_file"
            echo -e "\n### File: \`$req_file\`"
            # Using Unicode escapes for backticks to remain UI-safe
            echo '\u0060\u0060\u0060'
            cat "$req_file"
            echo '\u0060\u0060\u0060'
        else
            logger -t tos_ghost -p user.warn "Peek failed: $req_file not found."
            echo "⚠️ Warning: Requested file $req_file not found."
        fi
    done
} > "$TOS_CONTEXT"

echo "✅ Surgical context staged at $TOS_CONTEXT"
