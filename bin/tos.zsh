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
            # No remote at all. Every TOS command needs to know which
            # repository it concerns, and the only trustworthy answer is the
            # origin of the clone you are standing in.
            #
            # There is no exception for a bare directory. TOS does not create
            # repositories — the Ghost's GitHub App holds no `administration`
            # permission — so there is no command that could legitimately run
            # here. The Typo Guard that used to cover `create project` was
            # removed with it.
            echo "🚨 [ERROR] Not inside a clone of '$_CALLER_PROJECT'." >&2
            echo "    TOS does not create repositories. Create it yourself, clone it," >&2
            echo "    and run the command from inside the clone:" >&2
            echo "      gh repo create $_CALLER_PROJECT --private" >&2
            echo "      gh repo clone $_CALLER_PROJECT && cd $_CALLER_PROJECT" >&2
            echo "      tos $_CALLER_PROJECT sync project" >&2
            exit 1
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

# The Ghost authenticates as a GitHub App. The key on disk is not itself a
# credential; it mints a token that expires in an hour, so no invocation
# outlives its own secret.
#
# There is no fallback: a PAT cannot complete a Trinity. `write trinity`
# requires the retrospect phase, which requires three approvals, which
# requires an identity that is not the Architect's. Falling back to a PAT
# produces a system that appears to work and can never finish — and it fails
# silently, which is worse than refusing.
#
# The two conditions are checked separately on purpose. An unset path and an
# unreadable file are different mistakes with different fixes, and collapsing
# them is how a silent fallback gets reintroduced.
if [[ -z "${TOS_APP_PEM:-}" ]]; then
    echo "🚨 [ERROR] TOS_APP_PEM is not set." >&2
    echo "    The Ghost authenticates as a GitHub App. Configure it in" >&2
    echo "    conf/config and redeploy. See docs/06-security.md" >&2
    echo "    § The Ghost Identity." >&2
    exit 1
fi
if [[ ! -r "$TOS_APP_PEM" ]]; then
    echo "🚨 [ERROR] The Ghost cannot read its App key at $TOS_APP_PEM" >&2
    echo "    It must be owned by ${AI_USER:-team_of_six}, mode 0400:" >&2
    echo "      sudo chown ${AI_USER:-team_of_six}: $TOS_APP_PEM" >&2
    echo "      sudo chmod 0400 $TOS_APP_PEM" >&2
    exit 1
fi
if true; then
    GH_TOKEN=$("$TOS_BIN/utils/mint_app_token.zsh") || {
        echo "🚨 [ERROR] Could not mint a GitHub App installation token." >&2
        exit 1
    }
    export GH_TOKEN
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
    # --- Isolation boundary (REQ-TOS-AUTH-01) ---------------------------------
    # Environment injection is only airtight if git cannot find a credential
    # anywhere else.
    #
    # NOSYSTEM closes /etc/gitconfig. GLOBAL=/dev/null closes ~/.gitconfig for
    # the Ghost user — which NOSYSTEM leaves open, and which is exactly where a
    # helper lands if anyone runs `gh auth setup-git` as the Ghost.
    #
    # KEY_0 is an EMPTY credential.helper. Git accumulates helpers rather than
    # replacing them, so an empty entry ahead of the real one is what clears
    # anything inherited. Without it an inherited helper is consulted first.
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_CONFIG_COUNT=2
    export GIT_CONFIG_KEY_0="credential.helper"
    export GIT_CONFIG_VALUE_0=""
    export GIT_CONFIG_KEY_1="credential.https://github.com.helper"
    export GIT_CONFIG_VALUE_1='!f() { echo "username=x-access-token"; echo "password=${GH_TOKEN}"; }; f'
fi
export TOS_PARSE_DIR=$(mktemp -d)
trap 'unset GH_TOKEN GITHUB_TOKEN GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1 GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL; rm -rf "$TOS_PARSE_DIR"' EXIT INT TERM

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

# Every module is teed into the outbox, which TRUNCATES — correct for a
# snapshot, wrong for peek. Surgical context injection is additive by
# definition: peek adds one file to a context the Agent already has. Truncating
# means injecting a file and destroying the issue, the diff and the file map in
# the same breath, while printing "This context is appended".
#
# One exception, stated once, rather than a general append mode: only a module
# whose whole purpose is to add to existing context should be able to.
TEE_MODE=""
[[ "$MODULE $ACTION" == "sync peek" ]] && TEE_MODE="-a"

set -o pipefail
{ "$TARGET_SCRIPT" "$PROJECT_NAME" "$@" } 2>&1 | tee ${TEE_MODE} "$TOS_CONTEXT" || exit $?
