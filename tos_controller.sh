#!/bin/zsh
# Team of Six - Global Controller V64 (FHS Container)

export TOS_SANDBOX="${TOS_SANDBOX:-/var/lib/tos_sandbox}"
export TOS_CONF="$TOS_SANDBOX/.tos"

# 1. Source Sandbox Config (Zero Context Switch)
if [ -f "$TOS_CONF/config" ]; then
    source "$TOS_CONF/config"
else
    echo "❌ ERROR: Config missing at $TOS_CONF/config"
    exit 1
fi

export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" 2>/dev/null | tr -d '\n\r ')

# 2. Hardcoded FHS Paths
export TOS_BIN="/opt/team_of_six/bin"
export TOS_IPC="/run/team_of_six"
export TOS_INPUT="$TOS_IPC/tos_input.sh"
export TOS_LOG="$TOS_IPC/controller.log"
export TOS_OUTBOX="$TOS_CONF/outbox"
export AI_USER="team_of_six"

# 3. IPC Provisioning (Volatile)
if [ ! -d "$TOS_IPC" ]; then
    sudo mkdir -p "$TOS_IPC"
    sudo chown "$USER:$AI_USER" "$TOS_IPC"
    sudo chmod 775 "$TOS_IPC"
fi
touch "$TOS_INPUT" "$TOS_LOG" && chmod 666 "$TOS_INPUT" "$TOS_LOG"

# 4. Execution
cd "$TOS_SANDBOX" || exit 1
CMD="$1"
[[ $# -gt 0 ]] && shift

case "$CMD" in
    "wrapper") "$TOS_BIN/tos_wrapper.sh" "$@" ;;
    "publish") "$TOS_BIN/tos_publish.sh" "$@" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    "")        "$TOS_BIN/tos_wrapper.sh" && "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: team_of_six [wrapper|new|publish]" ;;
esac
