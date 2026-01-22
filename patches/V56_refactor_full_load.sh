#!/bin/bash
# Patch Name: V56 Refactor (Full Load - Ghost Protocol Final)
# Location: patches/v56_refactor_full_load.sh
# Purpose: Decouple execution, sandbox publication, enforce AI ownership, and remove sudoers tunnel.

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$PATCH_DIR/../bin" && pwd)"
BASE_DIR="$(cd "$PATCH_DIR/.." && pwd)"

echo "🏗️ Applying V56 Refactor (Ghost Protocol)..."

# --- 1. OVERWRITE: bin/tos_wrapper.sh (The Engine) ---
cat << 'EOF' > "$BIN_DIR/tos_wrapper.sh"
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
EOF

# --- 2. OVERWRITE: bin/tos_publish.sh (Sandboxed Governor) ---
cat << 'EOF' > "$BIN_DIR/tos_publish.sh"
#!/bin/zsh
# Team of Six - Publisher V56 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"
STATE_FILE="$TARGET_DIR/.tos/state"

CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "Unknown")
if [[ "$CURRENT_STATE" == "Red" || "$CURRENT_STATE" == "Requirement" ]]; then
    echo "⛔ GOVERNANCE VETO: Cannot publish in state [$CURRENT_STATE]"
    exit 1
fi

echo "🚀 Governor: Initiating Sandboxed Publication..."

# [FIXED] Git operations sandboxed under AI_USER
sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"
    
    # Git Auth & Identity
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    if [ ! -d ".git" ]; then
        git init -b main
        git add .
        git commit -m "scaff: project genesis"
        REPO_NAME=\$(basename "\$(pwd)")
        gh repo create "\$REPO_NAME" --private --source=. --remote=origin --push
    else
        BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
        git checkout -b "\$BRANCH_NAME"
        git add .
        if ! git diff --cached --quiet; then
            git commit -m "feat: updates for state [$CURRENT_STATE]"
            git push origin "\$BRANCH_NAME"
            gh pr create --title "tos: \$BRANCH_NAME" --body "Automated release from state $CURRENT_STATE" --fill
        fi
    fi
SANDBOX

echo "✅ Publication Complete."
EOF

# --- 3. OVERWRITE: bin/tos_installer.sh (Corrected Ownership & Removed Tunnel) ---
cat << 'EOF' > "$BIN_DIR/tos_installer.sh"
#!/bin/zsh
# V56 Deployment Script - Permission Wiring
set -e

AI_USER="team_of_six"
GROUP="team_of_six"
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
REAL_USER=$(whoami)

sudo -v
if ! getent group "$GROUP" >/dev/null; then sudo groupadd "$GROUP"; fi
if ! id "$AI_USER" &>/dev/null; then sudo useradd -r -g "$GROUP" -s /bin/zsh "$AI_USER"; fi
sudo usermod -a -G "$GROUP" "$REAL_USER"

echo "📂 [SUDO] Wiring Permissions..."
# Repo belongs to Ghost ($AI_USER)
sudo chown -R "$AI_USER:$GROUP" "$REPO_ROOT"
sudo chmod -R 775 "$REPO_ROOT"
# Config belongs to Architect ($REAL_USER)
sudo chown -R "$REAL_USER:$GROUP" "$HOME/.team_of_six"
sudo chmod -R 775 "$HOME/.team_of_six"

# [FIXED] Sudoers Tunnel removed (System Ghost Principle)

echo "✅ Installation Complete."
EOF

# --- 4. CREATE: bin/tos_project_creator.sh (For 'new' command) ---
cat << 'EOF' > "$BIN_DIR/tos_project_creator.sh"
#!/bin/zsh
# Team of Six - Project Creator
set -e
PROJECT_NAME=$1
[ -z "$PROJECT_NAME" ] && exit 1
TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"

mkdir -p "$PROJECT_NAME/.tos"
echo "Scaffolding" > "$PROJECT_NAME/.tos/state"
touch "$PROJECT_NAME/.tos/objections.md"

# Backlog
cat <<BACKLOG > "$PROJECT_NAME/.tos/features.md"
# 📋 Project Backlog: $PROJECT_NAME
* [ ] Initial Architecture (Current)
BACKLOG

# Enforce Ghost Ownership
sudo chown -R "$AI_USER:$AI_GROUP" "$PROJECT_NAME"
sudo chmod -R 775 "$PROJECT_NAME"
echo "✅ Project '$PROJECT_NAME' initialized."
EOF

# --- 5. UPDATE: tos_controller.sh (Inject 'new' command) ---
echo "⚙️  Updating Controller Dispatcher..."
if ! grep -q "new)" "$BASE_DIR/tos_controller.sh"; then
    # Insert 'new' command before the wildcard default case
    sed -i '/install)/i \    new)\n        exec "$BIN_DIR/tos_project_creator.sh" "$@"\n        ;;' "$BASE_DIR/tos_controller.sh"
fi

chmod +x "$BIN_DIR"/*.sh
echo "🚀 V56 Ghost Protocol Applied Successfully."
