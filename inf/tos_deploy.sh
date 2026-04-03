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

# Internal source
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

# --- 5. MIRRORING ---
echo "[*] Mirroring binaries to $TOS_MNT_ROOT..."

mkdir -p "${TOS_MNT_ROOT}/.local/bin"
mkdir -p "${TOS_MNT_ROOT}/.local/conf"

if [[ -d "$SOURCE_BIN" ]]; then
    {
      rsync -av --delete "${SOURCE_BIN}" "${TOS_MNT_ROOT}/.local/bin/"
    } | tee -a "${TOS_MNT_ROOT}/deploy.log"
else
    echo "❌ ERROR: Source directory '$SOURCE_BIN' not found."
    exit 1
fi

# --- 6. PERMISSIONS & IPC HARDENING ---
echo "[*] Securing IPC bridge and Sandbox for user: $USER_NAME"

touch "${TOS_MNT_ROOT}/.local/conf/config" "${TOS_MNT_ROOT}/.local/conf/.token"
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/.local/conf/config" "${TOS_MNT_ROOT}/.local/conf/.token"
chmod 440 "${TOS_MNT_ROOT}/.local/conf/config"
chmod 400 "${TOS_MNT_ROOT}/.local/conf/.token"

mkdir -p "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc"
mkdir -p "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/sandbox"
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc"
chmod 3770 "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc"

touch "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc/"{inbox,outbox}.md
chown "${USER_NAME}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc/inbox.md"
chown "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc/outbox.md"
chmod 660 "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/.ipc/"*.md

# --- 7. FINAL LOCKDOWN ---
chown -R "${AI_USER}:${AI_GROUP}" "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/sandbox" "${TOS_MNT_ROOT}/.local/bin"
chmod -R 700 "${TOS_MNT_ROOT}/tos_home/${USER_NAME}/sandbox"
chmod -R 750 "${TOS_MNT_ROOT}/.local/bin"

chown root:"${AI_USER}" "${TOS_MNT_ROOT}"
chmod 750 "${TOS_MNT_ROOT}"

echo "--- DEPLOYMENT REPORT ---"
tree -a -L 6 -pug -I '.git' "${TOS_MNT_ROOT}"

echo ""
echo "✅ Deployment complete. Root privileges confirmed and applied."
