#!/bin/zsh
source "$TOS_MNT_ROOT/.local/conf/error_trap.sh"

{
    echo "🚀 PUBLISH CYCLE STARTED"
    cd "$TOS_SANDBOX" || exit 1

    for PROJECT_DIR in "$TOS_OUTBOX"/*; do
        [ ! -d "$PROJECT_DIR" ] && continue
        PROJECT="$(basename "$PROJECT_DIR")"
        
        for PAYLOAD_DIR in "$PROJECT_DIR"/*; do
            [ ! -d "$PAYLOAD_DIR" ] && continue
            
            # [FIXED] Strict failing. No more dummy defaulting.
            if [ ! -f "$PAYLOAD_DIR/title" ]; then
                echo "❌ ERROR: Malformed payload in $PAYLOAD_DIR. Missing 'title'." >&2
                continue
            fi
            
            TITLE="$(cat "$PAYLOAD_DIR/title")"
            BODY="$(cat "$PAYLOAD_DIR/body" 2>/dev/null || echo "")"
            BRANCH="$(cat "$PAYLOAD_DIR/branch" 2>/dev/null || echo "")"
            REF="$(cat "$PAYLOAD_DIR/ref" 2>/dev/null || echo "")"
            
            COMMIT_MSG="$TITLE\n\n$BODY"
            [ -n "$REF" ] && COMMIT_MSG="$COMMIT_MSG\n\nFixes #$REF"

            echo "📦 Processing Payload: $TITLE"
            cd "$TOS_SANDBOX/$PROJECT" || continue

            if [ -n "$BRANCH" ]; then
                git checkout -B "$BRANCH"
                git add .
                git commit -m "$COMMIT_MSG"
                git push origin "$BRANCH" --force
            else
                echo "📝 Logging non-code issue: $TITLE"
            fi

            rm -rf "$PAYLOAD_DIR"
            echo "✅ Payload Published and Cleared."
        done
    done

    echo "🏁 PUBLISH CYCLE COMPLETE"
} 2>&1 | logger -t tos_ghost
