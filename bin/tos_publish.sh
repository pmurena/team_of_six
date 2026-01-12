#!/bin/zsh
# V55 Publisher (The Governor)
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
    "Requirement")
        echo "⛔ REJECTED: Cannot publish during Requirement phase. No code exists."
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
    "Green"|"Refactor"|"Document"|"Retrospect"|"Done")
        echo "✅ ALLOWED: State is safe for publication."
        ;;
    *)
        echo "⚠️  WARNING: Unknown state '$CURRENT_STATE'. Proceeding with caution."
        ;;
esac

# --- 4. ATOMIC EXECUTION ---
echo "🚀 Executing Atomic Release..."
git add .
git commit -m "$MSG"
git push

echo "✅ Published Successfully."
