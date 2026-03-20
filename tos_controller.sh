#!/bin/zsh
# Team of Six - Global Controller V63 (XDG Native)

# 1. Resolve XDG Base Directories (with fallbacks)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# 2. Define System Paths
export TOS_CONF="$XDG_CONFIG_HOME/team_of_six"
export TOS_INPUT="$XDG_RUNTIME_DIR/tos_input.sh"
export TOS_LOG="$XDG_STATE_HOME/team_of_six/controller.log"
export TOS_OUTBOX="$XDG_STATE_HOME/team_of_six/outbox"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--config) export TOS_CONF="$2"; shift 2 ;;
        *) break ;;
    esac
done

if [ ! -f "$TOS_CONF/conf" ] || [ ! -f "$TOS_CONF/.token" ]; then
    echo "❌ Error: Configuration missing in $TOS_CONF."
    exit 1
fi

source "$TOS_CONF/conf"
export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" | tr -d '\n\r ')

if [ -z "$TOS_SANDBOX" ] || [ -z "$TOS_BIN" ]; then
    echo "❌ Error: TOS_SANDBOX or TOS_BIN is not defined in conf."
    exit 1
fi

# Ensure directories exist and Outbox is accessible to AI_USER
mkdir -p "$(dirname "$TOS_LOG")"
mkdir -p "$TOS_OUTBOX"
chmod 777 "$TOS_OUTBOX"
touch "$TOS_INPUT"

cd "$TOS_SANDBOX" || exit 1

CMD="$1"
# Only shift if arguments exist to prevent shift count error
[[ $# -gt 0 ]] && shift

case "$CMD" in
    "wrapper") "$TOS_BIN/tos_wrapper.sh" "$@" ;;
    "publish") "$TOS_BIN/tos_publish.sh" "$@" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    "")        echo "🔄 Executing Unified Loop..."; "$TOS_BIN/tos_wrapper.sh" && "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: team_of_six [-c <config_dir>] [wrapper|new|publish]" ;;
esac
