#!/bin/zsh
# Team of Six - Project Creator
set -e
PROJECT_NAME=$1
[ -z "$PROJECT_NAME" ] && exit 1
TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"

mkdir -p "$PROJECT_NAME/.tos"
echo "Scaffolding" > "$PROJECT_NAME/.tos/state"
touch "$PROJECT_NAME/.tos/objections.md"

# Backlog
cat <<BACKLOG > "$PROJECT_NAME/.tos/features.md"
# 📋 Project Backlog: $PROJECT_NAME
* [ ] Initial Architecture (Current)
BACKLOG

# Enforce Ghost Ownership
sudo chown -R "$AI_USER:$AI_GROUP" "$PROJECT_NAME"
sudo chmod -R 775 "$PROJECT_NAME"
echo "✅ Project '$PROJECT_NAME' initialized."
