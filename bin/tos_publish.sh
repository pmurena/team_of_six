#!/bin/zsh
# Team of Six - Publisher V63.4 (The Lockdown)
set -e

# 1. Re-validate Paths before Sudo
TOS_OUTBOX="${TOS_OUTBOX:-$XDG_STATE_HOME/team_of_six/outbox}"

# 2. EMERGENCY ROOT GUARD
if [[ -z "$TOS_OUTBOX" ]] || [[ "$TOS_OUTBOX" == "/" ]]; then
    echo "⛔ SAFETY BLOCK: TOS_OUTBOX is unsafe ($TOS_OUTBOX). Aborting."
    exit 1
fi

echo "🚀 Governor: Scanning Outbox ($TOS_OUTBOX)..."

# 3. Explicitly pass variables into the AI User context
sudo -u "$AI_USER" \
    TOS_SANDBOX="$TOS_SANDBOX" \
    TOS_OUTBOX="$TOS_OUTBOX" \
    GITHUB_TOKEN="$TOS_GITHUB_TOKEN" \
    zsh << 'SANDBOX'
    
    # Internal Safeguard
    if [[ -z "$TOS_OUTBOX" ]] || [[ "$TOS_OUTBOX" == "/" ]]; then
        echo "⛔ INTERNAL SAFETY BLOCK: Outbox resolved to root inside sandbox."
        exit 1
    fi

    export HOME=/tmp/tos_ghost_$(date +%s)
    mkdir -p "$HOME"
    trap 'rm -rf "$HOME"' EXIT

    ERRORS_OCCURRED=false

    # Use a qualified glob to ensure we only target directories
    for PROJECT_DIR in "${TOS_OUTBOX}"/*(/N); do
        PROJECT_NAME=$(basename "$PROJECT_DIR")
        
        # System Directory Blacklist
        case "$PROJECT_NAME" in
            etc|usr|boot|proc|sys|dev|root|var|bin|lib|lib64|srv|run)
                echo "⛔ SAFETY BLOCK: Skipping system directory '$PROJECT_NAME'."
                continue ;;
        esac

        if [ ! -d "$TOS_SANDBOX/$PROJECT_NAME" ]; then
            echo "⛔ PUBLISH FAILED: Sandbox missing for $PROJECT_NAME."
            ERRORS_OCCURRED=true
            continue
        fi

        cd "$TOS_SANDBOX/$PROJECT_NAME"
        
        # Verify we are NOT at root
        if [[ "$(pwd)" == "/" ]]; then
            echo "⛔ SAFETY BLOCK: Path resolve failure. Aborting project."
            continue
        fi

        git config --local user.name "Team of Six"
        git config --local user.email "team_of_six@internal"
        git config --local url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

        for PAYLOAD in "$PROJECT_DIR"/*(/N); do
            echo "\n📦 Processing: [$PROJECT_NAME] -> $(basename "$PAYLOAD")"
            
            if [ ! -s "$PAYLOAD/title" ] || [ ! -s "$PAYLOAD/body" ]; then
                echo "⛔ PUBLISH FAILED: Missing title/body."
                ERRORS_OCCURRED=true
                continue
            fi

            TITLE=$(cat "$PAYLOAD/title")
            BODY=$(cat "$PAYLOAD/body")

            if [ -s "$PAYLOAD/branch" ]; then
                BRANCH=$(cat "$PAYLOAD/branch")
                git checkout -B "$BRANCH"
                git add .
                git commit -m "$TITLE" -m "$BODY"
                git push -u origin "$BRANCH"
                # PR logic...
            else
                # Issue logic...
            fi
            rm -rf "$PAYLOAD"
        done
        rmdir "$PROJECT_DIR" 2>/dev/null || true
    done

    [ "$ERRORS_OCCURRED" = true ] && exit 1
SANDBOX
