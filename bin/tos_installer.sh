#!/bin/zsh
# V55 Deployment Script
# Security: Runs as User. Uses sudo for wiring.

set -e

# Defaults
AI_USER="team_of_six"
GROUP="team_of_six"
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"

# Args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ai-user) AI_USER="$2"; shift ;;
        --ai-group) GROUP="$2"; shift ;;
        --repo-root) REPO_ROOT="$2"; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
    shift
done

REAL_USER=$(whoami)
echo "🔧 Installing V55 for $REAL_USER (AI: $AI_USER)..."

# [CONSTRAINT] Anti-Root in Installer
if [[ $EUID -eq 0 ]]; then
   echo "❌ ERROR: Installer should run as $REAL_USER, not root."
   exit 1
fi

echo "🔐 Verifying sudo for system wiring..."
sudo -v

# 1. Guard: Git Status
if [[ -d "$REPO_ROOT/.git" ]]; then
    if [[ -n $(git -C "$REPO_ROOT" status --porcelain) ]]; then
        echo "❌ ERROR: Repository is dirty. Commit or stash changes first."
        exit 1
    fi
fi

# 2. System Users (Requires Sudo)
if ! getent group "$GROUP" >/dev/null; then
    echo "👤 [SUDO] Creating group $GROUP"
    sudo groupadd "$GROUP"
fi
if ! id "$AI_USER" &>/dev/null; then
    echo "👤 [SUDO] Creating system user $AI_USER"
    sudo useradd -r -g "$GROUP" -s /bin/zsh "$AI_USER"
else
    echo "   [INFO] User $AI_USER exists."
fi
# Add Real User to Group
sudo usermod -a -G "$GROUP" "$REAL_USER"

# 3. Sudoers Tunnel
echo "🛡️ [SUDO] Configuring Tunnel Permissions..."
TMP_SUDOERS=$(mktemp)
BIN_GIT=$(which git)
BIN_GH=$(which gh)
BIN_PYTHON=$(which python3)

# --- CONDA HEURISTIC ---
CONDA_BIN=""
if command -v conda &>/dev/null; then
    CONDA_BIN=$(command -v conda)
fi
if [ -z "$CONDA_BIN" ]; then
    # Standard locations
    for path in "$HOME/miniconda3/bin/conda" "/opt/miniconda3/bin/conda" "/usr/bin/conda"; do
        if [ -x "$path" ]; then CONDA_BIN="$path"; break; fi
    done
fi
[ -z "$CONDA_BIN" ] && CONDA_BIN="/usr/bin/conda"

# Write Rule: AI User can run these commands as REAL_USER without password
echo "$AI_USER ALL=($REAL_USER) NOPASSWD: $BIN_GIT, $BIN_GH, $CONDA_BIN, $BIN_PYTHON" > "$TMP_SUDOERS"

# Validate strictly before moving
visudo -c -f "$TMP_SUDOERS" || { echo "❌ Sudoers syntax error"; rm "$TMP_SUDOERS"; exit 1; }

sudo cp "$TMP_SUDOERS" "/etc/sudoers.d/team_of_six"
sudo chmod 440 "/etc/sudoers.d/team_of_six"
rm "$TMP_SUDOERS"

# 4. Symlink (User Scope)
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_ROOT/tos_controller.sh" "$HOME/.local/bin/team_of_six"
echo "   + Symlink created: ~/.local/bin/team_of_six"

# 5. Bootstrapping Home (User Scope)
TOS_HOME="$HOME/.team_of_six"
mkdir -p "$TOS_HOME"

# Write Full Config
cat <<CONFIG > "$TOS_HOME/tos_config"
export AI_USER="$AI_USER"
export AI_GROUP="$GROUP"
export REAL_USER="$REAL_USER"
export REPO_ROOT="$REPO_ROOT"
CONFIG

# Initialize Global State Files
touch "$TOS_HOME/tos_input.sh" "$TOS_HOME/tos_output.log" "$TOS_HOME/tos_lessons.md"

echo "✅ Installation Complete."
