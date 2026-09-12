#!/bin/zsh
# ==============================================================================
# Team of Six - Global Gateway
# ==============================================================================

# Resolve the absolute physical path of this script, chasing any symlinks
REAL_PATH="${0:A}"
# Extract the directory containing the script (e.g., /mnt/team_of_six/.local/bin)
BIN_DIR="${REAL_PATH:h}"
# Go up two levels to set the global mount root (e.g., /mnt/team_of_six)
export TOS_MNT_ROOT="${TOS_MNT_ROOT:-${BIN_DIR:h:h}}"

# === STAGE 0: CALLER LOCATION VERIFICATION ===
# MUST run BEFORE the sudo escalation in Stage 1.
#
# This check inspects the ARCHITECT's working directory. Performing it after
# escalation would mean the Ghost reads the Architect's working tree, which
# the sandbox architecture exists to prevent, and which fails silently on any
# directory the Ghost cannot traverse (mode 0700 homes, mktemp -d, encrypted
# home mounts) — reporting "not a git repository" for a repo that plainly is.
#
# The guard below is skipped when already running as the Ghost, so the block
# is inert on the re-exec that Stage 1 performs.
if [[ "$(id -un)" != "${AI_USER:-team_of_six}" ]]; then
    _CALLER_PROJECT="${1:-}"; _CALLER_MODULE="${2:-}"; _CALLER_ACTION="${3:-}"

    if [[ -n "$_CALLER_PROJECT" ]]; then
        if _CALLER_REMOTE=$(git remote get-url origin 2>/dev/null); then
            if [[ "$_CALLER_REMOTE" != *"team_of_six"* ]]; then
                _CALLER_REPO=$(basename "$_CALLER_REMOTE" .git 2>/dev/null || true)
                if [[ -n "$_CALLER_REPO" && "$_CALLER_REPO" != "$_CALLER_PROJECT" ]]; then
                    echo "🚨 [ERROR] Project mismatch: active is '$_CALLER_REPO' but called with '$_CALLER_PROJECT'." >&2
                    exit 1
                fi
            fi
        else
            # No remote: only `create project` is legal here, and only in a
            # folder whose name matches the requested project.
            if [[ "$_CALLER_MODULE" != "create" || "$_CALLER_ACTION" != "project" ]]; then
                echo "🚨 [ERROR] Not in an initialized repository. Run 'tos $_CALLER_PROJECT create project' first." >&2
                exit 1
            fi
            _CALLER_FOLDER=$(basename "$PWD")
            if [[ "$_CALLER_FOLDER" != "$_CALLER_PROJECT" ]]; then
                echo "🚨 [TYPO GUARD] Current folder name '$_CALLER_FOLDER' does not match requested project name '$_CALLER_PROJECT'." >&2
                exit 1
            fi
        fi
    fi
    unset _CALLER_PROJECT _CALLER_MODULE _CALLER_ACTION _CALLER_REMOTE _CALLER_REPO _CALLER_FOLDER
fi

# === STAGE 1: SECURITY PERIMETER ===
if [[ -z "$SUDO_USER" && "$TOS_TEST_MODE" != "1" ]]; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "${AI_GROUP:-team_of_six}"; then
        echo "🚨 [ACCESS DENIED]" >&2
        exit 1
    fi
    exec sudo -n -u team_of_six "$REAL_PATH" "$@"
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

    # --- GHOST GIT CREDENTIALS (process-scoped) -------------------------------
    # Plain `git` cannot see GH_TOKEN; only `gh` reads it. Without a credential
    # helper the Ghost's fetch/pull/push against an https remote falls back to
    # an interactive username prompt and hangs the gateway.
    #
    # GIT_CONFIG_COUNT/KEY/VALUE (git >= 2.31) injects config through the
    # environment only. Nothing is written to any gitconfig on disk, the
    # setting is inherited by every module the gateway dispatches, and it dies
    # with this process alongside the token itself.
    #
    # A persisted credential in the team_of_six gitconfig would outlive the
    # gateway and defeat the EXIT scrub below — that is why this is deliberately
    # environment-scoped rather than configured once at deploy time.
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0="credential.https://github.com.helper"
    export GIT_CONFIG_VALUE_0='!f() { echo "username=x-access-token"; echo "password=${GH_TOKEN}"; }; f'
fi
export TOS_PARSE_DIR=$(mktemp -d)
trap 'unset GH_TOKEN GITHUB_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0; rm -rf "$TOS_PARSE_DIR"' EXIT INT TERM

# === STAGE 3: ARGUMENT PARSING ===
PROJECT_NAME="$1"; MODULE="$2"; ACTION="$3"
[[ -z "$PROJECT_NAME" || -z "$MODULE" || -z "$ACTION" ]] && exit 1
shift 3

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
{ "$TARGET_SCRIPT" "$PROJECT_NAME" "$@" } 2>&1 | tee "$TOS_CONTEXT" || exit $?
