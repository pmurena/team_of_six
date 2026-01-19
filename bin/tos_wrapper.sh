#!/bin/zsh
# V55 Logic Engine (The Wrapper) - Fixed Logic
# Separates Context Logging from Script Execution.

set -o pipefail

# --- PATH RESOLUTION ---
BIN_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="$(dirname "$BIN_DIR")"

# --- DEFAULTS ---
USER_HOME=$HOME

# GLOBAL CONFIG (The Team)
TOS_HOME="$USER_HOME/.team_of_six"
INPUT_FILE="$TOS_HOME/tos_input.sh"
OUTPUT_FILE="$TOS_HOME/tos_output.log"
LESSONS_FILE="$TOS_HOME/tos_lessons.md"
CONFIG_FILE="$TOS_HOME/tos_config"
LAST_EXIT_FILE="$TOS_HOME/tos_last_exit"

# --- ARGUMENT PARSING ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --input|-i) INPUT_FILE="$2"; shift ;;
        --output|-o) OUTPUT_FILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- SELF-HEALING (Global) ---
if [ ! -d "$TOS_HOME" ]; then
    mkdir -p "$TOS_HOME"
    touch "$INPUT_FILE" "$OUTPUT_FILE" "$LAST_EXIT_FILE" "$LESSONS_FILE"
    echo "AI_USER=team_of_six" > "$CONFIG_FILE"
fi

# Load Config
source "$CONFIG_FILE"

# --- LOCAL STATE RESOLUTION ---
TARGET_DIR="$(pwd)"
LOCAL_TOS="$TARGET_DIR/.tos"
LOCAL_STATE_FILE="$LOCAL_TOS/state"
LOCAL_OBJECTIONS="$LOCAL_TOS/objections.md"
LOCAL_FEATURES="$LOCAL_TOS/features.md"

# --- 0. THE IRON GATE (Local Veto) ---
if [ -s "$LOCAL_OBJECTIONS" ]; then
    echo "⛔ SYSTEM HALTED: Unresolved Objections detected in local project."
    echo "    See: $LOCAL_OBJECTIONS"
    echo "    Action: You must manually resolve and clear the objections file."
    exit 1
fi

# --- LOG LOGIC ---
PREV_EXIT=0
if [ -f "$LAST_EXIT_FILE" ]; then
    PREV_EXIT=$(cat "$LAST_EXIT_FILE")
fi

# --- STEP 1: DUMP CONTEXT TO LOG (Do NOT Execute) ---
{
    if [ "$PREV_EXIT" -ne 0 ]; then
        echo "--- [APPENDING TO LOG: PREVIOUS EXIT $PREV_EXIT] ---"
    fi
    
    echo "# --- 💎 V55 GEM (IDENTITY) ---"
    cat "$REPO_ROOT/tos_gem.md"
    echo ""
    echo "# --- 📋 PROJECT BACKLOG ---"
    cat "$LOCAL_FEATURES" 2>/dev/null || echo "No local backlog (.tos/features.md not found)."
    echo ""
    echo "# --- 🛡️ PROJECT OBJECTIONS ---"
    cat "$LOCAL_OBJECTIONS" 2>/dev/null || echo "None."
    echo ""
    echo "# --- 📚 TEAM LESSONS (GLOBAL) ---"
    cat "$LESSONS_FILE" 2>/dev/null || echo "None."
    echo ""
    echo "# --- 🧠 PROJECT STATE ---"
    if [ -f "$LOCAL_STATE_FILE" ]; then
        echo "Current TDD Phase: $(cat "$LOCAL_STATE_FILE")"
    else
        echo "Current TDD Phase: Genesis (No State File)"
    fi
    echo ""
    echo "# --- 📂 TARGET CONTEXT ---"
    echo "Target Directory: $TARGET_DIR"
    echo ""
    echo "# --- ⚡ TASK INPUT ---"
    if [ -s "$INPUT_FILE" ]; then
        cat "$INPUT_FILE"
    else
        echo "No input provided. Awaiting orders."
    fi
    echo ""
    echo "# --- 🚀 EXECUTION LOG ---"
} > "$OUTPUT_FILE"

# --- STEP 2: PREPARE PAYLOAD ---
# We copy the input script to a temp file that is world-readable
# so the AI User can execute it without pipe permissions issues.
TMP_SCRIPT=$(mktemp)
if [ -s "$INPUT_FILE" ]; then
    cat "$INPUT_FILE" > "$TMP_SCRIPT"
else
    echo "echo 'No input commands to execute.'" > "$TMP_SCRIPT"
fi
chmod 644 "$TMP_SCRIPT"

# --- STEP 3: EXECUTE (Sudo) ---
echo -n "🏥 System Check... "
if ! sudo -n -u "$AI_USER" git --version >/dev/null 2>&1; then
    echo "❌ FAILED"
    echo "    Error: Sudo Tunnel blocked. Check /etc/sudoers.d/team_of_six."
    rm "$TMP_SCRIPT"
    exit 1
fi
echo "✓"

sudo -u "$AI_USER" zsh -c "
    # TUNNEL DEFINITION (Inside the AI User Shell)
    
    # Version Control uses REAL_USER (Local config)
    git() { sudo -u $REAL_USER git \"\$@\"; }
    gh() { sudo -u $REAL_USER gh \"\$@\"; }
    
    # Execution uses REAL_USER
    conda() { sudo -u $REAL_USER conda \"\$@\"; }
    python() { sudo -u $REAL_USER python \"\$@\"; }
    pytest() { sudo -u $REAL_USER python -m pytest \"\$@\"; } 
    
    # Environment Passthrough
    export PATH=\"$PATH\"
    export TERM=\"xterm-256color\"
    
    # MOVE TO TARGET DIRECTORY (CRITICAL)
    cd \"$TARGET_DIR\" || exit 1

    # Run the payload
    source \"$TMP_SCRIPT\"
" >> "$OUTPUT_FILE" 2>&1

EXIT_CODE=$?

# Cleanup
rm -f "$TMP_SCRIPT"

# --- STEP 4: CLEANUP ---
echo "$EXIT_CODE" > "$LAST_EXIT_FILE"

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "✅ Success. Input cleared."
    truncate -s 0 "$INPUT_FILE"
else
    echo "⚠️  Task Failed (Exit $EXIT_CODE). Input preserved for debugging."
    echo "    See $OUTPUT_FILE for details."
fi

exit $EXIT_CODE
