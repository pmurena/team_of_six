#!/bin/zsh
# Team of Six - V56 "Level 0" Clean Bootstrap
# To be run by the Architect (REAL_USER) using sudo.

set -e

echo "💎 Team of Six: V56 Hardware & Identity Bridge (Clean)"

# 1. DISK DISCOVERY & MOUNTING
echo "\n🔍 Step 1: Disk Discovery"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
echo -n "\nSelect the device for the 25GB SSD (e.g., sdb1): "
read DEV_NAME
DEVICE="/dev/$DEV_NAME"

if [ ! -b "$DEVICE" ]; then
    echo "❌ Error: $DEVICE is not a valid block device."
    exit 1
fi

echo "⚠️  DANGER: This will mount $DEVICE to /mnt/team_of_six."
echo -n "Type 'CONFIRM' to proceed: "
read CONFIRM
if [[ "$CONFIRM" != "CONFIRM" ]]; then echo "Aborted."; exit 1; fi

sudo mkdir -p /mnt/team_of_six
sudo mount "$DEVICE" /mnt/team_of_six || { echo "❌ Mount failed. Ensure disk is formatted as ext4."; exit 1; }

# Persistence (fstab)
if ! grep -q "/mnt/team_of_six" /etc/fstab; then
    echo "📝 Adding to /etc/fstab..."
    UUID=$(sudo blkid -s UUID -o value "$DEVICE")
    echo "UUID=$UUID /mnt/team_of_six ext4 defaults 0 2" | sudo tee -a /etc/fstab
fi

# 2. IDENTITY MANAGEMENT
echo "\n👤 Step 2: Creating Ghost Identity"
AI_USER="team_of_six"
GROUP="team_of_six"
getent group "$GROUP" >/dev/null || sudo groupadd "$GROUP"
id "$AI_USER" &>/dev/null || sudo useradd -r -g "$GROUP" -s /usr/sbin/nologin "$AI_USER"
sudo usermod -a -G "$GROUP" "$(whoami)"

# 3. TOOLCHAIN INSTALLATION
echo "\n🛠️ Step 3: Installing Toolchain (git, gh, conda)"
sudo apt update && sudo apt install -y git gh zsh curl

# Install Miniconda system-wide
if [ ! -d "/opt/miniconda" ]; then
    echo "🐍 Installing Miniconda..."
    curl -Lo /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    sudo bash /tmp/miniconda.sh -b -p /opt/miniconda
    sudo ln -s /opt/miniconda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
    rm /tmp/miniconda.sh
fi

# 4. COLLOCATION SETUP (Tri-Repo)
echo "\n📂 Step 4: Initializing Sandbox Repositories"
cd /mnt/team_of_six
sudo -u "$(whoami)" git clone https://github.com/pmurena/llm_agents.git
sudo -u "$(whoami)" git clone https://github.com/pmurena/team_of_six.git

# 5. PERMISSION WIRING (V56 Sandbox Protocol)
echo "\n🔐 Step 5: Enforcing Ghost Ownership"
sudo chown -R "$AI_USER:$GROUP" /mnt/team_of_six
sudo chmod -R 775 /mnt/team_of_six

# 6. CONTROLLER LINK
sudo ln -sf /mnt/team_of_six/team_of_six/tos_controller.sh /usr/local/bin/team_of_six

echo "\n✅ V56 Bootstrap Complete."
echo "Usage: Start your first project with 'team_of_six new <project_name>'"
