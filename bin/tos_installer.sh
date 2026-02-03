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
