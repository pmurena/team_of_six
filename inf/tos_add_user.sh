#!/bin/zsh
# ==============================================================================
# Title: Multi-Tenant User Provisioner
#
# Usage Explanation: Run this script via `sudo` when onboarding a new human 
# Architect to the machine. It adds the human to the AI group, provisions their 
# personal IPC ribbon (inbox/outbox), builds their locked Ghost sandbox, and 
# wires the sudoers file to allow passwordless execution of the gateway engine.
# ==============================================================================

TARGET_USER=$1

if [[ -z "$TARGET_USER" ]]; then
    echo "Usage: sudo ./inf/tos_add_user.sh <username>"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "🚨 ERROR: Must run with sudo."
    exit 1
fi

# 1. Resolve Repo Root and Source Config FIRST
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/conf/config"

# Now the config is loaded, we can safely fall back to AI_USER
AI_GROUP=${AI_GROUP:-$AI_USER}

echo "👥 Onboarding $TARGET_USER..."

# 2. Join Group
getent group "$AI_GROUP" >/dev/null || groupadd "$AI_GROUP"
usermod -a -G "$AI_GROUP" "$TARGET_USER"

# 3. Provision IPC & Sandbox (The Airlock)
TARGET_IPC="$TOS_MNT_ROOT/tos_home/$TARGET_USER/.ipc"
TARGET_SANDBOX="$TOS_MNT_ROOT/tos_home/$TARGET_USER/sandbox"

mkdir -p "$TARGET_IPC"
mkdir -p "$TARGET_SANDBOX"

# IPC: 770 allows both the Architect and the Ghost to write
chown "$TARGET_USER":"$AI_GROUP" "$TARGET_IPC"
chmod 770 "$TARGET_IPC"

# Sandbox: 700 explicitly owned by the Ghost. Architect cannot enter.
chown "$AI_USER":"$AI_GROUP" "$TARGET_SANDBOX"
chmod 700 "$TARGET_SANDBOX"

# 4. Secure Sudoers (Group-wide - Only needs to happen once)
SUDO_TMP=$(mktemp)
SUDO_FINAL="/etc/sudoers.d/team_of_six_sandbox"
echo "%${AI_GROUP} ALL=(${AI_USER}) NOPASSWD: ${TOS_BIN}/tos" > "$SUDO_TMP"

if visudo -c -f "$SUDO_TMP" > /dev/null; then
    cp "$SUDO_TMP" "$SUDO_FINAL"
    chmod 0440 "$SUDO_FINAL"
    echo "✅ Sudoers Perimeter Verified."
else
    echo "🚨 Sudoers Validation Failed!"
    exit 1
fi
rm -f "$SUDO_TMP"
