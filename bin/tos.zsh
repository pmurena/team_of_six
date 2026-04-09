#!/bin/zsh
# ==============================================================================
# Team of Six - Global Gateway
# ==============================================================================
# Protocol: tos <project> <module> <action> [args]
#
# Modules are discovered dynamically from bin/modules/. To add a new module,
# create bin/modules/<module>/soft/ and/or bin/modules/<module>/hard/ and drop
# action scripts in. The gateway requires zero changes.
#
# Lock policy is encoded by folder:
#   soft/ — any clean lock suffices (Trinity 0 or higher)
#   hard/ — an active trinity (> 0) is required
# ==============================================================================

# === STAGE 1: SECURITY PERIMETER ===
# If not already running as the Ghost, attempt self-escalation via sudo.
if [[ -z "$SUDO_USER" ]]; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "${AI_GROUP:-team_of_six}"; then
        echo "🚨 [ACCESS DENIED] You are not a member of the team_of_six group." >&2
        exit 1
    fi
    exec sudo -n -u team_of_six "$0" "$@"
    echo "🚨 [ERROR] The Threshold is sealed. sudo escalation failed." >&2
    exit 1
fi

# At this point we are the Ghost via legitimate sudo escalation.
# Set the controller lock now — all sub-scripts treat this as proof of
# authorised invocation through the gateway.
export TOS_CONTROLLER_LOCKED=true

# === STAGE 2: CONFIGURATION INJECTION ===
TOS_GLOBAL_CONF="/mnt/team_of_six/.local/conf/config"
if [[ -f "$TOS_GLOBAL_CONF" ]]; then
    source "$TOS_GLOBAL_CONF"
else
    echo "🚨 [ERROR] Missing global configuration at $TOS_GLOBAL_CONF" >&2
    exit 1
fi

[[ -z "$TOS_BIN" ]] && { echo "🚨 [ERROR] Config did not set TOS_BIN." >&2; exit 1; }
[[ -z "$TOS_IPC" ]] && { echo "🚨 [ERROR] Config did not set TOS_IPC." >&2; exit 1; }

source "$TOS_BIN/utils/error_trap.zsh"

# Load the Ghost's GitHub token and scrub it on exit
TOKEN_FILE="$TOS_MNT_ROOT/.local/conf/.token"
if [[ -s "$TOKEN_FILE" ]]; then
    export GH_TOKEN=$(cat "$TOKEN_FILE")
    export GITHUB_TOKEN="$GH_TOKEN"
else
    echo "🚨 [ERROR] Missing or empty token at $TOKEN_FILE" >&2
    exit 1
fi
export TOS_PARSE_DIR=$(mktemp -d)
trap 'unset GH_TOKEN; unset GITHUB_TOKEN; rm -rf "$TOS_PARSE_DIR"' EXIT INT TERM

# === STAGE 3: ARGUMENT PARSING ===
PROJECT_NAME="$1"
MODULE="$2"
ACTION="$3"

[[ -z "$PROJECT_NAME" ]] && { echo "🚨 [ERROR] Missing project name. Usage: tos <project> <module> <action>" >&2; exit 1; }
[[ -z "$MODULE" ]]       && { echo "🚨 [ERROR] Missing module. Usage: tos <project> <module> <action>" >&2; exit 1; }
[[ -z "$ACTION" ]]       && { echo "🚨 [ERROR] Missing action. Usage: tos <project> <module> <action>" >&2; exit 1; }

shift 3

# === STAGE 3b: CALLER LOCATION VERIFICATION ===
# tos must be called from within the correct git repository root.
# The project name must match the git remote name — no exceptions.
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)
if [[ -z "$CURRENT_REMOTE" ]]; then
    echo "🚨 [ERROR] Not inside a git repository. cd into '$PROJECT_NAME' and retry." >&2
    exit 1
fi
CURRENT_REPO=$(basename "$CURRENT_REMOTE" .git)
if [[ "$CURRENT_REPO" != "$PROJECT_NAME" ]]; then
    echo "🚨 [ERROR] Project mismatch: you are in '$CURRENT_REPO' but called tos with '$PROJECT_NAME'." >&2
    echo "    cd into the correct project root and retry." >&2
    exit 1
fi

# === STAGE 4: ENVIRONMENT & CONTEXT ===
export TOS_ACTIVE_PROJECT="$PROJECT_NAME"

# Derive active trinity from the authoritative lock file in the control plane.
# Nothing is written to the sandbox — zero proprietary pollution.
ACTIVE_LOCK=$(grep -rl "$SUDO_USER:HARD_LOCK" "$TOS_LOCKS" 2>/dev/null | grep "${PROJECT_NAME}_trinity_" | head -1)
if [[ -n "$ACTIVE_LOCK" ]]; then
    export TOS_ACTIVE_TRINITY=$(basename "$ACTIVE_LOCK" | sed 's/.*_trinity_\([0-9]*\)\.lock/\1/')
else
    export TOS_ACTIVE_TRINITY="0"
fi

# === STAGE 5: FILESYSTEM-DRIVEN DISPATCH & LOCK ENFORCEMENT ===
# The script's location (hard/ or soft/) is the sole authority on what lock
# it requires. No action names are hardcoded here — adding or moving a command
# is enough; the security model updates automatically.
MODULES_ROOT="$TOS_BIN/modules"
MODULE_DIR="$MODULES_ROOT/$MODULE"

if [[ ! -d "$MODULE_DIR" ]]; then
    echo "🚨 [ERROR] Unknown module: '$MODULE'." >&2
    echo "    Available modules: $(ls $MODULES_ROOT 2>/dev/null | tr '\n' ' ')" >&2
    exit 1
fi

# Resolve the target script — location determines lock requirement
TARGET_SCRIPT=""
LOCK_REQUIRED=""

if [[ -x "$MODULE_DIR/soft/${ACTION}.zsh" ]]; then
    TARGET_SCRIPT="$MODULE_DIR/soft/${ACTION}.zsh"
    LOCK_REQUIRED="soft"
elif [[ -x "$MODULE_DIR/hard/${ACTION}.zsh" ]]; then
    TARGET_SCRIPT="$MODULE_DIR/hard/${ACTION}.zsh"
    LOCK_REQUIRED="hard"
else
    echo "🚨 [ERROR] Unknown action: '$ACTION' for module '$MODULE'." >&2
    echo "    Soft actions: $(ls $MODULE_DIR/soft/*.zsh 2>/dev/null | xargs -I{} basename {} .zsh | tr '\n' ' ')" >&2
    echo "    Hard actions: $(ls $MODULE_DIR/hard/*.zsh 2>/dev/null | xargs -I{} basename {} .zsh | tr '\n' ' ')" >&2
    exit 1
fi

if [[ "$LOCK_REQUIRED" == "hard" && "$TOS_ACTIVE_TRINITY" == "0" ]]; then
    echo "🚨 [ERROR] '$ACTION' requires an active trinity (hard lock)." >&2
    echo "    Run: tos $PROJECT_NAME sync trinity <ID>" >&2
    exit 1
fi

# === STAGE 6: EXECUTION ===
mkdir -p "$TOS_IPC" 2>/dev/null

echo "🔑 [GATEWAY] $SUDO_USER | $PROJECT_NAME | $MODULE $ACTION $*"

# Execute target script directly — the gateway resolves the script itself,
# module routers are not needed.
{ "$TARGET_SCRIPT" "$PROJECT_NAME" "$@" } 2>&1 | tee "$TOS_CONTEXT"
