#!/bin/bash
# Team of Six: V56 Migration Patcher (Hardened Final)
# Architecture: Service Account Model (Isolated)
# Fixes: Home Paradox, Git Config Pollution, and Variable Shadowing.

set -e

# Ensure we are in the repo root
if [ ! -d "bin" ] || [ ! -f "tos_controller.sh" ]; then
    echo "❌ Error: You must run this script from the 'team_of_six' repository root."
    exit 1
fi

echo "🚀 Applying V56 Hardened Patch..."

# --- 1. Cleanup Script ---
# Purges V55 artifacts while preserving project data.
echo "📝 Writing bin/cleanup_v55.sh..."
cat << 'EOF' > bin/cleanup_v55.sh
#!/bin/zsh
set -e
echo "🧹 Purging V55 System Artifacts..."
[ -f /etc/sudoers.d/team_of_six ] && sudo rm /etc/sudoers.d/team_of_six
rm -rf "$HOME/.team_of_six"
rm -f "$HOME/.local/bin/team_of_six"
id "team_of_six" &>/dev/null && sudo userdel team_of_six
getent group team_of_six &>/dev/null && sudo groupdel team_of_six
echo "✅ Purge Complete."
EOF

# --- 2. Installer ---
# Sets up the restricted service account.
echo "📝 Updating bin/tos_installer.sh..."
cat << 'EOF' > bin/tos_installer.sh
#!/bin/zsh
set -e
AI_USER="team_of_six"
GROUP="team_of_six"
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
echo "🔧 Installing V56 (Hardened)..."
sudo -v
getent group "$GROUP" >/dev/null || sudo groupadd "$GROUP"
id "$AI_USER" &>/dev/null || sudo useradd -r -g "$GROUP" -s /usr/sbin/nologin "$AI_USER"
sudo usermod -a -G "$GROUP" "$(whoami)"
TOS_HOME="$HOME/.team_of_six"
mkdir -p "$TOS_HOME"
if [ ! -f "$TOS_HOME/.token" ]; then
    echo -n "🔑 Paste GitHub Token: "
    read -s UT
    echo "export GITHUB_TOKEN='$UT'" > "$TOS_HOME/.token"
    chmod 600 "$TOS_HOME/.token"
fi
ln -sf "$REPO_ROOT/tos_controller.sh" "$HOME/.local/bin/team_of_six"
cat <<CONFIG > "$TOS_HOME/tos_config"
export AI_USER="$AI_USER"
export AI_GROUP="$GROUP"
export REAL_USER="$(whoami)"
export REPO_ROOT="$REPO_ROOT"
CONFIG
touch "$TOS_HOME/tos_input.sh" "$TOS_HOME/tos_output.log"
chmod 644 "$TOS_HOME/tos_input.sh" 
echo "✅ Installation Complete."
EOF

# --- 3. Wrapper (Hardened Logic) ---
# Resolves Home Paradox and Git Pollution.
echo "📝 Updating bin/tos_wrapper.sh..."
cat << 'EOF' > bin/tos_wrapper.sh
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
EOF

# --- 4. Publisher ---
# Secure publication using local git configs.
echo "📝 Updating bin/tos_publish.sh..."
cat << 'EOF' > bin/tos_publish.sh
#!/bin/zsh
set -e
while [[ "$#" -gt 0 ]]; do case $1 in -m) MSG="$2"; shift ;; esac; shift; done
[ -z "$MSG" ] && exit 1
source "$HOME/.team_of_six/tos_config"
unset GITHUB_TOKEN
source "$HOME/.team_of_six/.token"
sudo -u "$AI_USER" zsh <<SANDBOX
    export GITHUB_TOKEN='$GITHUB_TOKEN'
    cd "$(pwd)"
    git config --local url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
    git add . && git commit -m "$MSG" && git push
SANDBOX
echo "✅ Published."
EOF

# --- 5. Documentation ---
# Generates updated README and Man Page.
echo "📚 Generating Documentation..."
cat << 'EOF' > README.md
# Team of Six (V56 Hardened)
- **Isolation**: Restricted `team_of_six` user.
- **Security**: Variable shadowing and local git configs prevent leaks and pollution.
- **Safety**: Hygiene guard protects non-project directories.
EOF

mkdir -p docs
cat << 'EOF' > docs/usage.man
NAME: team_of_six
SYNOPSIS: team_of_six [wrapper|publish]
SECURITY: V56 uses a Service Account model. Tokens are injected via standard input.
EOF

chmod +x bin/*.sh
echo "✅ HARDENED PATCH COMPLETE."
