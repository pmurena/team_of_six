#!/bin/zsh
# Team of Six - Publisher V63 (XDG Native)
set -e

if [ -z "$TOS_CONF" ]; then
    echo "⛔ ERROR: TOS_CONF not set. Publisher must be executed via tos_controller.sh"
    exit 1
fi

echo "🚀 Governor: Scanning Outbox ($TOS_OUTBOX)..."

sudo -u "$AI_USER" GITHUB_TOKEN="$TOS_GITHUB_TOKEN" zsh <<SANDBOX
    export TOS_SANDBOX="$TOS_SANDBOX"
    export TOS_OUTBOX="$TOS_OUTBOX"
    # 1. Provide a writable home for the "Homeless Ghost"
    export HOME=/tmp/tos_ghost_$(date +%s)
    mkdir -p "$HOME"

    # 2. Proceed with Git operations
    cd "$TOS_SANDBOX/$PROJECT_NAME"
    
    # Using --local is still safer to avoid any global lock attempts
    git config --local user.name "Team of Six"
    git config --local user.email "team_of_six@internal" 
    git config --local url. "https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    ERRORS_OCCURRED=false
    PAYLOADS_FOUND=false

    for PROJECT_DIR in "\$TOS_OUTBOX"/*(/N); do
        PROJECT_NAME=\$(basename "\$PROJECT_DIR")
        for PAYLOAD in "\$PROJECT_DIR"/*(/N); do
            PAYLOADS_FOUND=true
            echo "\n📦 Processing: [\$PROJECT_NAME] -> \$(basename "\$PAYLOAD")"
            
            HAS_REF=false;     [ -s "\$PAYLOAD/ref" ] && HAS_REF=true
            HAS_BRANCH=false;  [ -s "\$PAYLOAD/branch" ] && HAS_BRANCH=true
            HAS_TITLE=false;   [ -s "\$PAYLOAD/title" ] && HAS_TITLE=true
            HAS_BODY=false;    [ -s "\$PAYLOAD/body" ] && HAS_BODY=true

            if [ "\$HAS_BODY" = false ] || [ "\$HAS_TITLE" = false ]; then
                echo "⛔ PUBLISH FAILED: Missing title or body."
                ERRORS_OCCURRED=true
                continue
            fi

            BODY=\$(cat "\$PAYLOAD/body")
            TITLE=\$(cat "\$PAYLOAD/title")

            if [ ! -d "\$TOS_SANDBOX/\$PROJECT_NAME" ]; then
                echo "⛔ PUBLISH FAILED: Sandbox directory missing."
                ERRORS_OCCURRED=true
                continue
            fi
            
            cd "\$TOS_SANDBOX/\$PROJECT_NAME"

            if [ "\$HAS_BRANCH" = true ]; then
                BRANCH=\$(cat "\$PAYLOAD/branch")
                git checkout -B "\$BRANCH"
                git add .
                git commit -m "\$TITLE" -m "\$BODY"
                git push -u origin "\$BRANCH"

                if [ "\$HAS_REF" = true ]; then
                    REF=\$(cat "\$PAYLOAD/ref")
                    gh pr comment "\$REF" --body "\$BODY"
                else
                    NEW_REF=\$(gh pr create --title "\$TITLE" --body "\$BODY" --head "\$BRANCH" | grep -oE '[0-9]+$')
                fi
            else
                if [ "\$HAS_REF" = true ]; then
                    REF=\$(cat "\$PAYLOAD/ref")
                    gh issue comment "\$REF" --body "\$BODY"
                else
                    NEW_REF=\$(gh issue create --title "\$TITLE" --body "\$BODY" | grep -oE '[0-9]+$')
                fi
            fi
            rm -rf "\$PAYLOAD"
        done
        rmdir "\$PROJECT_DIR" 2>/dev/null || true
    done

    if [ "\$ERRORS_OCCURRED" = true ]; then exit 1; fi
SANDBOX
