#!/bin/zsh
# V68 Fix: Prevent crash on empty payload directories
#[FIXME] delete this line! I need a change in this file to test.
setopt nullglob  
source "$TOS_MNT_ROOT/.local/conf/error_trap.sh"

# Explicitly load token
if [ -f "$TOS_MNT_ROOT/.local/conf/.token" ]; then
     export GH_TOKEN="$(cat "$TOS_MNT_ROOT/.local/conf/.token" | tr -d '\n\r ')"
elif [ -f "$TOS_SANDBOX/.tos/.token" ]; then
     export GH_TOKEN="$(cat "$TOS_SANDBOX/.tos/.token" | tr -d '\n\r ')"
fi

if [ -z "$GH_TOKEN" ]; then
     echo "❌ ERROR: GH_TOKEN is missing. Cannot authenticate with GitHub." >&2
     exit 1
fi

{
     echo "🚀 PUBLISH CYCLE STARTED"
     cd "$TOS_SANDBOX" || exit 1

     for PROJECT_DIR in "$TOS_OUTBOX"/*; do
         [ ! -d "$PROJECT_DIR" ] && continue
         PROJECT="$(basename "$PROJECT_DIR")"

         for PAYLOAD_DIR in "$PROJECT_DIR"/*; do
             [ ! -d "$PAYLOAD_DIR" ] && continue

             if [ ! -f "$PAYLOAD_DIR/title" ]; then
                 echo "❌ ERROR: Malformed payload in $PAYLOAD_DIR. Missing 'title'." >&2
                 continue
             fi

             TITLE="$(cat "$PAYLOAD_DIR/title")"
             BODY="$(cat "$PAYLOAD_DIR/body" 2>/dev/null || echo "")"
             BRANCH="$(cat "$PAYLOAD_DIR/branch" 2>/dev/null || echo "")"
             REF="$(cat "$PAYLOAD_DIR/ref" 2>/dev/null || echo "")"

             echo "📦 Processing Payload: $TITLE (Project: $PROJECT)"
             cd "$TOS_SANDBOX/$PROJECT" || continue

             SUCCESS=false

             if [ -n "$BRANCH" ]; then
                 # --- CODE MODIFICATION (PR ROUTE) ---
                 echo "🌿 Branch detected ($BRANCH). Processing Git Push & PR..."
                 git checkout -B "$BRANCH"
                 git add .

                 COMMIT_MSG="$TITLE\n\n$BODY"
                 [ -n "$REF" ] && COMMIT_MSG="$COMMIT_MSG\n\nFixes #$REF"

                 # V70: GHOST IDENTITY INJECTION
                 export GIT_AUTHOR_NAME="Team of Six (Ghost)"
                 export GIT_AUTHOR_EMAIL="ghost@teamofsix.local"

                 git commit -m "$COMMIT_MSG"

                 set -x
                 if git push origin "$BRANCH" --force; then
                     if [ -n "$REF" ]; then
                         echo "💬 Updating PR #$REF..."
                         gh pr comment "$REF" --body "$BODY" && SUCCESS=true
                     else
                         echo "✨ Creating new Pull Request..."
                         gh pr create --title "$TITLE" --body "$BODY" --head "$BRANCH" && SUCCESS=true
                     fi
                 fi
                 set +x
             else
                 # --- DISCUSSION ONLY (ISSUE ROUTE) ---
                 echo "📝 No branch detected. Routing to GitHub Issues..."
                 set -x
                 if [ -n "$REF" ]; then
                     echo "💬 Commenting on Issue #$REF..."
                     gh issue comment "$REF" --body "$BODY" && SUCCESS=true
                 else
                     echo "✨ Creating new Issue..."
                     gh issue create --title "$TITLE" --body "$BODY" && SUCCESS=true
                 fi
                 set +x
             fi

             # --- TRANSACTION VERIFICATION ---
             if [ "$SUCCESS" = true ]; then
                 rm -rf "$PAYLOAD_DIR"
                 echo "✅ Payload Published and Cleared."
             else
                 echo "❌ ERROR: GitHub API action failed! Payload preserved in outbox."
             fi
             echo "---------------------------------------------------"
         done
     done

     echo "🏁 PUBLISH CYCLE COMPLETE"
} 2>&1 | tee -a /tmp/tos_publish_debug.log | logger -t tos_ghost
