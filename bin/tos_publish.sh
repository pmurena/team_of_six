#!/bin/zsh
# V56 Publisher (The Governor)
# Enforces State Rules before pushing code.

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

# --- CONTEXT ---
TARGET_DIR="$(pwd)"
LOCAL_TOS="$TARGET_DIR/.tos"
LOCAL_STATE_FILE="$LOCAL_TOS/state"
LOCAL_OBJECTIONS="$LOCAL_TOS/objections.md"

# --- 1. LOCALITY CHECK ---
if [ ! -d "$LOCAL_TOS" ]; then
    echo "⛔ REJECTED: Not a Team of Six project (No .tos/ directory found)."
    exit 1
fi

# --- 2. VETO CHECK ---
if [ -s "$LOCAL_OBJECTIONS" ]; then
    echo "⛔ REJECTED: Unresolved Objections in $LOCAL_OBJECTIONS"
    exit 1
fi

# --- 3. STATE PHYSICS (THE RULES) ---
CURRENT_STATE=$(cat "$LOCAL_STATE_FILE" 2>/dev/null || echo "Unknown")
echo "🔍 Governance Check: Phase [$CURRENT_STATE]"

case "$CURRENT_STATE" in
    "Requirement"|"Scoping")
        echo "⛔ REJECTED: Cannot publish during Scoping/Requirement phase. No code exists."
        exit 1
        ;;
    "Scaffolding")
        echo "✅ ALLOWED: Initial commit permitted."
        ;;
    "Red")
        echo "⛔ REJECTED: Phase is RED. You cannot publish failing code."
        echo "    Action: Fix tests to reach GREEN state first."
        exit 1
        ;;
    "Green"|"Refactor"|"Document"|"Done"|"Retrospect")
        echo "✅ ALLOWED: State is safe for publication."
        ;;
    *)
        echo "⚠️  WARNING: Unknown state '$CURRENT_STATE'. Proceeding with caution."
        ;;
esac

# --- 4. ATOMIC EXECUTION (Project PR) ---
echo "🚀 Executing Atomic Release (Project: $TARGET_DIR)..."
TIMESTAMP=$(date +%Y%m%d%H%M)
BRANCH="release-$TIMESTAMP"

# Execute Git Operations (Direct Access)
(
    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
    git add .
    git commit -m "$MSG"
    git push --set-upstream origin "$BRANCH"
    
    # Create PR using GitHub CLI
    echo "      📝 Creating PR for Project..."
    gh pr create --title "$MSG" --body "Atomic Release triggered by state: $CURRENT_STATE" --fill
)

# --- 5. RETROSPECT EXTENSION (Tri-Repo) ---
if [ "$CURRENT_STATE" == "Retrospect" ]; then
    echo "🔄 [Retrospect] Scanning Sibling Repositories for Changes..."
    
    # Define Siblings
    SIBLINGS=("../llm_agents" "../team_of_six")
    
    for REPO in "${SIBLINGS[@]}"; do
        if [ -d "$REPO" ]; then
            REPO_NAME=$(basename "$REPO")
            echo "   🔎 Checking $REPO_NAME..."
            
            # Check for changes (Dirty State)
            if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
                echo "      ⚠️  Changes detected in $REPO_NAME. Processing..."
                
                # Branch Name for PR
                TIMESTAMP=$(date +%Y%m%d%H%M)
                BRANCH="retro-update-$TIMESTAMP"
                
                # Execute Git Operations
                (
                    cd "$REPO"
                    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
                    git add .
                    git commit -m "Retro Update: $MSG (from $TARGET_DIR)"
                    git push --set-upstream origin "$BRANCH"
                    
                    # Create PR using GitHub CLI
                    echo "      📝 Creating PR for $REPO_NAME..."
                    gh pr create --title "Retro Update: $MSG" --body "Automated Retrospective Update triggered by project: $TARGET_DIR" --fill
                )
                echo "      ✅ $REPO_NAME Processed."
            else
                echo "      ✓ Clean."
            fi
        else
            echo "   ⚠️  Sibling $REPO not found."
        fi
    done
fi

echo "✅ Published Successfully."
