#!/bin/zsh
# V56 Publisher (The Governor)
# Architecture: Direct Read (Open Permissions)

set -e

# --- ARGS ---
MSG=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m) MSG="$2"; shift ;;
        *) echo "Usage: team_of_six publish -m 'Commit Message'"; exit 1 ;;
    esac
    shift
done

if [ -z "$MSG" ]; then
    echo "❌ Error: Commit message required (-m)."
    exit 1
fi

TARGET_DIR="$(pwd)"
LOCAL_TOS="$TARGET_DIR/.tos"
LOCAL_STATE_FILE="$LOCAL_TOS/state"
LOCAL_OBJECTIONS="$LOCAL_TOS/objections.md"

# --- 1. CONTEXT RESOLUTION ---
# Attempt to load config from known locations to get REAL_USER
if [ -f "$HOME/.team_of_six/tos_config" ]; then
    source "$HOME/.team_of_six/tos_config"
elif [ -n "$SUDO_USER" ] && [ -f "/home/$SUDO_USER/.team_of_six/tos_config" ]; then
    source "/home/$SUDO_USER/.team_of_six/tos_config"
fi

# Fallback derivation
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(stat -c '%U' "$TARGET_DIR" 2>/dev/null || echo "pat")
fi

# Locate the Bridge
BRIDGE_DIR="/home/$REAL_USER/.team_of_six"

# Load Secrets (Direct Read)
if [ -f "$BRIDGE_DIR/.token" ]; then
    source "$BRIDGE_DIR/.token"
else
    echo "❌ Error: Could not read token at $BRIDGE_DIR/.token"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: Token file sourced, but GITHUB_TOKEN is empty."
    exit 1
fi

# --- 2. LOCALITY CHECK ---
if [ ! -d "$LOCAL_TOS" ]; then
    echo "⛔ REJECTED: Not a Team of Six project (No .tos/ directory found)."
    exit 1
fi

# --- 3. VETO CHECK ---
if [ -s "$LOCAL_OBJECTIONS" ]; then
    echo "⛔ REJECTED: Unresolved Objections in $LOCAL_OBJECTIONS"
    exit 1
fi

# --- 4. STATE PHYSICS ---
CURRENT_STATE=$(cat "$LOCAL_STATE_FILE" 2>/dev/null || echo "Unknown")
echo "🔍 Governance Check: Phase [$CURRENT_STATE]"

case "$CURRENT_STATE" in
    "Requirement"|"Red")
        echo "⛔ REJECTED: Cannot publish in state [$CURRENT_STATE]."
        exit 1
        ;;
    *)
        echo "✅ ALLOWED: State is safe for publication."
        ;;
esac

# --- 5. ATOMIC EXECUTION ---
echo "🚀 Executing Atomic Release..."
TIMESTAMP=$(date +%Y%m%d%H%M)
BRANCH="release-$TIMESTAMP"

# Execute Git (Authenticated)
git config user.name "Team of Six"
git config user.email "team_of_six@internal"
git config url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

# Branch & Push
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
git add .
git commit -m "$MSG"
git push --set-upstream origin "$BRANCH"

echo "      📝 Creating PR..."
gh pr create --title "$MSG" --body "Atomic Release triggered by state: $CURRENT_STATE" --fill

# --- 6. RETROSPECT EXTENSION (Tri-Repo) ---
# [FIX] Changed '==' to '=' for POSIX compatibility
if [ "$CURRENT_STATE" = "Retrospect" ]; then
    echo "🔄 [Retrospect] Scanning Sibling Repositories..."
    SIBLINGS=("../llm_agents" "../team_of_six")
    
    # Pre-calculate absolute target path
    ABS_TARGET=$(cd "$TARGET_DIR" && pwd -P)

    for REPO in "${SIBLINGS[@]}"; do
        if [ -d "$REPO" ]; then
            REPO_NAME=$(basename "$REPO")
            echo "   🔎 Checking $REPO_NAME..."
            
            # [FIX] Robust Self Check (Inode/Path based)
            ABS_REPO=$(cd "$REPO" && pwd -P)
            if [ "$ABS_REPO" = "$ABS_TARGET" ]; then
                echo "      ✓ Self (Already Processed)."
                continue
            fi

            if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
                echo "      ⚠️  Changes detected in $REPO_NAME. Processing..."
                (
                    cd "$REPO"
                    git config user.name "Team of Six"
                    git config user.email "team_of_six@internal"
                    git config url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
                    
                    BRANCH="retro-$TIMESTAMP"
                    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
                    git add .
                    git commit -m "Retro Update: $MSG"
                    git push --set-upstream origin "$BRANCH"
                    gh pr create --title "Retro Update: $MSG" --body "Automated Retrospective" --fill
                )
                echo "      ✅ $REPO_NAME Processed."
            else
                echo "      ✓ Clean."
            fi
        fi
    done
fi
echo "✅ Published Successfully."
