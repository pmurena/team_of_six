#!/usr/bin/env zsh
# ==============================================================================
# Team of Six - V76 Modular Typewriter Deployer (Dev Edition)
# Purpose: Infrastructure-as-Code for the Ghost Sandbox & XDG IPC Tier
# Execution: sudo ./deploy.sh
# ==============================================================================

set -e

# --- 1. Load Defaults from Repo Config ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_CONF="$REPO_ROOT/conf/config"

if [ -f "$REPO_CONF" ]; then
    source "$REPO_CONF"
    MNT_TARGET="$TOS_MNT_ROOT"
    AI_GROUP="$AI_USER"
else
    echo "🚨 ERROR: Configuration file not found at $REPO_CONF"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "🚨 ERROR: This script must be run with sudo."
  exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
USER_NEEDS_ACTIVATION=false

# --- 2. Create Ghost user & Group ---
echo "👥 Provisioning Identity..."
getent group "$AI_GROUP" >/dev/null || groupadd "$AI_GROUP"
id "$AI_USER" &>/dev/null || useradd -r -g "$AI_GROUP" -s /usr/sbin/nologin "$AI_USER"

if ! id -nG "$TARGET_USER" | grep -qw "$AI_GROUP"; then
    echo "   Adding $TARGET_USER to $AI_GROUP..."
    usermod -a -G "$AI_GROUP" "$TARGET_USER"
    USER_NEEDS_ACTIVATION=true
fi

# --- 3. Directory Scaffolding ---
echo "🏗️  Scaffolding Architecture at $MNT_TARGET..."
mkdir -p "$MNT_TARGET/.local/bin/utils"
mkdir -p "$MNT_TARGET/.local/bin/work"
mkdir -p "$MNT_TARGET/.local/bin/write"
mkdir -p "$MNT_TARGET/.local/conf"
mkdir -p "$MNT_TARGET/tos_home/$TARGET_USER/.ipc"
mkdir -p "$MNT_TARGET/tos_home/$TARGET_USER/sandbox"

# --- 4. File Distribution ---
echo "🚚 Deploying Modular Binaries..."
cp -r "$REPO_ROOT/bin/"* "$MNT_TARGET/.local/bin/" 2>/dev/null || true

if [ -f "$REPO_ROOT/conf/error_trap.sh" ]; then
    cp "$REPO_ROOT/conf/error_trap.sh" "$MNT_TARGET/.local/bin/utils/error_trap.sh"
fi
cp "$REPO_ROOT/conf/config" "$MNT_TARGET/.local/conf/config"

find "$MNT_TARGET/.local/bin" -type f -exec sed -i 's/\r$//' {} +

# --- 5. Security & Permission Topology ---
echo "🔒 Wiring Strict Security Permissions..."

# The Root Perimeter
chown root:"$AI_GROUP" "$MNT_TARGET"
chmod 750 "$MNT_TARGET"

# Base Engine Directories (Root owned, Group can traverse)
chown root:"$AI_GROUP" "$MNT_TARGET/.local"
chown root:"$AI_GROUP" "$MNT_TARGET/.local/bin"
chown root:"$AI_GROUP" "$MNT_TARGET/.local/conf"
chmod 750 "$MNT_TARGET/.local"
chmod 750 "$MNT_TARGET/.local/bin"
chmod 750 "$MNT_TARGET/.local/conf"

# The Config
chmod 440 "$MNT_TARGET/.local/conf/config"

# ==========================================
# THE GATEWAY FIREWALL (THE FIX)
# ==========================================
# 1. Master Gateway: Root owns it. Group can read/execute to trigger escalation.
chown root:"$AI_GROUP" "$MNT_TARGET/.local/bin/tos"
chmod 550 "$MNT_TARGET/.local/bin/tos"

# 2. Modules & Utils: Ghost owns them. Group is LOCKED OUT (500).
# The Architect cannot run these directly. They must go through the Master Gateway.
chown -R "$AI_USER":"$AI_GROUP" "$MNT_TARGET/.local/bin/utils"
chown -R "$AI_USER":"$AI_GROUP" "$MNT_TARGET/.local/bin/work"
chown -R "$AI_USER":"$AI_GROUP" "$MNT_TARGET/.local/bin/write"

chmod -R 500 "$MNT_TARGET/.local/bin/utils"
chmod -R 500 "$MNT_TARGET/.local/bin/work"
chmod -R 500 "$MNT_TARGET/.local/bin/write"
# ==========================================

# The User Workspace & IPC
chown root:"$AI_GROUP" "$MNT_TARGET/tos_home"
chmod 750 "$MNT_TARGET/tos_home"

chown "$TARGET_USER":"$AI_GROUP" "$MNT_TARGET/tos_home/$TARGET_USER"
chmod 750 "$MNT_TARGET/tos_home/$TARGET_USER"

# The Shared Typewriter Ribbon
chown "$TARGET_USER":"$AI_GROUP" "$MNT_TARGET/tos_home/$TARGET_USER/.ipc"
chmod 770 "$MNT_TARGET/tos_home/$TARGET_USER/.ipc"

# The Ghost's Locked Sandbox
chown "$AI_USER":"$AI_GROUP" "$MNT_TARGET/tos_home/$TARGET_USER/sandbox"
chmod 700 "$MNT_TARGET/tos_home/$TARGET_USER/sandbox"

echo -e "\n✅ Deployment Complete."

if [ "$USER_NEEDS_ACTIVATION" = true ]; then
    echo -e "\n⚠️  IMPORTANT: You have just been added to the '$AI_GROUP' group."
    echo "To activate permissions in this terminal, run: newgrp $AI_GROUP"
fi
