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
