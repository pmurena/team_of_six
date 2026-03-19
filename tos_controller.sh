#!/bin/zsh
# Team of Six - Global Controller V62.5 (XDG & CLI Config)

export TOS_CONF="$HOME/.config/team_of_six"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--config) export TOS_CONF="$2"; shift 2 ;;
        *) break ;;
    esac
done

# Updated to look for 'conf' instead of 'tos_config'
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

cd "$TOS_SANDBOX" || exit 1

CMD="$1"
shift || true

case "$CMD" in
    "wrapper") "$TOS_BIN/tos_wrapper.sh" "$@" ;;
    "publish") "$TOS_BIN/tos_publish.sh" "$@" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    "")        echo "🔄 Executing Unified Loop..."; "$TOS_BIN/tos_wrapper.sh" && "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: team_of_six [-c <config_dir>] [wrapper|new|publish]" ;;
esac
