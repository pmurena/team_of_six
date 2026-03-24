#!/bin/zsh
# ==============================================================================
# Patch: V64 Container/FHS Architecture 
# Target: Core System & Installers
# Execution: Manual (Run as Architect)
# ==============================================================================

set -e
echo "🚀 Applying V64 Container/FHS Architecture Patch..."

REPO_ROOT="$(pwd)"
if [ ! -d "bin" ] || [ ! -f "tos_controller.sh" ]; then
    echo "❌ ERROR: Must be run from the team_of_six repository root."
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. REWRITE: tos_controller.sh
# ------------------------------------------------------------------------------
cat << 'EOF' > tos_controller.sh
#!/bin/zsh
# Team of Six - Global Controller V64 (FHS Container)

export TOS_SANDBOX="${TOS_SANDBOX:-/var/lib/tos_sandbox}"
export TOS_CONF="$TOS_SANDBOX/.tos"

# 1. Source Sandbox Config (Zero Context Switch)
if [ -f "$TOS_CONF/config" ]; then
    source "$TOS_CONF/config"
else
    echo "❌ ERROR: Config missing at $TOS_CONF/config"
    exit 1
fi

export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" 2>/dev/null | tr -d '\n\r ')

# 2. Hardcoded FHS Paths
export TOS_BIN="/opt/team_of_six/bin"
export TOS_IPC="/run/team_of_six"
export TOS_INPUT="$TOS_IPC/tos_input.sh"
export TOS_LOG="$TOS_IPC/controller.log"
export TOS_OUTBOX="$TOS_CONF/outbox"
export AI_USER="team_of_six"

# 3. IPC Provisioning (Volatile)
if [ ! -d "$TOS_IPC" ]; then
    sudo mkdir -p "$TOS_IPC"
    sudo chown "$USER:$AI_USER" "$TOS_IPC"
    sudo chmod 775 "$TOS_IPC"
fi
touch "$TOS_INPUT" "$TOS_LOG" && chmod 666 "$TOS_INPUT" "$TOS_LOG"

# 4. Execution
cd "$TOS_SANDBOX" || exit 1
CMD="$1"
[[ $# -gt 0 ]] && shift

case "$CMD" in
    "wrapper") "$TOS_BIN/tos_wrapper.sh" "$@" ;;
    "publish") "$TOS_BIN/tos_publish.sh" "$@" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    "")        "$TOS_BIN/tos_wrapper.sh" && "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: team_of_six [wrapper|new|publish]" ;;
esac
EOF

# ------------------------------------------------------------------------------
# 2. REWRITE: bin/tos_installer.sh
# ------------------------------------------------------------------------------
cat << 'EOF' > bin/tos_installer.sh
#!/bin/zsh
set -e
echo "💎 Team of Six: V64 FHS Installer"

# 1. Identity
sudo groupadd team_of_six || true
sudo useradd -r -g team_of_six -s /usr/sbin/nologin team_of_six || true
sudo usermod -a -G team_of_six "$(whoami)"

# 2. Engine (/opt)
sudo mkdir -p /opt/team_of_six/bin
sudo cp -r $(pwd)/bin/* /opt/team_of_six/bin/
sudo chmod -R 755 /opt/team_of_six
sudo ln -sf $(pwd)/tos_controller.sh /usr/local/bin/team_of_six
sudo ln -sf /usr/local/bin/team_of_six /usr/local/bin/tos

# 3. Sandbox & Config (/var/lib)
SANDBOX="/var/lib/tos_sandbox"
sudo mkdir -p "$SANDBOX/.tos/outbox"
sudo chown -R team_of_six:team_of_six "$SANDBOX"
sudo chmod -R 2775 "$SANDBOX" # Setgid to enforce group ownership

# Generate config if missing
if [ ! -f "$SANDBOX/.tos/config" ]; then
    echo "export TOS_SANDBOX=\"$SANDBOX\"" | sudo tee "$SANDBOX/.tos/config" > /dev/null
fi

# Token Capture
if [ ! -f "$SANDBOX/.tos/.token" ]; then
    echo -n "Paste GitHub PAT: "
    read -s RAW_TOKEN
    echo "$RAW_TOKEN" | tr -d '\n\r ' | sudo tee "$SANDBOX/.tos/.token" > /dev/null
    sudo chmod 660 "$SANDBOX/.tos/.token"
fi

sudo chown -R team_of_six:team_of_six "$SANDBOX/.tos"
echo "\n✅ V64 Installation Complete. Engine at /opt, Sandbox at /var/lib."
EOF

# ------------------------------------------------------------------------------
# 3. REWRITE: bin/tos_wrapper.sh
# ------------------------------------------------------------------------------
cat << 'EOF' > bin/tos_wrapper.sh
#!/bin/zsh
set -o pipefail

if [ -n "$(find "$TOS_OUTBOX" -mindepth 2 -maxdepth 2 -type d -print -quit 2>/dev/null)" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished payloads in $TOS_OUTBOX"
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$TOS_LOG"
cat "$TOS_INPUT" >> "$TOS_LOG"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$TOS_LOG" 2>&1
    export TOS_SANDBOX="$TOS_SANDBOX"
    export TOS_OUTBOX="$TOS_OUTBOX"
    cd "$TOS_SANDBOX" || exit 1
    if [ -s "$TOS_INPUT" ]; then
        source "$TOS_INPUT"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit $EXIT_CODE
EOF

# ------------------------------------------------------------------------------
# 4. Cleanup & Execute Installer
# ------------------------------------------------------------------------------
chmod +x tos_controller.sh bin/*.sh
echo "✅ Files patched. Running V64 Installer to lay down the FHS structure..."
./bin/tos_installer.sh

echo "🚀 System rebuilt. You can now use 'tos' directly."
