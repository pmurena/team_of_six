# =============================================================================
# tests/system/fixtures/standard.zsh
# PURPOSE: Full GitHub E2E Fixture (Setup, Assertions, and Teardown)
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Standard Environment Variables
# ---------------------------------------------------------------------------
export REPO_NAME="tos-e2e-test-$(date +%s)"
export ARCHITECT_USER=$(whoami)
export TOS_MNT_ROOT=$(mktemp -d /tmp/tos_e2e_XXXXXX)
export TOS_LOCKS="${TOS_MNT_ROOT}/.ipc/locks"
export TOS_SANDBOX="${TOS_MNT_ROOT}/sandbox"
export AI_USER="$ARCHITECT_USER"
export AI_GROUP=$(id -gn)

# ---------------------------------------------------------------------------
# 2. The Teardown Hook (Caught by Il Grand Stregone)
# ---------------------------------------------------------------------------
function stregone_payload_teardown() {
    echo "🧹 Fixture Teardown: Removing GitHub repository ${REPO_NAME:-}..."
    gh repo delete "${REPO_NAME:-}" --yes 2>/dev/null || true
    
    echo "🧹 Fixture Teardown: Restoring configs and wiping sandbox..."
    [[ -f "conf/config.bak" ]] && mv conf/config.bak conf/config
    rm -rf "${TOS_MNT_ROOT:-}" /tmp/tos_deploy_test_*.zsh 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 3. Pre-Flight Auth Check
# ---------------------------------------------------------------------------
if ! gh auth status -h github.com 2>&1 | grep -q "delete_repo"; then 
    echo "🚨 [FIXTURE ERROR] MFA Auth Required. Run: gh auth refresh -h github.com -s delete_repo" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 4. Sandbox Deployment (The Setup)
# ---------------------------------------------------------------------------
echo "── FIXTURE: Deploying Local Sandbox ────────────────────────────────"
export TOS_MOCK_BIN="$TOS_MNT_ROOT/mock_bin"
mkdir -p "$TOS_MOCK_BIN"
echo '#!/usr/bin/env zsh\necho "team_of_six"' > "$TOS_MOCK_BIN/id"
chmod +x "$TOS_MOCK_BIN/id"
export PATH="$TOS_MOCK_BIN:$PATH"

[[ -f "conf/config" ]] && cp conf/config conf/config.bak
cat <<EOF > conf/config
export TOS_MNT_ROOT="$TOS_MNT_ROOT"
export TOS_BIN="\$TOS_MNT_ROOT/.local/bin"
export TOS_IPC="\$TOS_MNT_ROOT/.ipc"
export TOS_LOCKS="\$TOS_MNT_ROOT/.ipc/locks"
export TOS_SANDBOX="\$TOS_MNT_ROOT/sandbox"
export TOS_INPUT="\$TOS_MNT_ROOT/.ipc/$ARCHITECT_USER/inbox.md"
export TOS_CONTEXT="\$TOS_MNT_ROOT/.ipc/$ARCHITECT_USER/outbox.md"
export AI_USER="$AI_USER"
export AI_GROUP="$AI_GROUP"
EOF

cp inf/tos_deploy.zsh "/tmp/tos_deploy_test_$$.zsh"
sed -i 's/\[\[ \$EUID -ne 0 \]\]/false/g' "/tmp/tos_deploy_test_$$.zsh"
sed -i 's/chown /true /g; s/chmod /true /g' "/tmp/tos_deploy_test_$$.zsh"
sed -i '/tos_add_user.zsh/s/^/#/' "/tmp/tos_deploy_test_$$.zsh"
sed -i '/tos.zsh sync/d; /sync project/d' "/tmp/tos_deploy_test_$$.zsh"

export GHOST_TOKEN=$(gh auth token)
zsh "/tmp/tos_deploy_test_$$.zsh" <<EOF >/dev/null
$GHOST_TOKEN
EOF

export TOS_BIN_CMD="$TOS_MNT_ROOT/.local/bin/tos.zsh"
chmod +x "$TOS_BIN_CMD"
export TOS_CONTROLLER_LOCKED=true
export SUDO_USER="$ARCHITECT_USER"
export TOS_ACTIVE_PROJECT="${REPO_NAME}"
mkdir -p "${TOS_MNT_ROOT}/.ipc/locks" "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}" "${TOS_MNT_ROOT}/sandbox/${ARCHITECT_USER}"
: > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/inbox.md"
: > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/outbox.md"

echo "  [PASS] Sandbox provisioned securely at $TOS_MNT_ROOT\n"

# ---------------------------------------------------------------------------
# 5. Assertion Library
# ---------------------------------------------------------------------------
_FAILURES=0
function _pass() { echo "  [PASS] $*"; }
function _fail() { echo "  [FAIL] $*" >&2; (( _FAILURES++ )) || true; }
function assert_true() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then _pass "${desc}"; else _fail "${desc}"; fi }
function assert_false() { local desc="$1"; shift; if ! "$@" >/dev/null 2>&1; then _pass "${desc}"; else _fail "${desc} (expected failure)"; fi }
function assert_file_exists() { local desc="$1" path="$2"; if [[ -f "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} not found"; fi }
function assert_dir_exists() { local desc="$1" path="$2"; if [[ -d "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} not found"; fi }
function assert_dir_not_exists() { local desc="$1" path="$2"; if [[ ! -d "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} should not exist"; fi }
function assert_file_not_exists() { local desc="$1" path="$2"; if [[ ! -f "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} should not exist"; fi }
function assert_file_contains() { local desc="$1" path="$2" sub="$3"; if grep -qF "${sub}" "${path}" 2>/dev/null; then _pass "${desc}"; else _fail "${desc}: '${sub}' not found"; fi }
function assert_gh_output_contains() { local desc="$1" sub="$2"; shift 2; local out; out=$(gh "$@" 2>&1) || true; if echo "${out}" | grep -qF "${sub}"; then _pass "${desc}"; else _fail "${desc}: '${sub}' not found"; fi }
function assert_gh_succeeds() { local desc="$1"; shift; if gh "$@" >/dev/null 2>&1; then _pass "${desc}"; else _fail "${desc}: gh $* failed"; fi }
function assert_gh_fails() { local desc="$1"; shift; if ! gh "$@" >/dev/null 2>&1; then _pass "${desc}"; else _fail "${desc}: gh $* succeeded"; fi }
function write_inbox() { printf '%s\n' "$1" > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/inbox.md"; }
