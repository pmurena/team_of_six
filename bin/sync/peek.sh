#!/bin/zsh
# ==============================================================================
# Title: Surgical Context Injector
# Usage: tos <project> sync peek <files...>
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"
shift

[[ $# -eq 0 ]] && { echo "Usage: tos <project> sync peek <files...>"; exit 1; }

cd "$TOS_SANDBOX/$PROJECT_NAME" || exit 1

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ ! "$CURRENT_BRANCH" =~ ^tos-work- ]] && {
    echo "🚨 ERROR: Not on a tos-work branch. Run 'sync trinity <ID>' first."
    exit 1
}

echo -e "\n---"
echo "## SURGICAL CONTEXT INJECTION (PEEK)"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "> Note: This context is appended. Run 'sync trinity <ID>' to clean and reset."

for req_file in "$@"; do
	if [[ -f "$req_file" ]]; then
		echo -e "\n### File: \`$req_file\`\n\`\`\`"
		cat "$req_file"
		echo "\`\`\`"
	else
		echo "⚠️ Warning: Requested file $req_file not found."
	fi
done
