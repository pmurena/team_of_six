#!/bin/zsh
# Team of Six - Diagnostic Runtime Dump (V64.3)
# Purpose: Generate a full state report for debugging permission/path issues.

DUMP_DIR="/tmp/tos_dump_$(date +%s)"
DUMP_FILE="$HOME/docs/tos_report_$(date +%Y%m%d).tar.gz"

mkdir -p "$DUMP_DIR"
echo "🔍 Starting Team of Six Runtime Dump..."

# 1. Capture Environment Variables (XDG & TOS specific)
echo "--- Environment Variables ---" > "$DUMP_DIR/env.txt"
env | grep -E "XDG|TOS|AI_USER|USER|HOME|SHELL" >> "$DUMP_DIR/env.txt"

# 2. Capture Directory Structures (Recursive ls)
echo "--- Directory Tree: /opt/team_of_six ---" > "$DUMP_DIR/structure.txt"
ls -R /opt/team_of_six >> "$DUMP_DIR/structure.txt" 2>&1

echo "\n--- Directory Tree: /mnt/team_of_six/.tos ---" >> "$DUMP_DIR/structure.txt"
ls -R /mnt/team_of_six/.tos >> "$DUMP_DIR/structure.txt" 2>&1

# 3. Capture Configurations (MASKING TOKENS)
mkdir -p "$DUMP_DIR/config"
if [ -d "$HOME/.config/team_of_six" ]; then
    cp "$HOME/.config/team_of_six/conf" "$DUMP_DIR/config/conf" 2>/dev/null
    echo "TOKEN_MASKED" > "$DUMP_DIR/config/.token"
fi

# 4. Capture Current Binary Content
mkdir -p "$DUMP_DIR/bin"
cp -r /opt/team_of_six/bin/* "$DUMP_DIR/bin/" 2>/dev/null
cp /opt/team_of_six/tos_controller.sh "$DUMP_DIR/tos_controller.sh" 2>/dev/null

# 5. Capture Last 50 lines of Controller Log
if [ -f "/mnt/team_of_six/.tos/controller.log" ]; then
    tail -n 50 "/mnt/team_of_six/.tos/controller.log" > "$DUMP_DIR/last_logs.log"
fi

# 6. Check Permissions of Key Paths
echo "--- Permission Audit ---" > "$DUMP_DIR/permissions.txt"
ls -ld /opt/team_of_six >> "$DUMP_DIR/permissions.txt"
ls -ld /mnt/team_of_six >> "$DUMP_DIR/permissions.txt"
ls -ld /mnt/team_of_six/.tos/outbox >> "$DUMP_DIR/permissions.txt"
ls -l /usr/local/bin/tos >> "$DUMP_DIR/permissions.txt"

# 7. Package it up
tar -czf "$DUMP_FILE" -C "$DUMP_DIR" .
rm -rf "$DUMP_DIR"

echo "---"
echo "✅ Dump Complete!"
echo "📦 Report saved to: $DUMP_FILE"
echo "⚠️  Note: .token content was replaced with 'TOKEN_MASKED' for security."
