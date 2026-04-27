#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

echo "⚡ PARSING PLAN"
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "PLAN" "$TOS_PARSE_DIR" "APPROVED_FILES"

# ADR 10: Truncate immediately after parsing
truncate -s 0 "$TOS_INPUT"

MANIFEST=$(cat "$TOS_PARSE_DIR/1/APPROVED_FILES.txt" 2>/dev/null)
if [[ -z "$MANIFEST" ]]; then
    echo "🚨 [ERROR] write plan: Missing APPROVED_FILES." >&2
    exit 1
fi

# Write the visa file to the control plane
echo "$MANIFEST" > "${TOS_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TOS_ACTIVE_TRINITY}.manifest"
echo "✅ Intent Lock established. Manifest visa issued."
