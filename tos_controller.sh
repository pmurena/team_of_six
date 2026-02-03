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
