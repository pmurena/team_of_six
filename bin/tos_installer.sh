#!/bin/zsh
# V56 Deployment Script - Permission Wiring
set -e

AI_USER="team_of_six"
GROUP="team_of_six"
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
REAL_USER=$(whoami)

sudo -v
if ! getent group "$GROUP" >/dev/null; then sudo groupadd "$GROUP"; fi
if ! id "$AI_USER" &>/dev/null; then sudo useradd -r -g "$GROUP" -s /bin/zsh "$AI_USER"; fi
sudo usermod -a -G "$GROUP" "$REAL_USER"

echo "📂 [SUDO] Wiring Permissions..."
# Repo belongs to Ghost ($AI_USER)
sudo chown -R "$AI_USER:$GROUP" "$REPO_ROOT"
sudo chmod -R 775 "$REPO_ROOT"
# Config belongs to Architect ($REAL_USER)
sudo chown -R "$REAL_USER:$GROUP" "$HOME/.team_of_six"
sudo chmod -R 775 "$HOME/.team_of_six"

echo "✅ Installation Complete."
