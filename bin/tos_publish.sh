#!/bin/zsh
# Team of Six - Publisher V63.3 (Safety Hardened)
set -e

# 1. Resolve Paths (Redundant check for subshell safety)
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export TOS_OUTBOX="${TOS_OUTBOX:-$XDG_STATE_HOME/team_of_six/outbox}"

# 2. EMERGENCY SAFETY GUARD
if [[ "$TOS_OUTBOX" == "/" ]] || [[ -z "$TOS_OUTBOX" ]]; then
    echo "⛔ SAFETY BLOCK: TOS_OUTBOX is unset or pointing to root. Aborting to protect system."
    exit 1
fi

if [ -z "$TOS_CONF" ]; then
    echo "⛔ ERROR: TOS_CONF not set. Execute via tos_controller.sh"
    exit 1
fi

echo "🚀 Governor: Scanning Outbox ($TOS_OUTBOX)..."

sudo -u "$AI_USER" GITHUB_TOKEN="$TOS_GITHUB_TOKEN" zsh << 'SANDBOX'
    # Provide a writable home and re-import paths
    export HOME=/tmp/tos_ghost_$(date +%s)
    mkdir -p "$HOME"
    trap 'rm -rf "$HOME"' EXIT

    # Explicitly re-set these to ensure they aren't inherited as '/' from the environment
    TOS_SANDBOX_INTERNAL="$TOS_SANDBOX"
    TOS_OUTBOX_INTERNAL="$TOS_OUTBOX"

    ERRORS_OCCURRED=false

    # Only proceed if Outbox exists
    if [ ! -d "$TOS_OUTBOX_INTERNAL" ]; then
        echo "ℹ️  Outbox directory does not exist yet."
        exit 0
    fi

    for PROJECT_DIR in "$TOS_OUTBOX_INTERNAL"/*(/N); do
        PROJECT_NAME=$(basename "$PROJECT_DIR")
        
        # Guard against processing system dirs if globbing somehow fails
        if [[ "$PROJECT_NAME" == "etc" || "$PROJECT_NAME" == "usr" || "$PROJECT_NAME" == "boot" ]]; then
            echo "⛔ SAFETY BLOCK: Attempted to process system directory '$PROJECT_NAME'. Skipping."
            continue
        fi

        if [ ! -d "$TOS_SANDBOX_INTERNAL/$PROJECT_NAME" ]; then
            echo "⛔ PUBLISH FAILED: Sandbox directory missing for $PROJECT_NAME."
            ERRORS_OCCURRED=true
            continue
        fi

        cd "$TOS_SANDBOX_INTERNAL/$PROJECT_NAME"
        
        # Ensure we are actually in the sandbox
        if [[ "$(pwd)" == "/" ]]; then
            echo "⛔ SAFETY BLOCK: CD failed to sandbox. Currently at root. Aborting PROJECT."
            continue
        fi

        git config --local user.name "Team of Six"
        git config --local user.email "team_of_six@internal"
        git config --local url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

        for PAYLOAD in "$PROJECT_DIR"/*(/N); do
            echo "\n📦 Processing Payload: $(basename "$PAYLOAD")"
            
            HAS_TITLE=false;   [ -s "$PAYLOAD/title" ] && HAS_TITLE=true
            HAS_BODY=false;    [ -s "$PAYLOAD/body" ] && HAS_BODY=true

            if [ "$HAS_BODY" = false ] || [ "$HAS_TITLE" = false ]; then
                echo "⛔ PUBLISH FAILED: Missing title/body in $PAYLOAD"
                ERRORS_OCCURRED=true
                continue
            fi

            TITLE=$(cat "$PAYLOAD/title")
            BODY=$(cat "$PAYLOAD/body")
            HAS_BRANCH=false;  [ -s "$PAYLOAD/branch" ] && HAS_BRANCH=true

            if [ "$HAS_BRANCH" = true ]; then
                BRANCH=$(cat "$PAYLOAD/branch")
                git checkout -B "$BRANCH"
                git add .
                git commit -m "$TITLE" -m "$BODY"
                git push -u origin "$BRANCH"
                # PR logic remains same...
            else
                # Issue logic remains same...
            fi
            rm -rf "$PAYLOAD"
        done
        rmdir "$PROJECT_DIR" 2>/dev/null || true
    done

    if [ "$ERRORS_OCCURRED" = true ]; then exit 1; fi
SANDBOX
