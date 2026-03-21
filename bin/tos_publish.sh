#!/bin/zsh
# Team of Six - Publisher V63.2 (Hardened Identity)
set -e

if [ -z "$TOS_CONF" ]; then
    echo "⛔ ERROR: TOS_CONF not set. Publisher must be executed via tos_controller.sh"
    exit 1
fi

echo "🚀 Governor: Scanning Outbox ($TOS_OUTBOX)..."

# Use quoted 'SANDBOX' to prevent the parent shell from expanding $(pwd) or $VARS prematurely
sudo -u "$AI_USER" GITHUB_TOKEN="$TOS_GITHUB_TOKEN" zsh << 'SANDBOX'
    # 1. Resolve the Homeless Ghost Paradox
    # Provides a writable space for git locks and temporary configs
    export HOME=/tmp/tos_ghost_$(date +%s)
    mkdir -p "$HOME"
    trap 'rm -rf "$HOME"' EXIT

    export TOS_SANDBOX="$TOS_SANDBOX"
    export TOS_OUTBOX="$TOS_OUTBOX"
    
    ERRORS_OCCURRED=false

    for PROJECT_DIR in "$TOS_OUTBOX"/*(/N); do
        PROJECT_NAME=$(basename "$PROJECT_DIR")
        
        if [ ! -d "$TOS_SANDBOX/$PROJECT_NAME" ]; then
            echo "⛔ PUBLISH FAILED: Sandbox directory for $PROJECT_NAME missing."
            ERRORS_OCCURRED=true
            continue
        fi

        # Move into the specific project sandbox
        cd "$TOS_SANDBOX/$PROJECT_NAME"
        echo "📍 Project Context: $(pwd)"

        # 2. Local Identity Injection (Scoped to the .git folder to avoid global locks)
        git config --local user.name "Team of Six"
        git config --local user.email "team_of_six@internal"
        git config --local url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

        for PAYLOAD in "$PROJECT_DIR"/*(/N); do
            echo "\n📦 Processing Payload: $(basename "$PAYLOAD")"
            
            HAS_REF=false;     [ -s "$PAYLOAD/ref" ] && HAS_REF=true
            HAS_BRANCH=false;  [ -s "$PAYLOAD/branch" ] && HAS_BRANCH=true
            HAS_TITLE=false;   [ -s "$PAYLOAD/title" ] && HAS_TITLE=true
            HAS_BODY=false;    [ -s "$PAYLOAD/body" ] && HAS_BODY=true

            if [ "$HAS_BODY" = false ] || [ "$HAS_TITLE" = false ]; then
                echo "⛔ PUBLISH FAILED: Missing title or body in $PAYLOAD"
                ERRORS_OCCURRED=true
                continue
            fi

            TITLE=$(cat "$PAYLOAD/title")
            BODY=$(cat "$PAYLOAD/body")

            if [ "$HAS_BRANCH" = true ]; then
                BRANCH=$(cat "$PAYLOAD/branch")
                echo "🌿 Branching: $BRANCH"
                git checkout -B "$BRANCH"
                git add .
                git commit -m "$TITLE" -m "$BODY"
                git push -u origin "$BRANCH"

                if [ "$HAS_REF" = true ]; then
                    REF=$(cat "$PAYLOAD/ref")
                    gh pr comment "$REF" --body "$BODY"
                else
                    # Create PR and capture the reference for future comments
                    NEW_REF=$(gh pr create --title "$TITLE" --body "$BODY" --head "$BRANCH" --fill | grep -oE '[0-9]+$')
                    echo "$NEW_REF" > "$PAYLOAD/ref" # Optional persistence if payload isn't deleted
                fi
            else
                # Discussion-only route (Issues)
                if [ "$HAS_REF" = true ]; then
                    REF=$(cat "$PAYLOAD/ref")
                    gh issue comment "$REF" --body "$BODY"
                else
                    gh issue create --title "$TITLE" --body "$BODY"
                fi
            fi
            # Cleanup processed payload
            rm -rf "$PAYLOAD"
        done
        # Cleanup project outbox if empty
        rmdir "$PROJECT_DIR" 2>/dev/null || true
    done

    if [ "$ERRORS_OCCURRED" = true ]; then exit 1; fi
SANDBOX
