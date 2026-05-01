#!/bin/zsh
# ==============================================================================
# Team of Six - Global Gateway
# ==============================================================================

# === STAGE 1: SECURITY PERIMETER ===
if [[ -z "$SUDO_USER" && "$TOS_TEST_MODE" != "1" ]]; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "${AI_GROUP:-team_of_six}"; then
        echo "🚨 [ACCESS DENIED]" >&2
        exit 1
    fi
    exec sudo -n -u team_of_six "$0" "$@"
    exit 1
fi
export TOS_CONTROLLER_LOCKED=true
export SUDO_USER="${SUDO_USER:-$USER}"

# === STAGE 2: CONFIGURATION INJECTION ===
TOS_GLOBAL_CONF="${TOS_MNT_ROOT}/.local/conf/config"
[[ -f "$TOS_GLOBAL_CONF" ]] && source "$TOS_GLOBAL_CONF"
source "$TOS_BIN/utils/error_trap.zsh"

TOKEN_FILE="$TOS_MNT_ROOT/.local/conf/.token"
if [[ -s "$TOKEN_FILE" ]]; then
    export GH_TOKEN=$(cat "$TOKEN_FILE")
    export GITHUB_TOKEN="$GH_TOKEN"
fi
export TOS_PARSE_DIR=$(mktemp -d)
trap 'unset GH_TOKEN; unset GITHUB_TOKEN; rm -rf "$TOS_PARSE_DIR"' EXIT INT TERM

# === STAGE 3: ARGUMENT PARSING ===
PROJECT_NAME="$1"; MODULE="$2"; ACTION="$3"
[[ -z "$PROJECT_NAME" || -z "$MODULE" || -z "$ACTION" ]] && exit 1
shift 3

# === STAGE 3b: CALLER LOCATION VERIFICATION ===
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || true)
if [[ -n "$CURRENT_REMOTE" && "$CURRENT_REMOTE" != *"team_of_six"* ]]; then
    CURRENT_REPO=$(basename "$CURRENT_REMOTE" .git 2>/dev/null || true)
    if [[ -n "$CURRENT_REPO" && "$CURRENT_REPO" != "$PROJECT_NAME" ]]; then
        echo "🚨 [ERROR] Project mismatch: active is '$CURRENT_REPO' but called with '$PROJECT_NAME'." >&2
        exit 1
    fi
fi

# === STAGE 4: ENVIRONMENT & CONTEXT ===
export TOS_ACTIVE_PROJECT="$PROJECT_NAME"

# SAFE LOCK EXTRACTION: '|| true' prevents pipeline failures from crashing the gateway
ACTIVE_LOCK=$(grep -rl "$SUDO_USER:HARD_LOCK" "$TOS_LOCKS" 2>/dev/null | grep "${PROJECT_NAME}_trinity_" | head -1 || true)
if [[ -n "$ACTIVE_LOCK" ]]; then
    export TOS_ACTIVE_TRINITY=$(basename "$ACTIVE_LOCK" | sed 's/.*_trinity_\([0-9]*\)\.lock/\1/')
else
    export TOS_ACTIVE_TRINITY="0"
fi

# === STAGE 5: HALLUCINATION PERIMETER ===
if [[ -s "$TOS_INPUT" ]]; then
    PAYLOAD_PROJECT=$(grep "^TARGET_PROJECT=" "$TOS_INPUT" | cut -d= -f2 || true)
    PAYLOAD_TRINITY=$(grep "^TARGET_TRINITY=" "$TOS_INPUT" | cut -d= -f2 || true)
    
    if [[ -n "$PAYLOAD_PROJECT" && "$PAYLOAD_PROJECT" != "$TOS_ACTIVE_PROJECT" ]]; then
        echo "🚨 [ERROR] Hallucination detected: payload targets project '$PAYLOAD_PROJECT' but active project is '$TOS_ACTIVE_PROJECT'." >&2
        exit 1
    fi
    if [[ -n "$PAYLOAD_TRINITY" && "$PAYLOAD_TRINITY" != "$TOS_ACTIVE_TRINITY" ]]; then
        echo "🚨 [ERROR] Hallucination detected: payload targets trinity $PAYLOAD_TRINITY but active trinity is $TOS_ACTIVE_TRINITY." >&2
        echo "    Trinity mismatch — rejecting payload." >&2
        exit 1
    fi
fi

# === STAGE 6: DISPATCH ===
MODULE_DIR="$TOS_BIN/modules/$MODULE"
if [[ -x "$MODULE_DIR/soft/${ACTION}.zsh" ]]; then
    TARGET_SCRIPT="$MODULE_DIR/soft/${ACTION}.zsh"
    LOCK_REQUIRED="soft"
elif [[ -x "$MODULE_DIR/hard/${ACTION}.zsh" ]]; then
    TARGET_SCRIPT="$MODULE_DIR/hard/${ACTION}.zsh"
    LOCK_REQUIRED="hard"
else
    echo "🚨 [ERROR] Unknown action: '$ACTION' for module '$MODULE'." >&2
    exit 1
fi

if [[ "$LOCK_REQUIRED" == "hard" && "$TOS_ACTIVE_TRINITY" == "0" ]]; then
    echo "🚨 [ERROR] '$ACTION' requires an active trinity (hard lock)." >&2
    exit 1
fi

echo "🔑 [GATEWAY] $SUDO_USER | $PROJECT_NAME | $MODULE $ACTION $*"

set -o pipefail
{ "$TARGET_SCRIPT" "$PROJECT_NAME" "$@" } 2>&1 | tee "$TOS_CONTEXT"
