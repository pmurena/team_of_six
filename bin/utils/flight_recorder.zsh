#!/bin/zsh
# ==============================================================================
# TOS Flight Recorder (Telemetry & Bug Report Generator)
# Captures system state and API network traffic for debugging.
# ==============================================================================

PROJECT=$1
MODULE=$2
COMMAND=$3

# Generate a unique bug report ID based on timestamp
REPORT_ID="bug_report_$(date +%Y%m%d_%H%M%S)"
TELEMETRY_DIR="${TOS_MNT_ROOT:-/tmp}/.ipc/$USER/telemetry/$REPORT_ID"
REAL_ENGINE="$(dirname $0)/../tos.zsh"

echo "🔴 [FLIGHT RECORDER] Active. Recording telemetry to: $TELEMETRY_DIR"

# --- 1. START STATE ---
mkdir -p "$TELEMETRY_DIR/start"
cp -r "${TOS_MNT_ROOT:-/tmp}/.ipc/$USER" "$TELEMETRY_DIR/start/ipc_state" 2>/dev/null || true
cp -r "$(pwd)/sandbox/$USER/$PROJECT" "$TELEMETRY_DIR/start/sandbox_state" 2>/dev/null || true

# --- 2. THE PASSIVE WIRETAP ---
MOCKS_DIR="$TELEMETRY_DIR/network_traffic"
mkdir -p "$MOCKS_DIR"
SPY_BIN="$(mktemp -d)"

# Git Wiretap
cat << 'INNER_EOF' > "$SPY_BIN/git"
#!/bin/zsh
SUB_CMD=$1
COUNT=$(ls -1 "$MOCKS_DIR" | grep "git_${SUB_CMD}" | wc -l | tr -d ' ')
NEXT_NUM=$(printf "%02d" $((COUNT + 1)))
/usr/bin/git "$@" 2>&1 | tee "$MOCKS_DIR/${NEXT_NUM}_git_${SUB_CMD}.txt"
exit ${PIPESTATUS[0]}
INNER_EOF
chmod +x "$SPY_BIN/git"

# GH Wiretap
cat << 'INNER_EOF' > "$SPY_BIN/gh"
#!/bin/zsh
SUB_CMD=$1
COUNT=$(ls -1 "$MOCKS_DIR" | grep "gh_${SUB_CMD}" | wc -l | tr -d ' ')
NEXT_NUM=$(printf "%02d" $((COUNT + 1)))
/usr/bin/gh "$@" 2>&1 | tee "$MOCKS_DIR/${NEXT_NUM}_gh_${SUB_CMD}.txt"
exit ${PIPESTATUS[0]}
INNER_EOF
chmod +x "$SPY_BIN/gh"

# Inject wiretap into PATH
export PATH="$SPY_BIN:$PATH"
export MOCKS_DIR="$MOCKS_DIR"

# --- 3. EXECUTE REAL ENGINE ---
"$REAL_ENGINE" "$@"
ENGINE_EXIT_CODE=$?

# Clean up wiretap immediately
rm -rf "$SPY_BIN"

# --- 4. END STATE ---
mkdir -p "$TELEMETRY_DIR/end"
cp -r "${TOS_MNT_ROOT:-/tmp}/.ipc/$USER" "$TELEMETRY_DIR/end/ipc_state" 2>/dev/null || true
cp -r "$(pwd)/sandbox/$USER/$PROJECT" "$TELEMETRY_DIR/end/sandbox_state" 2>/dev/null || true

echo "\n🛑 [FLIGHT RECORDER] Recording complete."
if [[ $ENGINE_EXIT_CODE -ne 0 ]]; then
    echo "⚠️  Engine exited with error code: $ENGINE_EXIT_CODE"
fi
echo "📦 Please zip the following directory and attach it to your bug report:"
echo "   $TELEMETRY_DIR"

exit $ENGINE_EXIT_CODE
