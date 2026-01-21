#!/bin/zsh
set -e
AI_USER="team_of_six"
GROUP="team_of_six"
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
echo "🔧 Installing V56 (Hardened)..."
sudo -v
getent group "$GROUP" >/dev/null || sudo groupadd "$GROUP"
id "$AI_USER" &>/dev/null || sudo useradd -r -g "$GROUP" -s /usr/sbin/nologin "$AI_USER"
sudo usermod -a -G "$GROUP" "$(whoami)"
TOS_HOME="$HOME/.team_of_six"
mkdir -p "$TOS_HOME"
if [ ! -f "$TOS_HOME/.token" ]; then
    echo -n "🔑 Paste GitHub Token: "
    read -s UT
    echo "export GITHUB_TOKEN='$UT'" > "$TOS_HOME/.token"
    chmod 600 "$TOS_HOME/.token"
fi
ln -sf "$REPO_ROOT/tos_controller.sh" "$HOME/.local/bin/team_of_six"
cat <<CONFIG > "$TOS_HOME/tos_config"
export AI_USER="$AI_USER"
export AI_GROUP="$GROUP"
export REAL_USER="$(whoami)"
export REPO_ROOT="$REPO_ROOT"
CONFIG
touch "$TOS_HOME/tos_input.sh" "$TOS_HOME/tos_output.log"
chmod 644 "$TOS_HOME/tos_input.sh" 
echo "✅ Installation Complete."
