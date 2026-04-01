#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"
shift

[[ $# -eq 0 ]] && { echo "Usage: tos <project> work peek <files...>"; exit 1; }

cd "$TOS_WORKING_DIR" || exit 1

# Ensure we are actually on a Ghost workspace branch before peeking
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ ! "$CURRENT_BRANCH" =~ ^tos-work- ]] && { echo "🚨 ERROR: Not on a tos-work branch. Run 'work <ID>' first."; exit 1; }

{
    echo "\n## SURGICAL CONTEXT INJECTION (PEEK)"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    for req_file in "$@"; do
        if [[ -f "$req_file" ]]; then
            echo -e "\n### File: \`$req_file\`\n\`\`\`"
            cat "$req_file"
            echo "\`\`\`"
        else
            echo "⚠️ Warning: Requested file $req_file not found."
        fi
    done
} >> "$TOS_CONTEXT"

echo "✅ Surgical context added to $TOS_CONTEXT"
