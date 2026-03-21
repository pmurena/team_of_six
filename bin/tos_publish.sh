#!/bin/zsh
# Team of Six - Publisher V64 (Lean Governor)
set -e

# Safety check: Ensure the Controller provided the paths
if [[ -z "$TOS_OUTBOX" ]] || [[ "$TOS_OUTBOX" == "/" ]]; then
    echo "⛔ SAFETY BLOCK: Publisher received unsafe Outbox path ($TOS_OUTBOX)"
    exit 1
fi

echo "🚀 Governor: Scanning Outbox ($TOS_OUTBOX)..."

# Git Identity (Local to the current sandbox project)
git config --local user.name "Team of Six"
git config --local user.email "team_of_six@internal"
git config --local url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

ERRORS_OCCURRED=false

# 1. Iterate through Project Payloads in Outbox
for PROJECT_DIR in "$TOS_OUTBOX"/*(/N); do
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    
    # 2. Enter Project Sandbox
    if [ ! -d "$TOS_SANDBOX/$PROJECT_NAME" ]; then
        echo "⛔ PUBLISH FAILED: Sandbox missing for $PROJECT_NAME"
        ERRORS_OCCURRED=true
        continue
    fi

    cd "$TOS_SANDBOX/$PROJECT_NAME"
    echo "📍 Project: $PROJECT_NAME"

    # 3. Process Individual Payloads
    for PAYLOAD in "$PROJECT_DIR"/*(/N); do
        echo "📦 Payload: $(basename "$PAYLOAD")"
        
        # Verify Mutex files
        if [ ! -s "$PAYLOAD/title" ] || [ ! -s "$PAYLOAD/body" ]; then
            echo "⛔ PUBLISH FAILED: Missing title or body."
            ERRORS_OCCURRED=true
            continue
        fi

        TITLE=$(cat "$PAYLOAD/title")
        BODY=$(cat "$PAYLOAD/body")

        # 4. Route: Codebase Modification vs Discussion
        if [ -s "$PAYLOAD/branch" ]; then
            BRANCH=$(cat "$PAYLOAD/branch")
            echo "🌿 Branch: $BRANCH"
            git checkout -B "$BRANCH"
            git add .
            git commit -m "$TITLE" -m "$BODY"
            git push -u origin "$BRANCH"

            if [ -s "$PAYLOAD/ref" ]; then
                REF=$(cat "$PAYLOAD/ref")
                gh pr comment "$REF" --body "$BODY"
            else
                gh pr create --title "$TITLE" --body "$BODY" --head "$BRANCH" --fill
            fi
        else
            # Issue Route
            if [ -s "$PAYLOAD/ref" ]; then
                REF=$(cat "$PAYLOAD/ref")
                gh issue comment "$REF" --body "$BODY"
            else
                gh issue create --title "$TITLE" --body "$BODY"
            fi
        fi
        rm -rf "$PAYLOAD"
    done
    rmdir "$PROJECT_DIR" 2>/dev/null || true
done

[ "$ERRORS_OCCURRED" = true ] && exit 1
