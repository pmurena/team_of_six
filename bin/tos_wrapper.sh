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
