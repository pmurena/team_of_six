#!/bin/zsh

# ==============================================================================
# Title: Multi-Tenant User Provisioner
#
# Usage: sudo ./inf/tos_add_user.zsh <username>
#
# Adds a new Architect to the AI group, provisions their IPC ribbon in the
# global control plane (.ipc/<user>/), creates their flattened sandbox
# (sandbox/<user>/), and wires the sudoers file for passwordless gateway access.
# ==============================================================================

TARGET_USER=$1

if [[ -z "$TARGET_USER" ]]; then
    echo "Usage: sudo ./inf/tos_add_user.zsh <username>"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "🚨 ERROR: Must run with sudo."
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/conf/config"

AI_GROUP=${AI_GROUP:-$AI_USER}

echo "👥 Onboarding $TARGET_USER..."

# 1. Join Group
getent group "$AI_GROUP" >/dev/null || groupadd "$AI_GROUP"
usermod -a -G "$AI_GROUP" "$TARGET_USER"

# 2. Provision IPC ribbon under global control plane
TARGET_IPC="$TOS_MNT_ROOT/.ipc/$TARGET_USER"
mkdir -p "$TARGET_IPC"
touch "$TARGET_IPC/inbox.md" "$TARGET_IPC/outbox.md"

chown "${TARGET_USER}:${AI_GROUP}" "$TARGET_IPC/inbox.md"
chown "${AI_USER}:${AI_GROUP}"     "$TARGET_IPC/outbox.md"
chmod 660 "$TARGET_IPC/"*.md

chown "${AI_USER}:${AI_GROUP}" "$TARGET_IPC"
chmod 3770 "$TARGET_IPC"
setfacl -d -m u::rwX,g::rwX,o::--- "$TARGET_IPC"

# 3. Provision flattened sandbox
TARGET_SANDBOX="$TOS_MNT_ROOT/sandbox/$TARGET_USER"
mkdir -p "$TARGET_SANDBOX"
chown "${AI_USER}:${AI_GROUP}" "$TARGET_SANDBOX"
chmod 700 "$TARGET_SANDBOX"

# 4. Secure Sudoers (group-wide — only needs to happen once)
SUDO_TMP=$(mktemp)
SUDO_FINAL="/etc/sudoers.d/team_of_six_sandbox"
echo "%${AI_GROUP} ALL=(${AI_USER}) NOPASSWD: ${TOS_BIN}/tos.zsh" > "$SUDO_TMP"

if visudo -c -f "$SUDO_TMP" > /dev/null; then
    cp "$SUDO_TMP" "$SUDO_FINAL"
    chmod 0440 "$SUDO_FINAL"
    echo "✅ Sudoers Perimeter Verified."
else
    echo "🚨 Sudoers Validation Failed!"
    exit 1
fi
rm -f "$SUDO_TMP"

# 5. Global Environment Variable
echo "export TOS_MNT_ROOT=\"$TOS_MNT_ROOT\"" > /etc/profile.d/tos.sh
chmod 644 /etc/profile.d/tos.sh

echo "✅ $TARGET_USER onboarded successfully."
