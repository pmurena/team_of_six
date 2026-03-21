#!/bin/zsh
# Team of Six - Global Controller V64.2 (Neutral Zone & Ghost Ownership)
# Path: /opt/team_of_six/tos_controller.sh
# Symlink: /usr/local/bin/tos -> /opt/team_of_six/tos_controller.sh

# 1. Resolve Environment (Architect Context)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Static Runtime Path (Repo #3)
export TOS_BIN="/opt/team_of_six/bin"

# Triple-Gated Paths
export TOS_CONF="$XDG_CONFIG_HOME/team_of_six"
export TOS_LOG="$XDG_STATE_HOME/team_of_six/controller.log"
export TOS_INPUT="$XDG_RUNTIME_DIR/tos_input.sh"

# These live on the Mount (Repo #1)
export TOS_OUTBOX="/mnt/team_of_six/.tos/outbox"
export TOS_SANDBOX="/mnt/team_of_six/team_of_six"

# 2. Validation & Token Extraction
[ ! -f "$TOS_CONF/conf" ] && { echo "❌ Config missing: $TOS_CONF/conf"; exit 1; }
source "$TOS_CONF/conf"
[ -f "$TOS_CONF/.token" ] && export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" | tr -d '\n\r ')

# 3. The Unified Execution Bridge
# - Injects all variables into the Ghost's environment.
# - Ghost creates its own directories (mkdir) to ensure native ownership.
# - Uses 'zsh <script>' to ensure execution regardless of mount 'noexec' flags.
run_as_ghost() {
    sudo -u "$AI_USER" \
        TOS_BIN="$TOS_BIN" \
        TOS_SANDBOX="$TOS_SANDBOX" \
        TOS_OUTBOX="$TOS_OUTBOX" \
        TOS_LOG="$TOS_LOG" \
        TOS_INPUT="$TOS_INPUT" \
        GITHUB_TOKEN="$TOS_GITHUB_TOKEN" \
        zsh -c "
            export HOME=/tmp/tos_ghost
            mkdir -p \$HOME '$TOS_OUTBOX' '$TOS_SANDBOX' \$(dirname '$TOS_LOG')
            zsh $1
        "
}

# 4. Context Anchoring
# Architect moves to Sandbox before triggering the Ghost
cd "$TOS_SANDBOX" || { echo "❌ Failed to enter sandbox: $TOS_SANDBOX"; exit 1; }

# 5. Command Dispatch
case "$1" in
    "wrapper") 
        run_as_ghost "$TOS_BIN/tos_wrapper.sh" 
        ;;
    "publish") 
        run_as_ghost "$TOS_BIN/tos_publish.sh" 
        ;;
    "new")     
        # Project creator remains in Architect context for user interaction
        "$TOS_BIN/tos_project_creator.sh" "$@" 
        ;;
    "")        
        # Default: Full Loop
        run_as_ghost "$TOS_BIN/tos_wrapper.sh" && \
        run_as_ghost "$TOS_BIN/tos_publish.sh" 
        ;;
    *)         
        echo "Usage: tos [wrapper|publish|new]" 
        ;;
esac
