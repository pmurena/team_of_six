#!/bin/bash

# --- 0. PRIVILEGE CHECK ---
if [[ $EUID -ne 0 ]]; then
   echo "❌ ERROR: This script must be run as root (sudo)."
   exit 1
fi

# --- 1. DEPENDENCY CHECK ---
REQUIRED_PKGS=("zsh" "git" "rsync" "gh" "tee" "touch" "tree" "chown" "chmod" "mkdir")

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    echo "❌ ERROR: Missing required dependencies: ${MISSING_PKGS[*]}"
    exit 1
fi

# --- 2. ZSH FORCE ---
if [ -z "$ZSH_VERSION" ]; then
    exec zsh "$0" "$@"
fi

# --- 3. REPO & REMOTE VALIDATION ---
if [[ ! -d ".git" ]]; then
    echo "❌ ERROR: .git directory not found. Run from repo root."
    exit 1
fi

REPO_URL=$(git remote get-url origin 2>/dev/null)
if [[ "$REPO_URL" != *"team_of_six"* ]]; then
    echo "❌ ERROR: Repository mismatch ($REPO_URL). Deployment aborted."
    exit 1
fi

if [[ ! -f "inf/tos_deploy.sh" ]]; then
    echo "❌ ERROR: Project signature not found."
    exit 1
fi

# --- 4. CONFIGURATION ---
CONFIG_FILE="./conf/config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "❌ ERROR: Configuration file missing at $CONFIG_FILE"
    exit 1
fi

: "${TOS_MNT_ROOT:?Config Error: TOS_MNT_ROOT must be defined in $CONFIG_FILE}"
: "${AI_USER:?Config Error: AI_USER must be defined in $CONFIG_FILE}"
: "${AI_GROUP:?Config Error: AI_GROUP must be defined in $CONFIG_FILE}"

HUMAN_USER="${SUDO_USER:-$USER}"
SOURCE_BIN="./bin/"

[[ -t 0 ]] && clear

cat << 'EOF'
  _______                    ____   __   _____ _      
 |__   __|                  / __ \ / _| / ____(_)     
    | | ___  __ _ _ __ ___  | |  | | |_ | (___  ___  __
    | |/ _ \/ _` | '_ ` _ \ | |  | |  _| \___ \| \ \/ /
    | |  __/ (_| | | | | | || |__| | |  ____) | |>  < 
    |_|\___|\_,_|_| |_| |_| \____/|_|  |_____/|_/_/\_\

 Deployment & Security Scaffolding (Root Verified)
==========================================================
EOF

# --- 5. DIRECTORY ARCHITECTURE ---
echo "[*] STEP 1: Creating Directory Structure..."

# Global Control Plane
mkdir -p "${TOS_MNT_ROOT}/.ipc/locks"
mkdir -p "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"

# Engine
mkdir -p "${TOS_MNT_ROOT}/.local/bin"
mkdir -p "${TOS_MNT_ROOT}/.local/conf"

# Flattened Execution Plane
mkdir -p "${TOS_MNT_ROOT}/sandbox/${HUMAN_USER}"

# --- 6. FILE COPY & MIRRORING ---
echo "[*] STEP 2: Copying Engine Files & Configuration..."

if [[ -d "$SOURCE_BIN" ]]; then
    rsync -av --delete "${SOURCE_BIN}" "${TOS_MNT_ROOT}/.local/bin/" >/dev/null
else
    echo "❌ ERROR: Source directory '$SOURCE_BIN' not found."
    exit 1
fi

cp "$CONFIG_FILE" "${TOS_MNT_ROOT}/.local/conf/config"
touch "${TOS_MNT_ROOT}/.local/conf/.token"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/inbox.md"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/outbox.md"

# --- 7. SECURITY PERIMETER LOCKDOWN ---
echo "[*] STEP 3: Enforcing Security Perimeters..."

# Root Mount
chown root:"${AI_USER}" "${TOS_MNT_ROOT}"
chmod 750 "${TOS_MNT_ROOT}"

# Binaries
chown -R "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.local/bin"
chmod -R 750 "${TOS_MNT_ROOT}/.local/bin"

# Configurations
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.local/conf/config" "${TOS_MNT_ROOT}/.local/conf/.token"
chmod 640 "${TOS_MNT_ROOT}/.local/conf/config"
chmod 400 "${TOS_MNT_ROOT}/.local/conf/.token"

# Global IPC root — ghost owns, group can enter
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.ipc"
chmod 750 "${TOS_MNT_ROOT}/.ipc"

# Locks dir — ghost owns exclusively
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.ipc/locks"
chmod 700 "${TOS_MNT_ROOT}/.ipc/locks"

# Per-user IPC ribbon
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"
chmod 3770 "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"

chown "${HUMAN_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/inbox.md"
chown "${AI_USER}:${AI_GROUP}"    "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/outbox.md"
chmod 660 "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/"*.md

# Flattened Sandbox (Air-gapped)
chown -R "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/sandbox/${HUMAN_USER}"
chmod -R 700 "${TOS_MNT_ROOT}/sandbox/${HUMAN_USER}"

echo ""
echo "--- DEPLOYMENT REPORT ---"
tree -a -L 6 -pug -I '.git' "${TOS_MNT_ROOT}"

echo ""
echo "✅ Deployment sequence complete. Sandbox secured for $HUMAN_USER."

echo ""
echo "[*] STEP 4: Auto-Provisioning User Environment..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
zsh "$SCRIPT_DIR/tos_add_user.sh" "$HUMAN_USER"
