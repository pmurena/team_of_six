#!/bin/zsh
# ==============================================================================
# Patch: V68.1 Grand Unification (Refined LLM-Native OS)
# Target: Architectural Hardening, DRY Principles, Smart IPC
# Execution: sudo ./v68_master_patch_refined.sh
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ ERROR: This patch alters the root file system. Please run with sudo."
  exit 1
fi

echo "🚀 Initiating V68.1 Refined Unification Sequence..."

MNT_ROOT="/mnt/team-of-six"
AI_USER="team_of_six"
AI_GROUP="team_of_six"

# ------------------------------------------------------------------------------
# 1. THE 3-TIER IRONCLAD MOUNT (Hardened)
# ------------------------------------------------------------------------------
echo "📂 Provisioning 3-Tier Mount at $MNT_ROOT..."
mkdir -p "$MNT_ROOT"
# [FIXED] 750 ensures ONLY root and team_of_six can enter the mount. Total lockdown.
chown root:"$AI_GROUP" "$MNT_ROOT"
chmod 750 "$MNT_ROOT"

# Tier 1: The Engine & Config (Immutable to Ghost)
mkdir -p "$MNT_ROOT/.local/bin"
mkdir -p "$MNT_ROOT/.local/conf"
chown -R root:"$AI_GROUP" "$MNT_ROOT/.local"
chmod -R 750 "$MNT_ROOT/.local"

# Tier 2: The Sandbox (Ghost's Domain)
# [FIXED] Renamed to .tos_outbox as it's the only metadata directory needed now.
mkdir -p "$MNT_ROOT/sandbox/.tos_outbox"
chown -R "$AI_USER":"$AI_GROUP" "$MNT_ROOT/sandbox"
chmod -R 770 "$MNT_ROOT/sandbox"

# ------------------------------------------------------------------------------
# 2. IMMUTABLE CONFIGURATION
# ------------------------------------------------------------------------------
echo "⚙️  Writing System Configuration..."
# [FIXED] MNT_ROOT is now explicitly defined inside the config for portability.
cat <<EOF > "$MNT_ROOT/.local/conf/config"
export TOS_MNT_ROOT="$MNT_ROOT"
export TOS_SANDBOX="\$TOS_MNT_ROOT/sandbox"
export TOS_LOCAL="\$TOS_MNT_ROOT/.local"
export TOS_BIN="\$TOS_LOCAL/bin"
export TOS_CONF="\$TOS_LOCAL/conf"
export TOS_OUTBOX="\$TOS_SANDBOX/.tos_outbox"
export AI_USER="$AI_USER"
EOF
chmod 640 "$MNT_ROOT/.local/conf/config"

# ------------------------------------------------------------------------------
# 3. ERROR TRAP MODULE (DRY Principle)
# ------------------------------------------------------------------------------
# [FIXED] Extracted to a single sourced file instead of injecting into every script.
cat << 'EOF' > "$MNT_ROOT/.local/conf/error_trap.sh"
set -e
trap 'catch_error $LINENO $?' ZERR
catch_error() {
    local line=$1
    local code=$2
    echo "🚨 FATAL ERROR: Execution failed at line $line (Exit Code: $code)" >&2
    echo "--- Stack Trace ---" >&2
    print -l $funcfiletrace >&2
    exit $code
}
EOF
chmod 640 "$MNT_ROOT/.local/conf/error_trap.sh"

# ------------------------------------------------------------------------------
# 4. ENGINE REWRITE: tos_wrapper.sh (The Executor)
# ------------------------------------------------------------------------------
echo "🧠 Rebuilding Engine: tos_wrapper.sh..."
cat << 'EOF' > "$MNT_ROOT/.local/bin/tos_wrapper.sh"
#!/bin/zsh
source "$TOS_MNT_ROOT/.local/conf/error_trap.sh"

{
    echo "⚡ TASK INPUT STARTED"
    
    # [FIXED] Mutex strictly looks for 'branch' files (code payloads). Allows non-code payloads to stack.
    if [ -n "$(find "$TOS_OUTBOX" -type f -name "branch" -print -quit 2>/dev/null)" ]; then
        echo "⛔ EXECUTION BLOCKED: Pending code payloads (branch) found in $TOS_OUTBOX."
        exit 1
    fi

    cat "$TOS_INPUT"

    # [TODO] find a solution to be able to cd into the project folder to avoid context pollution on error.
    cd "$TOS_SANDBOX" || exit 1
    source "$TOS_INPUT"
    
    EXIT_CODE=$?
    echo "🏁 TASK FINISHED WITH EXIT CODE: $EXIT_CODE"

} 2>&1 | logger -t tos_ghost

[ ${EXIT_CODE:-0} -eq 0 ] && truncate -s 0 "$TOS_INPUT"
exit ${EXIT_CODE:-0}
EOF

# ------------------------------------------------------------------------------
# 5. ENGINE REWRITE: tos_publish.sh (The Governor)
# ------------------------------------------------------------------------------
echo "🧠 Rebuilding Engine: tos_publish.sh..."
cat << 'EOF' > "$MNT_ROOT/.local/bin/tos_publish.sh"
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
EOF

# ------------------------------------------------------------------------------
# 6. SATELLITE CONTROLLER (The Gatekeeper)
# ------------------------------------------------------------------------------
echo "🌉 Building Gatekeeper Controller..."
cat << 'EOF' > "$MNT_ROOT/.local/bin/tos"
#!/bin/zsh

# [FIXED] Config is loaded BEFORE security checks.
source "/mnt/team-of-six/.local/conf/config"

if [ "$USER" != "$AI_USER" ]; then
    echo "❌ ERROR: You must cross the threshold."
    echo "Run: sudo -u $AI_USER /mnt/team-of-six/.local/bin/tos $@"
    exit 1
fi

if [ -z "$SUDO_USER" ]; then
    echo "❌ ERROR: Could not determine calling user. Must be run via sudo."
    exit 1
fi

# [FIXED] IPC folder created dynamically based on config/user variables.
IPC_DIR="/run/${AI_USER}"
mkdir -p "$IPC_DIR" 2>/dev/null || true
export TOS_INPUT="$IPC_DIR/${SUDO_USER}_input.sh"

# [FIXED] UX Improvement: Halts and points Architect to the empty file.
if [ ! -s "$TOS_INPUT" ]; then
    touch "$TOS_INPUT"
    chmod 660 "$TOS_INPUT"
    echo "⚠️  Awaiting Instructions."
    echo "Please write your execution script to: $TOS_INPUT"
    echo "Then re-run this command."
    exit 1
fi

CMD="$1"
[[ $# -gt 0 ]] && shift
case "$CMD" in
    "wrapper") "$TOS_BIN/tos_wrapper.sh" "$@" ;;
    "publish") "$TOS_BIN/tos_publish.sh" "$@" ;;
    "")        "$TOS_BIN/tos_wrapper.sh" && "$TOS_BIN/tos_publish.sh" ;;
    *)         echo "Usage: sudo -u $AI_USER $TOS_BIN/tos [wrapper|publish]" ;;
esac
EOF

# ------------------------------------------------------------------------------
# 7. PERMISSIONS ENFORCEMENT & ALIAS
# ------------------------------------------------------------------------------
chmod 750 "$MNT_ROOT/.local/bin/tos"
chmod 750 "$MNT_ROOT/.local/bin/tos_wrapper.sh"
chmod 750 "$MNT_ROOT/.local/bin/tos_publish.sh"

# [FIXED] Removed symlink. Instructing user on Alias generation.
echo ""
echo "======================================================================"
echo "✅ V68.1 SYSTEM DEPLOYMENT COMPLETE"
echo "======================================================================"
echo "Your LLM-Native OS is secured and live."
echo ""
echo "🔗 REQUIRED NEXT STEP:"
echo "Add this alias to your ~/.zshrc or ~/.bashrc for seamless execution:"
echo ""
echo "    alias tos='sudo -u team_of_six /mnt/team-of-six/.local/bin/tos'"
echo ""
echo "🔧 THE WORKFLOW:"
echo "1. Run 'tos' once to generate your empty IPC file."
echo "2. Edit: nano /run/team_of_six/${SUDO_USER:-$USER}_input.sh"
echo "3. Run 'tos' again to execute."
echo "4. Watch: journalctl -t tos_ghost -f"
echo "======================================================================"
