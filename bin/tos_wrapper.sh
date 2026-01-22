#!/bin/zsh
# Team of Six - Wrapper V56 (Engine Only)
set -o pipefail

HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⛔ ERROR: .tos/ context missing."
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

# Execute logic as AI_USER (Air-Gapped)
sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    cd "$TARGET_DIR" || exit 1
    if [ -s "$INPUT_ABS" ]; then
        source "$INPUT_ABS"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$INPUT_ABS"
exit $EXIT_CODE
