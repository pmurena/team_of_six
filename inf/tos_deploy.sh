#!/usr/bin/env zsh
# ==============================================================================
# Team of Six - V71 Grand Unification Deployer (Dev Edition)
# Purpose: Infrastructure-as-Code for the Ghost Sandbox & XDG IPC Tier
# Execution: sudo ./deploy.sh
# ==============================================================================

set -e

# --- 1. Load Defaults from Repo Config ---
# Dynamically resolve the absolute path of the repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_CONF="$REPO_ROOT/conf/config"

if [ -f "$REPO_CONF" ]; then
    source "$REPO_CONF"
    # Mapping repo-specific variables to deployment targets
    MNT_TARGET="$TOS_MNT_ROOT"
    AI_GROUP="$AI_USER"
else
    echo "🚨 ERROR: Configuration file not found at $REPO_CONF"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "🚨 ERROR: This script must be run with sudo to configure system users and permissions."
  exit 1
fi

# Ensure target user is captured when running via sudo
TARGET_USER="${SUDO_USER:-$USER}"
USER_NEEDS_ACTIVATION=false

# --- 2. Create Ghost user & Group ---
echo "👥 Provisioning Identity..."
getent group "$AI_GROUP" >/dev/null || groupadd "$AI_GROUP"
id "$AI_USER" &>/dev/null || useradd -r -g "$AI_GROUP" -s /usr/sbin/nologin "$AI_USER"

# Smart Group Check: Only add and warn if they aren't already in the group
if ! id -nG "$TARGET_USER" | grep -qw "$AI_GROUP"; then
    echo "   Adding $TARGET_USER to $AI_GROUP..."
    usermod -a -G "$AI_GROUP" "$TARGET_USER"
    USER_NEEDS_ACTIVATION=true
fi

# --- 3. Directory Scaffolding (XDG Native) ---
echo "🏗️  Scaffolding Architecture at $MNT_TARGET..."
mkdir -p "$MNT_TARGET/.local/bin"
mkdir -p "$MNT_TARGET/.local/conf"
mkdir -p "$MNT_TARGET/sandbox/.tos_outbox"

# Tier 3: The IPC Airlock (Persistent State)
IPC_ROOT="$MNT_TARGET/.ipc"
mkdir -p "$IPC_ROOT/$TARGET_USER"

# --- 4. File Distribution ---
echo "🚚 Deploying Binaries..."
# Since deploy.sh is in the root, it won't be copied into the engine!
cp "$REPO_ROOT/bin/"* "$MNT_TARGET/.local/bin/"
cp "$REPO_ROOT/conf/config" "$MNT_TARGET/.local/conf/config"
cp "$REPO_ROOT/conf/error_trap.sh" "$MNT_TARGET/.local/conf/error_trap.sh"

# Fix Line Endings for portability (Preserving the native #!/bin/zsh shebangs)
sed -i 's/\r$//' "$MNT_TARGET/.local/bin/"*

# --- 5. Security & Permission Topology ---
echo "🔒 Wiring Strict Security Permissions..."

# The Root Perimeter
chown root:"$AI_GROUP" "$MNT_TARGET"
chmod 750 "$MNT_TARGET"

# The Immutable Engine
chown -R root:"$AI_GROUP" "$MNT_TARGET/.local"
chmod -R 750 "$MNT_TARGET/.local"
chown root:"$AI_GROUP" "$MNT_TARGET/.local/bin/"*
chmod 750 "$MNT_TARGET/.local/bin/"*

# The Ghost Workspace
chown -R "$AI_USER":"$AI_GROUP" "$MNT_TARGET/sandbox"
chmod -R 770 "$MNT_TARGET/sandbox"

# The Airlock (Root structure vs User subfolder)
chown root:"$AI_GROUP" "$IPC_ROOT"
chmod 770 "$IPC_ROOT"
chown -R "$TARGET_USER":"$AI_GROUP" "$IPC_ROOT/$TARGET_USER"
chmod -R 770 "$IPC_ROOT/$TARGET_USER"

echo -e "\n✅ Deployment Complete."
echo "Set your alias: alias tos='sudo -u $AI_USER $MNT_TARGET/.local/bin/tos'"

# --- 6. The Activation Prompt ---
if [ "$USER_NEEDS_ACTIVATION" = true ]; then
    echo -e "\n⚠️  IMPORTANT: You have just been added to the '$AI_GROUP' group."
    echo "To activate these permissions in your current terminal, you MUST run:"
    echo "👉  newgrp $AI_GROUP"
    echo "(Or simply close this terminal and open a new one)."
fi
