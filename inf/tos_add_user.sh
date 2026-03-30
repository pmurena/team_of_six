#!/usr/bin/env zsh
# ==============================================================================
# Team of Six - Multi-Tenant User Provisioner (V72)
# Path: inf/add_user.sh
# ==============================================================================

TARGET_USER=$1
AI_GROUP=${AI_GROUP:-$AI_USER}
# Resolve Repo Root from inf/ directory
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/conf/config"

if [[ -z "$TARGET_USER" ]]; then
    echo "Usage: sudo ./inf/add_user.sh <username>"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "🚨 ERROR: Must run with sudo."
    exit 1
fi

echo "👥 Onboarding $TARGET_USER..."

# 1. Join Group
getent group "$AI_USER" >/dev/null || groupadd "$AI_GROUP"
usermod -a -G "$AI_GROUP" "$TARGET_USER"

# 2. Provision IPC (Airlock)
mkdir -p "$IPC_DIR/$TARGET_USER"
chown -R "$TARGET_USER":"$AI_GROUP" "$IPC_DIR/$TARGET_USER"
chmod -R 770 "$IPC_DIR/$TARGET_USER"

# 3. Secure Sudoers (Group-wide - Only needs to happen once)
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
