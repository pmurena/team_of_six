#!/bin/zsh
# Team of Six - Global Controller V64.3 (Total Isolation)

# 1. Resolve Environment (Architect Context)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Static Runtime Path (Repo #3)
export TOS_BIN="/opt/team_of_six/bin"

# --- THE FIX: Move State out of /home/pat ---
# We point these to the mount and /tmp so the Ghost has native access
export TOS_OUTBOX="/mnt/team_of_six/.tos/outbox"
export TOS_SANDBOX="/mnt/team_of_six/team_of_six"
export TOS_LOG="/mnt/team_of_six/.tos/controller.log" 
export TOS_INPUT="/tmp/tos_input.sh" 
# --------------------------------------------

export TOS_CONF="$XDG_CONFIG_HOME/team_of_six"

# 2. Validation & Token Extraction
[ ! -f "$TOS_CONF/conf" ] && { echo "❌ Config missing: $TOS_CONF/conf"; exit 1; }
source "$TOS_CONF/conf"
[ -f "$TOS_CONF/.token" ] && export TOS_GITHUB_TOKEN=$(cat "$TOS_CONF/.token" | tr -d '\n\r ')

# 3. The Unified Execution Bridge
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
cd "$TOS_SANDBOX" || { echo "❌ Failed to enter sandbox: $TOS_SANDBOX"; exit 1; }

# 5. Command Dispatch
case "$1" in
    "wrapper") run_as_ghost "$TOS_BIN/tos_wrapper.sh" ;;
    "publish") run_as_ghost "$TOS_BIN/tos_publish.sh" ;;
    "new")     "$TOS_BIN/tos_project_creator.sh" "$@" ;;
    *)         run_as_ghost "$TOS_BIN/tos_wrapper.sh" && run_as_ghost "$TOS_BIN/tos_publish.sh" ;;
esac
