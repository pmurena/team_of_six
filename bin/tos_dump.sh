#!/bin/zsh
# Team of Six - Diagnostic Runtime Dump (V72)
# Purpose: Generate a full state report for the current V72 architecture.

# 0. Load Central Truth
if [[ -f "/mnt/team_of_six/.local/conf/config" ]]; then
    source "/mnt/team_of_six/.local/conf/config"
else
    echo "❌ ERROR: Could not find config at /mnt/team_of_six/.local/conf/config"
    exit 1
fi

DUMP_DIR="/tmp/tos_dump_$(date +%s)"
DUMP_FILE="$HOME/tos_report_$(date +%Y%m%d).tar.gz"

mkdir -p "$DUMP_DIR"
echo "🔍 Starting Team of Six Runtime Dump..."

# 1. Capture Environment Context
echo "--- Environment Variables ---" > "$DUMP_DIR/env.txt"
env | grep -E "TOS|AI_USER|USER|HOME|SHELL|IPC_DIR" >> "$DUMP_DIR/env.txt"

# 2. Capture V72 Directory Structure
echo "--- Directory Tree: $TOS_MNT_ROOT ---" > "$DUMP_DIR/structure.txt"
ls -R "$TOS_MNT_ROOT" >> "$DUMP_DIR/structure.txt" 2>&1

echo "\n--- Directory Tree: $IPC_DIR ---" >> "$DUMP_DIR/structure.txt"
ls -R "$IPC_DIR" >> "$DUMP_DIR/structure.txt" 2>&1

# 3. Capture Infrastructure & Plugins (The requested expansion)
echo "📦 Backing up code for diagnostics..."
mkdir -p "$DUMP_DIR/src"
cp -r "$TOS_LOCAL/bin" "$DUMP_DIR/src/" 2>/dev/null
cp -r "$TOS_MNT_ROOT/inf" "$DUMP_DIR/src/" 2>/dev/null
cp -r "$TOS_MNT_ROOT/plugins" "$DUMP_DIR/src/" 2>/dev/null

# 4. Capture Configurations (MASKING TOKENS)
mkdir -p "$DUMP_DIR/config"
cp "$TOS_CONF/config" "$DUMP_DIR/config/config" 2>/dev/null
echo "TOKEN_MASKED" > "$DUMP_DIR/config/.token"

# 5. Capture System Logs (Journalctl - Since we moved to logger)
echo "--- Recent System Logs (tos_ghost) ---" > "$DUMP_DIR/ghost_logs.log"
journalctl -t tos_ghost -n 100 --no-pager >> "$DUMP_DIR/ghost_logs.log" 2>&1

# 6. Permission Audit (Crucial for IPC/Sandbox Debugging)
echo "--- Permission Audit ---" > "$DUMP_DIR/permissions.txt"
ls -ld "$TOS_MNT_ROOT" >> "$DUMP_DIR/permissions.txt"
ls -ld "$TOS_LOCAL" >> "$DUMP_DIR/permissions.txt"
ls -ld "$IPC_DIR" >> "$DUMP_DIR/permissions.txt"
ls -ld "$TOS_SANDBOX" >> "$DUMP_DIR/permissions.txt"
ls -l "$TOS_BIN/tos" >> "$DUMP_DIR/permissions.txt"

# 7. Package it up
tar -czf "$DUMP_FILE" -C "$DUMP_DIR" .
rm -rf "$DUMP_DIR"

echo "---"
echo "✅ Dump Complete!"
echo "📦 Report saved to: $DUMP_FILE"
echo "⚠️  Note: Secrets were masked. Run 'tar -ztvf $DUMP_FILE' to see contents."
