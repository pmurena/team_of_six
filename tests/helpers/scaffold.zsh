#!/usr/bin/env zsh
# =============================================================================
# test/helpers/scaffold.zsh
# =============================================================================
# PURPOSE
#   Every test suite sources this file first. It builds a fake control-plane
#   tree under /tmp/tos_test_root, exports the environment variables that TOS
#   scripts expect, and provides a tearDown function that cleans everything up.
#
# ZSH / ZUNIT PRIMER FOR NEW READERS
#   - "source file.zsh"  : run the file inside the current shell (same process,
#                          shares variables). Used here so the test process can
#                          inspect side-effects.
#   - "export VAR=value" : make the variable visible to child processes.
#   - "$(...)"           : run a command and capture its output as a string.
#   - "(( expr ))"       : arithmetic evaluation; returns 0 (true) if non-zero.
#   - "[[ cond ]]"       : conditional test; preferred over [ ] in zsh.
# =============================================================================

# ---------------------------------------------------------------------------
# Canonical paths used by the fake control plane
# ---------------------------------------------------------------------------
# These match the layout documented in Section 2 of test-concept-v2.md.
# Every variable is exported so that child processes (i.e. the scripts under
# test) see the same values.

export TOS_MNT_ROOT="/tmp/tos_test_root"
export SUDO_USER="test_architect"
export TOS_CONTROLLER_LOCKED="true"
export TOS_ACTIVE_PROJECT="test-project"
export TOS_ACTIVE_TRINITY="0"

# Derived paths — computed once here so tests don't hard-code strings.
export TOS_IPC="${TOS_MNT_ROOT}/.ipc"
export TOS_LOCKS="${TOS_IPC}/locks"
export TOS_INBOX="${TOS_IPC}/${SUDO_USER}/inbox.md"
export TOS_OUTBOX="${TOS_IPC}/${SUDO_USER}/outbox.md"
export TOS_SANDBOX="${TOS_MNT_ROOT}/sandbox"
export TOS_LOCAL="${TOS_MNT_ROOT}/.local"
export TOS_CONF="${TOS_LOCAL}/conf"
export TOS_TOKEN_FILE="${TOS_CONF}/.token"

# ---------------------------------------------------------------------------
# setUp — called at the top of every test suite (or @setup block in ZUnit)
# ---------------------------------------------------------------------------
function scaffold_setUp() {
    # Remove any leftover state from a previous run.
    [[ -d "${TOS_MNT_ROOT}" ]] && rm -rf "${TOS_MNT_ROOT}"

    # Create the directory tree.
    # -p : create all intermediate directories without error if they exist.
    mkdir -p \
        "${TOS_LOCKS}" \
        "${TOS_IPC}/${SUDO_USER}" \
        "${TOS_LOCAL}/bin" \
        "${TOS_CONF}" \
        "${TOS_SANDBOX}/${SUDO_USER}"

    # Apply the access-control modes documented in the spec (ADR 5).
    # 0700 = owner can read/write/execute; group and other have no access.
    chmod 0700 "${TOS_LOCKS}"
    chmod 0700 "${TOS_SANDBOX}/${SUDO_USER}"
    # 3770 = setgid + group read/write/execute (IPC ribbon shared by group).
    chmod 3770 "${TOS_IPC}/${SUDO_USER}"

    # Seed the inbox and outbox as empty files.
    : > "${TOS_INBOX}"
    : > "${TOS_OUTBOX}"

    # Write a fake PAT token so scripts that source .token don't abort.
    # 0400 = read-only for owner (matches production permission).
    echo "FAKE_GH_TOKEN" > "${TOS_TOKEN_FILE}"
    chmod 0400 "${TOS_TOKEN_FILE}"

    # Clear the mock call-log files used by mocks.zsh.
    : > /tmp/tos_mock_gh_calls.log
    : > /tmp/tos_mock_git_calls.log

    # Clear any leftover ordering logs used by inbox-truncation tests.
    : > /tmp/tos_order.log
}

# ---------------------------------------------------------------------------
# tearDown — called at the bottom of every test suite (or @teardown block)
# ---------------------------------------------------------------------------
function scaffold_tearDown() {
    # Blow away the entire fake root. Any test that left files here will have
    # them silently cleaned up. The 2>/dev/null suppresses "no such file"
    # errors if setUp was never fully completed.
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null

    # Also clean up any per-test parse output directories.
    rm -rf /tmp/tos_parse_test_* 2>/dev/null

    # Clean up mock logs.
    rm -f /tmp/tos_mock_gh_calls.log \
          /tmp/tos_mock_git_calls.log \
          /tmp/tos_order.log \
          /tmp/tos_mock_gh_exit_override \
          2>/dev/null
}

# ---------------------------------------------------------------------------
# Convenience: write a fixture payload directly into the fake inbox.
# Usage: scaffold_write_inbox <fixture_file_path>
# ---------------------------------------------------------------------------
function scaffold_write_inbox() {
    local fixture_path="$1"
    if [[ ! -f "${fixture_path}" ]]; then
        echo "scaffold_write_inbox: fixture not found: ${fixture_path}" >&2
        return 1
    fi
    cp "${fixture_path}" "${TOS_INBOX}"
}

# ---------------------------------------------------------------------------
# Convenience: assert that the inbox is zero bytes (truncation invariant).
# ---------------------------------------------------------------------------
function scaffold_assert_inbox_empty() {
    local size
    size=$(wc -c < "${TOS_INBOX}")
    if (( size != 0 )); then
        echo "FAIL: inbox is not empty; contains ${size} bytes" >&2
        return 1
    fi
    return 0
}
