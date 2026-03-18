#!/bin/zsh
# Team of Six - Global Controller V58

TOS_CONFIG="$HOME/.team_of_six/tos_config"
TOS_TOKEN="$HOME/.team_of_six/.token"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$TOS_CONFIG" ] || [ ! -f "$TOS_TOKEN" ]; then
    echo "❌ Error: V58 configuration missing."
    exit 1
fi

source "$TOS_CONFIG"
source "$TOS_TOKEN"
export GH_TOKEN=$GITHUB_TOKEN

case "$1" in
    "wrapper")
        shift
        "$REPO_ROOT/bin/tos_wrapper.sh" "$@"
        ;;
    "publish")
        shift
        "$REPO_ROOT/bin/tos_publish.sh" "$@"
        ;;
    "new")
        shift
        "$REPO_ROOT/bin/tos_project_creator.sh" "$@"
        ;;
    "")
        echo "🔄 Executing Unified Loop (Wrapper -> Publish)..."
        "$REPO_ROOT/bin/tos_wrapper.sh" && "$REPO_ROOT/bin/tos_publish.sh"
        ;;
    *)
        echo "Usage: team_of_six [wrapper|new|publish] or run without args for unified loop."
        ;;
esac
