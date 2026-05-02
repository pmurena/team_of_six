#!/usr/bin/env zsh
# =============================================================================
# test/e2e/grand_tutorial.zsh
# =============================================================================
# WHAT IS TESTED
#   The full TOS lifecycle against a REAL GitHub repository.
#   No mocks. No fakes. Real `gh`, real `git`, real network.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WARNING: THIS SCRIPT CREATES AND DESTROYS A REAL GITHUB REPOSITORY.    │
# │  It requires:                                                            │
# │    - An authenticated `gh` CLI (`gh auth status` must show a valid PAT) │
# │    - Write access to create repos under the authenticated account        │
# │    - The `tos` gateway to be installed and on PATH                       │
# │  DO NOT run this in CI unless you have a dedicated test GitHub account.  │
# └─────────────────────────────────────────────────────────────────────────┘
#
# STEPS (matching test-concept-v2.md Section 7)
#   1.  create project   → GitHub repo exists
#   2.  sync project     → sandbox cloned; SOFT_LOCK acquired
#   3.  create issue     → ≥2 issues open on GitHub
#   4.  create trinity 1 → Draft PR open on GitHub
#   5.  sync trinity 1   → HARD_LOCK acquired; outbox has snapshot
#   6.  write plan       → .manifest visa created
#   7.  write code (red) → failing test committed to tos-work-1
#   8.  write comment    → comment visible on PR
#   9.  write code (green) → passing implementation committed
#  10.  write trinity    → PR merged; issue closed; lock released
#  11.  close project    → sandbox removed; remote intact
#  12.  delete project   → MFA escalation; repo deleted; scope revoked
#
# EXIT TRAP (always runs — even on script error or Ctrl-C)
#   Cleans up the GitHub repo and /tmp/tos_test_root so the test account
#   never accumulates leftover repos.
#
# USAGE
#   zsh test/e2e/grand_tutorial.zsh
#
# PASS/FAIL REPORTING
#   Each step prints "[PASS] <description>" or "[FAIL] <description>" to stdout.
#   The script exits non-zero if ANY assertion fails.
# =============================================================================

# ---------------------------------------------------------------------------
# Strict mode
# ---------------------------------------------------------------------------
# -e : exit immediately on error (we override with explicit checks per step)
# -u : treat unset variables as errors
# -o pipefail : a pipeline fails if any command in it fails
setopt ERR_EXIT NOUNSET PIPE_FAIL 2>/dev/null || set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# $$ is the PID of this shell — guarantees a unique repo name per run.
REPO_NAME="tos-e2e-test-$$"
ARCHITECT_USER=$(whoami)
TOS_MNT_ROOT="${TOS_MNT_ROOT:-/tmp/tos_test_root}"
TOS_LOCKS="${TOS_MNT_ROOT}/.ipc/locks"
TOS_SANDBOX="${TOS_MNT_ROOT}/sandbox"

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------
# _pass / _fail track the overall result without exiting immediately on each
# assertion failure. This lets the script report ALL failures before exiting.
_FAILURES=0

function _pass() {
    echo "[PASS] $*"
}

function _fail() {
    echo "[FAIL] $*" >&2
    (( _FAILURES++ )) || true
}

# assert_true <description> <command...>
# Runs the command; calls _pass or _fail based on exit code.
function assert_true() {
    local description="$1"; shift
    if "$@" >/dev/null 2>&1; then
        _pass "${description}"
    else
        _fail "${description}"
    fi
}

# assert_false <description> <command...>
# Passes if the command exits NON-zero.
function assert_false() {
    local description="$1"; shift
    if ! "$@" >/dev/null 2>&1; then
        _pass "${description}"
    else
        _fail "${description} (expected failure, got success)"
    fi
}

# assert_file_exists <description> <path>
function assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} not found"; fi
}

# assert_dir_exists <description> <path>
function assert_dir_exists() {
    local desc="$1" path="$2"
    if [[ -d "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} not found"; fi
}

# assert_dir_not_exists <description> <path>
function assert_dir_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -d "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} should not exist"; fi
}

# assert_file_not_exists <description> <path>
function assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -f "${path}" ]]; then _pass "${desc}"; else _fail "${desc}: ${path} should not exist"; fi
}

# assert_file_contains <description> <path> <substring>
function assert_file_contains() {
    local desc="$1" path="$2" substring="$3"
    if grep -qF "${substring}" "${path}" 2>/dev/null; then
        _pass "${desc}"
    else
        _fail "${desc}: '${substring}' not found in ${path}"
    fi
}

# assert_gh_output_contains <description> <substring> <gh_args...>
# Runs a gh command and checks its JSON output for a substring.
function assert_gh_output_contains() {
    local desc="$1" substring="$2"; shift 2
    local output
    output=$(gh "$@" 2>&1) || true
    if echo "${output}" | grep -qF "${substring}"; then
        _pass "${desc}"
    else
        _fail "${desc}: '${substring}' not found in: ${output}"
    fi
}

# assert_gh_succeeds <description> <gh_args...>
function assert_gh_succeeds() {
    local desc="$1"; shift
    if gh "$@" >/dev/null 2>&1; then
        _pass "${desc}"
    else
        _fail "${desc}: gh $* failed"
    fi
}

# assert_gh_fails <description> <gh_args...>
function assert_gh_fails() {
    local desc="$1"; shift
    if ! gh "$@" >/dev/null 2>&1; then
        _pass "${desc}"
    else
        _fail "${desc}: gh $* succeeded (expected failure)"
    fi
}

# ---------------------------------------------------------------------------
# Inbox writer helper
# ---------------------------------------------------------------------------
# Writes a payload string to the architect's inbox.
function write_inbox() {
    local content="$1"
    printf '%s\n' "${content}" > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/inbox.md"
}

# ---------------------------------------------------------------------------
# EXIT trap — always runs
# ---------------------------------------------------------------------------
function _cleanup() {
    echo ""
    echo "═══ EXIT TRAP: cleaning up ═══"
    # Attempt to delete the test repo (ignore errors — it may already be gone).
    gh repo delete "${REPO_NAME}" --yes 2>/dev/null || true
    # Remove the local scratch filesystem.
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null || true
    echo "Cleanup complete."
}
trap '_cleanup' EXIT

# ---------------------------------------------------------------------------
# Startup warning and confirmation prompt
# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  TOS Grand Tutorial — End-to-End Test                           ║"
echo "║                                                                  ║"
echo "║  This script will CREATE and DESTROY the GitHub repository:     ║"
printf "║    %-64s║\n" "  ${REPO_NAME}"
echo "║                                                                  ║"
echo "║  It uses your authenticated gh CLI credentials.                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
printf "Type 'yes' to proceed, anything else to abort: "
read -r _confirmation
if [[ "${_confirmation}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

# Verify gh is authenticated before doing anything destructive.
if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

# Ensure TOS environment variables are exported for child processes.
export TOS_MNT_ROOT ARCHITECT_USER REPO_NAME TOS_CONTROLLER_LOCKED=true
export SUDO_USER="${ARCHITECT_USER}"
export TOS_ACTIVE_PROJECT="${REPO_NAME}"

# Create the base IPC directory tree so the inbox exists before step 1.
mkdir -p \
    "${TOS_MNT_ROOT}/.ipc/locks" \
    "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}" \
    "${TOS_MNT_ROOT}/sandbox/${ARCHITECT_USER}" \
    "${TOS_MNT_ROOT}/.local/conf"
: > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/inbox.md"
: > "${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/outbox.md"

# ---------------------------------------------------------------------------
# STEP 1 — Inception: create project
# ---------------------------------------------------------------------------
echo "── STEP 1: create project ──────────────────────────────────────────"
write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TITLE=${REPO_NAME}
BODY=E2E test repo created by grand_tutorial.zsh
===TOS_META_END==="

tos "${REPO_NAME}" create project
assert_gh_succeeds \
    "STEP 1: gh repo view exits 0 (repo exists on GitHub)" \
    repo view "${REPO_NAME}"

# ---------------------------------------------------------------------------
# STEP 2 — Sandbox provisioning: sync project
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 2: sync project ────────────────────────────────────────────"
tos "${REPO_NAME}" sync project

assert_dir_exists \
    "STEP 2: sandbox directory created" \
    "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}"

assert_file_exists \
    "STEP 2: SOFT_LOCK acquired (trinity 0 lock file exists)" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_0.lock"

assert_file_contains \
    "STEP 2: lock file contains SOFT_LOCK" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_0.lock" \
    "SOFT_LOCK"

# ---------------------------------------------------------------------------
# STEP 3 — Issue creation: create issue (two issues)
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 3: create issue ────────────────────────────────────────────"
write_inbox "===TOS_ISSUE_START===
TITLE=Implement add() function
BODY=The primary calculation function for this trinity.
===TOS_ISSUE_END===
===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Deferred to a future trinity.
===TOS_ISSUE_END==="

tos "${REPO_NAME}" create issue

# Query GitHub for the open issue count — must be at least 2.
_issue_count=$(gh issue list \
    --repo "${REPO_NAME}" \
    --state open \
    --json number \
    --jq 'length' 2>/dev/null || echo 0)

if (( _issue_count >= 2 )); then
    _pass "STEP 3: at least 2 issues open on GitHub (found ${_issue_count})"
else
    _fail "STEP 3: expected ≥2 open issues, found ${_issue_count}"
fi

# ---------------------------------------------------------------------------
# STEP 4 — Trinity creation: create trinity 1
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 4: create trinity 1 ────────────────────────────────────────"
tos "${REPO_NAME}" create trinity 1

# A Draft PR must now exist.
_pr_count=$(gh pr list \
    --repo "${REPO_NAME}" \
    --state open \
    --json number \
    --jq 'length' 2>/dev/null || echo 0)

if (( _pr_count >= 1 )); then
    _pass "STEP 4: at least 1 open PR found"
else
    _fail "STEP 4: expected ≥1 open PR, found ${_pr_count}"
fi

# The PR must be a draft.
_is_draft=$(gh pr view 1 \
    --repo "${REPO_NAME}" \
    --json isDraft \
    --jq '.isDraft' 2>/dev/null || echo "false")

if [[ "${_is_draft}" == "true" ]]; then
    _pass "STEP 4: PR 1 is a Draft"
else
    _fail "STEP 4: PR 1 is not a Draft (isDraft=${_is_draft})"
fi

# ---------------------------------------------------------------------------
# STEP 5 — Workspace alignment: sync trinity 1
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 5: sync trinity 1 ──────────────────────────────────────────"
tos "${REPO_NAME}" sync trinity 1
export TOS_ACTIVE_TRINITY="1"

assert_file_exists \
    "STEP 5: HARD_LOCK acquired (trinity 1 lock file exists)" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock"

assert_file_contains \
    "STEP 5: lock file contains HARD_LOCK" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock" \
    "HARD_LOCK"

_outbox="${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/outbox.md"
if [[ -s "${_outbox}" ]]; then
    _pass "STEP 5: outbox is non-empty (Clean Room Snapshot generated)"
else
    _fail "STEP 5: outbox is empty — snapshot not written"
fi

assert_file_contains \
    "STEP 5: outbox contains TARGET_TRINITY=1" \
    "${_outbox}" \
    "TARGET_TRINITY=1"

# ---------------------------------------------------------------------------
# STEP 6 — Intent Lock: write plan
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 6: write plan ──────────────────────────────────────────────"
write_inbox "===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh
===TOS_PLAN_END==="

tos "${REPO_NAME}" write plan

_manifest="${TOS_LOCKS}/${REPO_NAME}_trinity_1.manifest"
assert_file_exists \
    "STEP 6: manifest visa created" \
    "${_manifest}"

assert_file_contains "STEP 6: manifest contains calculator.zsh"     "${_manifest}" "calculator.zsh"
assert_file_contains "STEP 6: manifest contains test_calculator.zsh" "${_manifest}" "test_calculator.zsh"

# ---------------------------------------------------------------------------
# STEP 7 — Red phase: write code (failing test)
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 7: write code (red — failing test) ─────────────────────────"
write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TARGET_TRINITY=1
TITLE=Red phase: add failing test
BODY=Failing test_calculator.zsh committed first (TDD red phase).
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
# This test will fail until calculator.zsh is written.
source ./calculator.zsh 2>/dev/null || { echo 'calculator.zsh missing'; exit 1; }
result=\$(add 5 5)
[[ \"\${result}\" == \"10\" ]] || { echo \"Expected 10, got \${result}\"; exit 1; }
echo 'PASS: add 5 5 = 10'
===TOS_FILE_END==="

tos "${REPO_NAME}" write code

# Confirm test_calculator.zsh is now on the branch.
_diff_files=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" \
    diff origin/main...origin/tos-work-1 --name-only 2>/dev/null || echo "")

if echo "${_diff_files}" | grep -q "test_calculator.zsh"; then
    _pass "STEP 7: test_calculator.zsh appears in branch diff"
else
    _fail "STEP 7: test_calculator.zsh NOT found in branch diff"
fi

# ---------------------------------------------------------------------------
# STEP 8 — Comment: write comment
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 8: write comment ───────────────────────────────────────────"
write_inbox "===TOS_COMMENT_START===
TARGET=1
BODY=**[STATUS]**: Red test committed. Awaiting green phase implementation.
===TOS_COMMENT_END==="

tos "${REPO_NAME}" write comment

# Verify the comment is visible on the PR.
_comments=$(gh pr view 1 \
    --repo "${REPO_NAME}" \
    --comments \
    --json comments \
    --jq '.comments[].body' 2>/dev/null || echo "")

if echo "${_comments}" | grep -q "Red test committed"; then
    _pass "STEP 8: comment containing 'Red test committed' visible on PR"
else
    _fail "STEP 8: comment not found on PR (comments: ${_comments})"
fi

# ---------------------------------------------------------------------------
# STEP 9 — Green phase: write code (implementation)
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 9: write code (green — implementation) ─────────────────────"
write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TARGET_TRINITY=1
TITLE=Green phase: implement add() and fix test
BODY=calculator.zsh implemented; test now passes.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
# calculator.zsh — basic arithmetic functions
add() { echo \$(( \$1 + \$2 )); }
===TOS_FILE_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
# test_calculator.zsh — verifies add() returns correct results
source ./calculator.zsh
result=\$(add 5 5)
[[ \"\${result}\" == \"10\" ]] || { echo \"Expected 10, got \${result}\"; exit 1; }
echo 'PASS: add 5 5 = 10'
===TOS_FILE_END==="

tos "${REPO_NAME}" write code

# Both files must be in the branch diff.
_diff_files=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" \
    diff origin/main...origin/tos-work-1 --name-only 2>/dev/null || echo "")

if echo "${_diff_files}" | grep -q "calculator.zsh"; then
    _pass "STEP 9: calculator.zsh in branch diff"
else
    _fail "STEP 9: calculator.zsh NOT in branch diff"
fi

if echo "${_diff_files}" | grep -q "test_calculator.zsh"; then
    _pass "STEP 9: test_calculator.zsh in branch diff"
else
    _fail "STEP 9: test_calculator.zsh NOT in branch diff"
fi

# ---------------------------------------------------------------------------
# STEP 10 — Trinity closure: write trinity
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 10: write trinity ──────────────────────────────────────────"

# The MANIFEST must exactly match what git diff reports.
# We compute it dynamically rather than hard-coding it.
_manifest_files=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" \
    diff origin/main...origin/tos-work-1 --name-only 2>/dev/null \
    | tr '\n' ' ' | sed 's/ $//')

write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=${REPO_NAME}
TARGET_TRINITY=1
MANIFEST=${_manifest_files}
===TOS_TRINITY_END==="

tos "${REPO_NAME}" write trinity

# PR must now be merged.
_pr_state=$(gh pr view 1 \
    --repo "${REPO_NAME}" \
    --json state \
    --jq '.state' 2>/dev/null || echo "UNKNOWN")

if [[ "${_pr_state}" == "MERGED" ]]; then
    _pass "STEP 10: PR 1 is MERGED"
else
    _fail "STEP 10: PR 1 state is '${_pr_state}' (expected MERGED)"
fi

# Issue must be closed.
_issue_state=$(gh issue view 1 \
    --repo "${REPO_NAME}" \
    --json state \
    --jq '.state' 2>/dev/null || echo "UNKNOWN")

if [[ "${_issue_state}" == "CLOSED" ]]; then
    _pass "STEP 10: issue 1 is CLOSED"
else
    _fail "STEP 10: issue 1 state is '${_issue_state}' (expected CLOSED)"
fi

# Lock and manifest files must be gone.
assert_file_not_exists \
    "STEP 10: hard lock file deleted after trinity closure" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock"

assert_file_not_exists \
    "STEP 10: manifest visa deleted after trinity closure" \
    "${TOS_LOCKS}/${REPO_NAME}_trinity_1.manifest"

# ---------------------------------------------------------------------------
# STEP 11 — Sandbox teardown: close project
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 11: close project ──────────────────────────────────────────"

# After write trinity the hard lock was released; acquire soft lock again
# so close project sees the expected soft-lock state.
write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TARGET_TRINITY=0
TITLE=Close project
BODY=Teardown local sandbox.
CONFIRM=TRUE
===TOS_META_END==="

export TOS_ACTIVE_TRINITY="0"
tos "${REPO_NAME}" close project

assert_dir_not_exists \
    "STEP 11: local sandbox directory removed" \
    "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}"

# Remote must still exist (close project does NOT delete the GitHub repo).
assert_gh_succeeds \
    "STEP 11: remote repository still exists after close project" \
    repo view "${REPO_NAME}"

# ---------------------------------------------------------------------------
# STEP 12 — Nuclear purge: delete project (MFA enforced)
# ---------------------------------------------------------------------------
echo ""
echo "── STEP 12: delete project ─────────────────────────────────────────"
echo "NOTE: This step requires interactive browser MFA."
echo "      The gh CLI will prompt you to complete an OAuth flow."
echo "      Follow the on-screen instructions."
echo ""

write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TARGET_TRINITY=0
TITLE=Delete project
BODY=Nuclear purge. MFA required.
CONFIRM=TRUE
===TOS_META_END==="

# The module must print the MFA action-required message and wait.
# We run it and let it interact with the terminal.
tos "${REPO_NAME}" delete project

# After deletion the repo must return 404.
assert_gh_fails \
    "STEP 12: gh repo view returns non-zero after deletion (repo gone)" \
    repo view "${REPO_NAME}"

# The delete_repo scope must NOT appear in the active scopes after the EXIT
# trap has fired (scope revocation).
_active_scopes=$(gh auth status 2>&1 || true)
if echo "${_active_scopes}" | grep -q "delete_repo"; then
    _fail "STEP 12: delete_repo scope still present after EXIT trap (scope not revoked)"
else
    _pass "STEP 12: delete_repo scope not present in active scopes (revoked by EXIT trap)"
fi

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════════"
if (( _FAILURES == 0 )); then
    echo "  ALL ASSERTIONS PASSED"
    echo "═══════════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ${_FAILURES} ASSERTION(S) FAILED — see [FAIL] lines above"
    echo "═══════════════════════════════════════════════════════════════════"
    exit 1
fi
