#!/bin/zsh
# Team of Six - Global Controller V64 (Absolute Identity)

# 1. Resolve Environment (Architect Context)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

export TOS_CONF="$XDG_CONFIG_HOME/team_of_six"
export TOS_LOG="$XDG_STATE_HOME/team_of_six/controller.log"
export TOS_OUTBOX="$XDG_STATE_HOME/team_of_six/outbox"
export TOS_INPUT="$XDG_RUNTIME_DIR/tos_input.sh"

# 2. Validation
[ ! -f "$TOS_CONF/conf" ] && { echo "❌ Config missing: $TOS_CONF/conf"; exit 1; }
source "$TOS_CONF/conf"
export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" | tr -d '\n\r ')

# 3. Path Lockdown
mkdir -p "$TOS_OUTBOX" "$TOS_SANDBOX" "$(dirname "$TOS_LOG")"
chmod 777 "$TOS_OUTBOX" # Ensure AI_USER can write payloads

# 4. The Unified Execution Bridge
# We CD to the sandbox HERE to prevent root-relative errors
cd "$TOS_SANDBOX" || { echo "❌ Failed to enter sandbox: $TOS_SANDBOX"; exit 1; }

# We pass ALL critical variables explicitly to the sudo shell
run_as_ghost() {
    sudo -u "$AI_USER" \
        TOS_SANDBOX="$TOS_SANDBOX" \
        TOS_OUTBOX="$TOS_OUTBOX" \
        TOS_LOG="$TOS_LOG" \
        TOS_INPUT="$TOS_INPUT" \
        GITHUB_TOKEN="$TOS_GITHUB_TOKEN" \
        zsh -c "export HOME=/tmp/tos_ghost; mkdir -p \$HOME; source $1"
}

case "$1" in
    "wrapper") run_as_ghost "$TOS_BIN/tos_wrapper.sh" ;;
    "publish") run_as_ghost "$TOS_BIN/tos_publish.sh" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    "")        run_as_ghost "$TOS_BIN/tos_wrapper.sh" && run_as_ghost "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: team_of_six [wrapper|publish|new]" ;;
esac

