#!/bin/bash

# --- 0. PRIVILEGE CHECK ---
# Fail immediately if not root
if [[ $EUID -ne 0 ]]; then
   echo "❌ ERROR: This script must be run as root (sudo)."
   exit 1
fi

# --- 1. DEPENDENCY CHECK (Initial Shell) ---
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

# --- 2. ZSH FORCE (The Handover) ---
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

# --- 4. STRICT CONFIGURATION ---
CONFIG_FILE="./conf/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # Since we are root, we can safely source protected configs
    source "$CONFIG_FILE"
else
    echo "❌ ERROR: Configuration file missing at $CONFIG_FILE"
    exit 1
fi

# Force validation of variables from config
: "${TOS_MNT_ROOT:?Config Error: TOS_MNT_ROOT must be defined in $CONFIG_FILE}"
: "${AI_USER:?Config Error: AI_USER must be defined in $CONFIG_FILE}"
: "${AI_GROUP:?Config Error: AI_GROUP must be defined in $CONFIG_FILE}"

# Capture the real human user running sudo
HUMAN_USER="${SUDO_USER:-$USER}"
SOURCE_BIN="./bin/"

[[ -t 0 ]] && clear

cat << 'EOF'
  _______                    ____   __   _____ _      
 |__   __|                  / __ \ / _| / ____(_)     
    | | ___  __ _ _ __ ___  | |  | | |_ | (___  ___  __
    | |/ _ \/ _` | '_ ` _ \ | |  | |  _| \___ \| \ \/ /
    | |  __/ (_| | | | | | || |__| | |  ____) | |>  < 
    |_|\___|\__,_|_| |_| |_| \____/|_|  |_____/|_/_/\_\

 Deployment & Security Scaffolding (Root Verified)
==========================================================
EOF

# --- 5. DIRECTORY ARCHITECTURE ---
echo "[*] STEP 1: Creating Directory Structure..."

mkdir -p "${TOS_MNT_ROOT}/.local/bin"
mkdir -p "${TOS_MNT_ROOT}/.local/conf"
mkdir -p "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc"
mkdir -p "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/sandbox"

# --- 6. FILE COPY & MIRRORING ---
echo "[*] STEP 2: Copying Engine Files & Configuration..."

if [[ -d "$SOURCE_BIN" ]]; then
    # Mirror Binaries
    rsync -av --delete "${SOURCE_BIN}" "${TOS_MNT_ROOT}/.local/bin/" >/dev/null
else
    echo "❌ ERROR: Source directory '$SOURCE_BIN' not found."
    exit 1
fi

# Copy Config and initialize Token/IPC files
cp "$CONFIG_FILE" "${TOS_MNT_ROOT}/.local/conf/config"
touch "${TOS_MNT_ROOT}/.local/conf/.token"
touch "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc/"{inbox,outbox}.md


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
chmod 640 "${TOS_MNT_ROOT}/.local/conf/config" # Readable by human via group
chmod 400 "${TOS_MNT_ROOT}/.local/conf/.token" # AI locked

# IPC Bridge
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc"
chmod 3770 "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc" # Sticky bits for shared reading

chown "${HUMAN_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc/inbox.md"
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc/outbox.md"
chmod 660 "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/.ipc/"*.md

# Sandbox (Air-gapped)
chown -R "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/sandbox"
chmod -R 700 "${TOS_MNT_ROOT}/tos_home/${HUMAN_USER}/sandbox"

echo ""
echo "--- DEPLOYMENT REPORT ---"
tree -a -L 6 -pug -I '.git' "${TOS_MNT_ROOT}"

echo ""
echo "✅ Deployment sequence complete. Sandbox secured for $HUMAN_USER."
