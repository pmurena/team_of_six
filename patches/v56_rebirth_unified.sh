#!/bin/zsh
# Team of Six - Unified V56 Rebirth Patch (Full Script Replacement)
# Targets: installer, uninstaller, wrapper, and controller.

REPO_ROOT="$(pwd)"
echo "🩹 Applying Unified V56 Rebirth Patch to $REPO_ROOT..."

# 1. GOLD MASTER: bin/tos_installer.sh
cat <<'EOF' > bin/tos_installer.sh
#!/bin/zsh
set -e
echo "💎 Team of Six: Unified V56 Genesis Installer (Gold Master)"

# Hardware Setup
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
echo -n "\nSelect device (e.g., nvme0n1p4): "
read DEV_NAME
DEVICE="/dev/$DEV_NAME"
sudo mkdir -p /mnt/team_of_six
sudo mount "$DEVICE" /mnt/team_of_six
if ! grep -q "/mnt/team_of_six" /etc/fstab; then
    UUID=$(sudo blkid -s UUID -o value "$DEVICE")
    echo "UUID=$UUID /mnt/team_of_six ext4 defaults 0 2" | sudo tee -a /etc/fstab
fi

# Identity Setup
sudo groupadd team_of_six || true
sudo useradd -r -g team_of_six -s /usr/sbin/nologin team_of_six || true
sudo usermod -a -G team_of_six "$(whoami)"

# Toolchain & System Whitelist
sudo apt update && sudo apt install -y git gh zsh curl
sudo git config --system --add safe.directory '*'

# Token Capture & Sanitization
TOS_HOME="$HOME/.team_of_six"
mkdir -p "$TOS_HOME"
echo -n "Paste GitHub PAT (Visible): "
read RAW_TOKEN
PAT_TOKEN=$(echo "$RAW_TOKEN" | tr -d '\n\r ')
echo "export GITHUB_TOKEN='$PAT_TOKEN'" > "$TOS_HOME/.token"
chmod 600 "$TOS_HOME/.token"

# Permissions & Genesis Clones
sudo chown team_of_six:team_of_six /mnt/team_of_six
sudo chmod 775 /mnt/team_of_six

sudo -u team_of_six zsh <<GHOST
    export HOME=/tmp
    export GH_TOKEN="$PAT_TOKEN"
    cd /mnt/team_of_six
    git clone https://x-access-token:$PAT_TOKEN@github.com/pmurena/llm_agents.git
    git clone https://x-access-token:$PAT_TOKEN@github.com/pmurena/team_of_six.git

    for repo in llm_agents team_of_six; do
        if [ -d "/mnt/team_of_six/\$repo" ]; then
            cd /mnt/team_of_six/\$repo
            git config --local user.name "Team of Six (V56)"
            git config --local user.email "agent@teamofsix.bot"
            git config --local url."https://x-access-token:$PAT_TOKEN@github.com/".insteadOf "https://github.com/"
        fi
    done
GHOST

# Controller Linking
sudo ln -sf /mnt/team_of_six/team_of_six/tos_controller.sh /usr/local/bin/team_of_six
echo "\n✅ V56 Genesis Complete."
EOF

# 2. GOLD MASTER: bin/tos_uninstaller.sh
cat <<'EOF' > bin/tos_uninstaller.sh
#!/bin/zsh
echo "🗑️  Team of Six: Full System Purge..."
sudo git config --system --unset-all safe.directory "*" || true
sudo umount /mnt/team_of_six || true
sudo sed -i '/team_of_six/d' /etc/fstab
sudo rm -rf /mnt/team_of_six
sudo userdel -r team_of_six || true
sudo groupdel team_of_six || true
sudo rm -f /usr/local/bin/team_of_six
echo "✅ System Purged."
EOF

# 3. GOLD MASTER: bin/tos_wrapper.sh
cat <<'EOF' > bin/tos_wrapper.sh
#!/bin/zsh
# Team of Six - V56 Secure Wrapper
# Bridges Architect input to the Homeless Ghost context.

TOS_CONFIG="$HOME/.team_of_six/tos_config"
TOS_TOKEN="$HOME/.team_of_six/.token"

if [ ! -f "$TOS_CONFIG" ] || [ ! -f "$TOS_TOKEN" ]; then
    echo "❌ Error: TOS configuration not found. Run installer first."
    exit 1
fi

source "$TOS_CONFIG"
source "$TOS_TOKEN"

# Export critical env for the homeless ghost
export GH_TOKEN=$GITHUB_TOKEN
export HOME=/tmp

if [[ "$1" == "--input" ]]; then
    INPUT_FILE="$2"
    sudo -u "$AI_USER" zsh -c "source $TOS_TOKEN; export GH_TOKEN=\$GITHUB_TOKEN; export HOME=/tmp; zsh" < "$INPUT_FILE"
else
    sudo -u "$AI_USER" zsh -c "source $TOS_TOKEN; export GH_TOKEN=\$GITHUB_TOKEN; export HOME=/tmp; $*"
fi
EOF

# 4. GOLD MASTER: tos_controller.sh
cat <<'EOF' > tos_controller.sh
#!/bin/zsh
# Team of Six - V56 Global Controller
# High-level Architect interface.

TOS_CONFIG="$HOME/.team_of_six/tos_config"
TOS_TOKEN="$HOME/.team_of_six/.token"

if [ ! -f "$TOS_CONFIG" ] || [ ! -f "$TOS_TOKEN" ]; then
    echo "❌ Error: V56 configuration missing."
    exit 1
fi

source "$TOS_CONFIG"
source "$TOS_TOKEN"

# Anchor Ghost Environment
export HOME=/tmp
export GH_TOKEN=$GITHUB_TOKEN

case "$1" in
    "wrapper")
        shift
        $REPO_ROOT/bin/tos_wrapper.sh "$@"
        ;;
    "new")
        shift
        sudo -u "$AI_USER" zsh -c "export GH_TOKEN=$GITHUB_TOKEN; export HOME=/tmp; $REPO_ROOT/bin/tos_project_creator.sh $*"
        ;;
    "publish")
        shift
        sudo -u "$AI_USER" zsh -c "export GH_TOKEN=$GITHUB_TOKEN; export HOME=/tmp; cd $(pwd) && $REPO_ROOT/bin/tos_publish.sh $*"
        ;;
    *)
        echo "Usage: team_of_six [wrapper|new|publish] ..."
        ;;
esac
EOF

# Ensure all scripts are executable
chmod +x bin/*.sh tos_controller.sh

echo "✅ All scripts replaced with Gold Master V56 logic."
