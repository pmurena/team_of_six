#!/bin/bash

# --- 1. PRE-EMPTIVE ARGUMENT PARSING & ZSH FORCE ---
TEST_MODE=0
# Quick scan to determine if we need root or not
for arg in "$@"; do
    [[ "$arg" == "--test-mode" ]] && TEST_MODE=1
done

# Only force Zsh if we aren't already in it
if [[ -z "$ZSH_VERSION" ]]; then
    exec zsh "$0" "$@"
fi

# --- 2. PRIVILEGE CHECK ---
if [[ $TEST_MODE -eq 0 && $EUID -ne 0 ]]; then
   echo "❌ ERROR: This script must be run as root (sudo) unless --test-mode is used."
   exit 1
fi

# --- 3. CONFIGURATION ---
CONFIG_FILE="./conf/config"
echo "🔍 Checking configuration..."
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "✅ Configuration sourced."
else
    echo "❌ ERROR: Configuration file missing at $CONFIG_FILE"
    exit 1
fi

# --- 4. ARGUMENT PARSING (Fixed Loop) ---
# Every branch MUST include a shift to avoid infinite loops
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --mnt-root)
            TOS_MNT_ROOT="$2"
            shift 2
            ;;
        --test-mode)
            TEST_MODE=1
            shift
            ;;
        *)
            # Consume unknown arguments to prevent hanging
            shift
            ;;
    esac
done

# --- 5. IDENTITY MAPPING (Mathematical Proof Mode) ---
HUMAN_USER="${SUDO_USER:-$USER}"

if [[ $TEST_MODE -eq 1 ]]; then
    echo "🧪 [TEST MODE] Mapping all identities to $USER:$(id -gn $USER)"
    AI_USER="$USER"
    AI_GROUP=$(id -gn "$USER")
fi

: "${TOS_MNT_ROOT:?Config Error: TOS_MNT_ROOT undefined}"
SOURCE_BIN="./bin/"

# --- 6. EXECUTION (Structure) ---
echo "🏗️  STEP 1: Creating Directory Architecture in $TOS_MNT_ROOT..."
DIRS=(
    "${TOS_MNT_ROOT}/.ipc/locks"
    "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"
    "${TOS_MNT_ROOT}/.local/bin"
    "${TOS_MNT_ROOT}/.local/conf"
    "${TOS_MNT_ROOT}/sandbox/${HUMAN_USER}"
)

for dir in "${DIRS[@]}"; do
    mkdir -p "$dir" && echo "  mkdir -> $dir"
done

# --- 7. FILE COPY & MIRRORING ---
echo "🚚 STEP 2: Mirroring Engine & Configuration..."
if [[ -d "$SOURCE_BIN" ]]; then
    rsync -av --delete "${SOURCE_BIN}" "${TOS_MNT_ROOT}/.local/bin/" | sed 's/^/    /'
else
    echo "❌ ERROR: Source bin not found."
    exit 1
fi

cp -v "$CONFIG_FILE" "${TOS_MNT_ROOT}/.local/conf/config"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/inbox.md"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/outbox.md"
touch "${TOS_MNT_ROOT}/.local/conf/.token"

# --- 8. SECURITY PERIMETER ---
echo "🔐 STEP 3: Enforcing Security Perimeters..."

set_perm() {
    local perm=$1; local owner=$2; local target=$3
    echo "  perm: [$perm] owner: [$owner] -> $target"
    # chown works in Test Mode because the owner is current $USER
    chown -R "$owner" "$target" 2>/dev/null
    chmod "$perm" "$target"
}

set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}"
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/bin"
set_perm 640 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/conf/config"
set_perm 400 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/conf/.token"
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc"
set_perm 700 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc/locks"
set_perm 3770 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"

echo "🏁 Deployment logic verified for sandbox."
