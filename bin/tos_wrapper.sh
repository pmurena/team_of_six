#!/bin/zsh
set -o pipefail
HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

# [VARIABLE ISOLATION] Clear any existing token before loading authorized one
unset GITHUB_TOKEN
source "$TOS_DIR/.token" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⛔ SAFETY BLOCK: No .tos/ folder detected."
    exit 1
fi

if [ "$(stat -c '%U' "$TARGET_DIR")" != "$AI_USER" ]; then
    sudo chown -R "$AI_USER:$AI_GROUP" "$TARGET_DIR"
    sudo chmod -R 775 "$TARGET_DIR"
fi

echo "# --- ⚡ TASK INPUT ---" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    # 1. Identity & Auth (Local to avoid pollution)
    export GITHUB_TOKEN='$GITHUB_TOKEN'
    cd "$TARGET_DIR"
    git config --local url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
    git config --local user.email "agent@teamofsix.bot"
    git config --local user.name "Team of Six (V56)"
    
    # 2. Sandbox Setup (Post-Sourcing Fix)
    export HOME=/tmp/tos_sandbox_$(date +%s)
    mkdir -p \$HOME
    
    # 3. Execution (Using Absolute Host Path)
    if [ -f "$INPUT_ABS" ]; then
        source "$INPUT_ABS"
    fi
SANDBOX

[ $? -eq 0 ] && truncate -s 0 "$INPUT_ABS"
