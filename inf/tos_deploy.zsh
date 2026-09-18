#!/bin/bash
set -x
# --- 1. PRE-EMPTIVE ARGUMENT PARSING & ZSH FORCE ---
# Move this to the top to stop the infinite loop
TEST_MODE=0
for arg in "$@"; do
    [[ "$arg" == "--test-mode" ]] && TEST_MODE=1
done

# Only force Zsh if we aren't already in it
if [[ -z "$ZSH_VERSION" ]]; then
    exec zsh "$0" "$@"
fi

# --- 2. PRIVILEGE CHECK ---
# Guard root requirement behind test mode
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

# Parse remaining flags

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --mnt-root)
            TOS_MNT_ROOT="$2"
            shift 2
            ;;
        --test-mode)
            TEST_MODE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# --- 4. IDENTITY MAPPING (Mathematical Proof Mode) ---
HUMAN_USER="${SUDO_USER:-$USER}"

if [[ $TEST_MODE -eq 1 ]]; then
    echo "🧪 [TEST MODE] Mapping all identities to $USER:$(id -gn $USER)"
    AI_USER="$USER"
    AI_GROUP=$(id -gn "$USER")
fi

: "${TOS_MNT_ROOT:?Config Error: TOS_MNT_ROOT undefined}"
SOURCE_BIN="./bin/"

# --- 5. EXECUTION (Structure) ---
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

# --- GHOST CREDENTIAL SETUP ---
# Runs AFTER the directory tree exists: the key lives inside the control plane,
# so demanding it beforehand asked the Architect to place a file in a directory
# nothing had created yet.
#
# Interactive by default. A first-time deploy walks the Architect through it
# and installs what it is given. Non-interactive runs (CI, piped stdin) keep
# the old behaviour and refuse, because prompting there would hang.
_tos_credentials_ok() {
    [[ -n "${TOS_APP_ID:-}"         && "$TOS_APP_ID"         != *CHANGEME* ]] || return 1
    [[ -n "${TOS_APP_INSTALL_ID:-}" && "$TOS_APP_INSTALL_ID" != *CHANGEME* ]] || return 1
    [[ -n "${TOS_GHOST_LOGIN:-}"    && "$TOS_GHOST_LOGIN"    != *CHANGEME* ]] || return 1
    [[ -n "${TOS_APP_PEM:-}" && -f "$TOS_APP_PEM" ]] || return 1
    return 0
}

_tos_write_conf() {
    # Rewrite a value in the Architect's conf/config, then hand the file back:
    # sed -i replaces the inode, and running under sudo would otherwise leave
    # it owned by root.
    local key="$1" val="$2"
    if grep -q "^export ${key}=" "$CONFIG_FILE"; then
        KEY="$key" VAL="$val" perl -i -pe \
            's/^export \Q$ENV{KEY}\E=.*$/export $ENV{KEY}="$ENV{VAL}"/' "$CONFIG_FILE"
    else
        echo "export ${key}=\"${val}\"" >> "$CONFIG_FILE"
    fi
    chown "${HUMAN_USER}:" "$CONFIG_FILE" 2>/dev/null || true
}

if [[ $TEST_MODE -eq 0 ]] && ! _tos_credentials_ok; then
    if [[ ! -t 0 ]]; then
        echo "" >&2
        echo "❌ Ghost credentials are not configured, and stdin is not a terminal." >&2
        echo "   Set TOS_APP_ID, TOS_APP_INSTALL_ID and TOS_GHOST_LOGIN in conf/config," >&2
        echo "   place the App private key at ${TOS_APP_PEM:-<TOS_APP_PEM>}, and re-run." >&2
        echo "   docs/06-security.md § The Ghost Identity has the walkthrough." >&2
        exit 1
    fi

    echo ""
    echo "🔑 Ghost credentials are not configured yet."
    echo ""
    echo "   TOS runs its Ghost as a GitHub App with an identity of its own."
    echo "   That is what makes your approvals mean something: GitHub refuses"
    echo "   to let anyone approve their own pull request, and the Ghost opens"
    echo "   every one of them."
    echo ""
    echo "   Each Architect creates their own App. The private key never leaves"
    echo "   this machine — a shared App would make whoever created it a"
    echo "   credential broker for everyone else's repositories."
    echo ""
    echo "   If you have not made one yet:  https://github.com/settings/apps/new"
    echo "     Repository permissions:  Contents, Issues, Pull requests"
    echo "                              → Read and write"
    echo "     Administration:          leave UNGRANTED. TOS must not be able"
    echo "                              to create or destroy repositories."
    echo "   Then install it on your repositories and generate a private key."
    echo ""

    _v=""
    if [[ -z "${TOS_APP_ID:-}" || "$TOS_APP_ID" == *CHANGEME* ]]; then
        printf "   App ID (App settings → General → App ID): "
        read -r _v
        TOS_APP_ID="${_v//[^0-9]/}"
        [[ -n "$TOS_APP_ID" ]] || { echo "   ❌ Not a number. Aborting." >&2; exit 1; }
        _tos_write_conf TOS_APP_ID "$TOS_APP_ID"
    fi

    if [[ -z "${TOS_APP_INSTALL_ID:-}" || "$TOS_APP_INSTALL_ID" == *CHANGEME* ]]; then
        echo ""
        echo "   The installation ID is the number at the end of"
        echo "   https://github.com/settings/installations/<id>"
        printf "   Installation ID: "
        read -r _v
        TOS_APP_INSTALL_ID="${_v//[^0-9]/}"
        [[ -n "$TOS_APP_INSTALL_ID" ]] || { echo "   ❌ Not a number. Aborting." >&2; exit 1; }
        _tos_write_conf TOS_APP_INSTALL_ID "$TOS_APP_INSTALL_ID"
    fi

    if [[ -z "${TOS_GHOST_LOGIN:-}" || "$TOS_GHOST_LOGIN" == *CHANGEME* ]]; then
        echo ""
        echo "   The app slug is the last part of the App settings URL."
        printf "   App slug (without [bot]): "
        read -r _v
        _v="${_v%\[bot\]}"
        [[ -n "$_v" ]] || { echo "   ❌ Empty. Aborting." >&2; exit 1; }
        TOS_GHOST_LOGIN="${_v}[bot]"
        _tos_write_conf TOS_GHOST_LOGIN "$TOS_GHOST_LOGIN"
    fi

    : "${TOS_APP_PEM:=${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem}"
    if [[ ! -f "$TOS_APP_PEM" ]]; then
        echo ""
        echo "   The private key is the .pem GitHub downloaded when you"
        echo "   generated it. It will be copied into the control plane and"
        echo "   locked to ${AI_USER} at mode 0400; your own copy is untouched."
        printf "   Path to the .pem: "
        read -r _v
        _v="${_v/#\~/$HOME}"
        _v="${_v/#\$HOME/$HOME}"
        [[ -f "$_v" ]] || { echo "   ❌ No such file: $_v" >&2; exit 1; }
        if ! grep -q "PRIVATE KEY" "$_v"; then
            echo "   ❌ That does not look like a PEM private key." >&2
            echo "      Expected a line containing BEGIN ... PRIVATE KEY." >&2
            echo "      Note the CLIENT SECRET is a different credential and is" >&2
            echo "      not what TOS needs." >&2
            exit 1
        fi
        if ! install -o "$AI_USER" -g "$AI_GROUP" -m 0400 "$_v" "$TOS_APP_PEM"; then
            echo "   ❌ Could not install the key at $TOS_APP_PEM" >&2
            echo "      Check that the ${AI_USER} user exists and that this" >&2
            echo "      deploy is running as root." >&2
            exit 1
        fi
        _tos_write_conf TOS_APP_PEM "$TOS_APP_PEM"
        echo "   ✅ Installed at $TOS_APP_PEM"
    fi

    if ! _tos_credentials_ok; then
        echo "❌ Credentials are still incomplete. Aborting." >&2
        exit 1
    fi
    echo ""
fi

if [[ $TEST_MODE -eq 0 ]]; then
    echo "🔑 Ghost: App ${TOS_APP_ID}, installation ${TOS_APP_INSTALL_ID}, as ${TOS_GHOST_LOGIN}"
fi


# --- 6. FILE COPY & MIRRORING ---
echo "🚚 STEP 2: Mirroring Engine & Configuration..."
if [[ -d "$SOURCE_BIN" ]]; then
    # Removed > /dev/null so you can see progress
    rsync -av --delete "${SOURCE_BIN}" "${TOS_MNT_ROOT}/.local/bin/" | sed 's/^/    /'
else
    echo "❌ ERROR: Source bin not found."
    exit 1
fi

sed "s|/mnt/team_of_six|${TOS_MNT_ROOT}|g" "$CONFIG_FILE" > "${TOS_MNT_ROOT}/.local/conf/config"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/inbox.md"
touch "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}/outbox.md"

# --- 7. SECURITY PERIMETER ---
echo "🔐 STEP 3: Enforcing Security Perimeters..."

set_perm() {
    local perm=$1; local owner=$2; local target=$3
    echo "  perm: [$perm] owner: [$owner] -> $target"
    # chown will succeed in Test Mode because owner is $USER
    chown -R "$owner" "$target" 2>/dev/null
    chmod "$perm" "$target"
}

set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}"
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/bin"
set_perm 640 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/conf/config"
_PEM_LOCAL="${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem"
[[ -f "$_PEM_LOCAL" ]] && set_perm 400 "$AI_USER:$AI_GROUP" "$_PEM_LOCAL"
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc"
set_perm 700 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc/locks"
set_perm 3770 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"

# The sandbox is the isolation guarantee: docs/06-security.md § The Control
# Plane Layout says the Architect cannot read or write the Ghost's working
# files. Created by mkdir in STEP 1 under root's umask, it was left at 755
# and the guarantee silently did not hold.
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/sandbox"
# This is the directory modules actually use: TOS_SANDBOX resolves to
# sandbox/<architect> and projects are created inside it. Until the config was
# per-architect, this line permissioned a directory nothing touched, while the
# real sandboxes took whatever the Ghost's umask produced — correct by luck.
set_perm 700 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/sandbox/${HUMAN_USER}"

# .local/conf holds the App private key. The key itself is 0400, but a
# world-listable directory advertises what is in it.
set_perm 750 "$AI_USER:$AI_GROUP" "${TOS_MNT_ROOT}/.local/conf"

# --- STEP 4: Onboarding the deploying Architect ---
# MUST run last. STEP 3 does `chown -R team_of_six` across .ipc/<architect>,
# which takes the inbox with it — and the inbox has to be Architect-owned so
# payloads can be written without escalation. Onboarding here undoes that,
# and doing it any earlier would simply be undone in turn.
#
# Whoever installs TOS is assumed to be its first Architect. Adding further
# architects is what running tos_add_user.zsh directly is for.
if [[ $TEST_MODE -eq 0 ]]; then
    _DO_ONBOARD=1
    if [[ -t 0 ]]; then
        echo ""
        printf "👤 Set up '%s' as an Architect on this installation? [Y/n] " "$HUMAN_USER"
        read -r _reply
        [[ "$_reply" == [nN]* ]] && _DO_ONBOARD=0
    fi

    if (( _DO_ONBOARD )); then
        echo "👥 STEP 4: Onboarding $HUMAN_USER..."
        if [[ -x "./inf/tos_add_user.zsh" ]]; then
            ./inf/tos_add_user.zsh "$HUMAN_USER" || {
                echo "⚠️  Onboarding failed. The control plane is deployed, but" >&2
                echo "    $HUMAN_USER cannot use it yet. Run:" >&2
                echo "      sudo ./inf/tos_add_user.zsh $HUMAN_USER" >&2
                exit 1
            }
        else
            echo "⚠️  inf/tos_add_user.zsh not found or not executable." >&2
            exit 1
        fi
    else
        echo ""
        echo "⏭️  Skipped. No Architect can use this installation until you run:"
        echo "      sudo ./inf/tos_add_user.zsh <username>"
        echo "    The inbox is Ghost-owned until then, so payloads cannot be written."
    fi
fi

# --- IPC ribbon: asymmetric permissions for asymmetric roles ---
# The two halves of the ribbon are not symmetric and must not be given the
# same mode.
#
#   inbox   0660  the Architect writes payloads; the Ghost must also write,
#                 because ADR 10 has it truncate the inbox before any network
#                 side effect. Exact-once execution depends on that.
#
#   outbox  0640  the Ghost writes; the Architect only reads. At 0660 any
#                 Architect in the team_of_six group could edit the Clean Room
#                 Snapshot, and the Agent’s "verified context" would be only
#                 as trustworthy as everyone holding group membership.
#
# Runs after onboarding, which chowns the inbox to the Architect.
if [[ $TEST_MODE -eq 0 && -d "${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}" ]]; then
    _RIB="${TOS_MNT_ROOT}/.ipc/${HUMAN_USER}"
    [[ -f "${_RIB}/inbox.md" ]]  && chmod 0660 "${_RIB}/inbox.md"
    [[ -f "${_RIB}/outbox.md" ]] && { chown "${AI_USER}:${AI_GROUP}" "${_RIB}/outbox.md"; chmod 0640 "${_RIB}/outbox.md"; }
    echo "🔒 IPC ribbon: inbox 0660 (${HUMAN_USER}), outbox 0640 (${AI_USER})"
fi

echo "🏁 Deployment logic verified for sandbox."
