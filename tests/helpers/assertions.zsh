#!/usr/bin/env zsh
# =============================================================================
# test/helpers/assertions.zsh
# =============================================================================
# PURPOSE
#   Custom assertion functions that complement ZUnit's built-in @assert.
#   Each function follows the same contract:
#     - Returns 0 on success (assertion holds).
#     - Returns 1 on failure and prints a human-readable diagnostic to stderr.
#
# ZUNIT PRIMER: ASSERTIONS
#   ZUnit provides:
#     @assert equal   "$actual"   "$expected"
#     @assert not_equal ...
#     @assert contains "$haystack" "$needle"
#   The helpers below cover filesystem and log-based assertions that ZUnit
#   doesn't provide out of the box.
# =============================================================================

# ---------------------------------------------------------------------------
# assert_file_exists <path>
# ---------------------------------------------------------------------------
function assert_file_exists() {
    local path="$1"
    if [[ -f "${path}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: expected file to exist: ${path}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_file_not_exists <path>
# ---------------------------------------------------------------------------
function assert_file_not_exists() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: expected file to NOT exist: ${path}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_dir_exists <path>
# ---------------------------------------------------------------------------
function assert_dir_exists() {
    local path="$1"
    if [[ -d "${path}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: expected directory to exist: ${path}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_dir_not_exists <path>
# ---------------------------------------------------------------------------
function assert_dir_not_exists() {
    local path="$1"
    if [[ ! -d "${path}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: expected directory to NOT exist: ${path}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_file_contains <path> <substring>
# ---------------------------------------------------------------------------
# Reads the file and checks whether it contains the given substring.
function assert_file_contains() {
    local path="$1"
    local substring="$2"

    if [[ ! -f "${path}" ]]; then
        echo "ASSERT FAIL: file does not exist: ${path}" >&2
        return 1
    fi
    if grep -qF "${substring}" "${path}"; then
        return 0
    fi
    echo "ASSERT FAIL: '${substring}' not found in ${path}" >&2
    echo "  File contents:" >&2
    cat "${path}" | sed 's/^/    /' >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_file_not_contains <path> <substring>
# ---------------------------------------------------------------------------
function assert_file_not_contains() {
    local path="$1"
    local substring="$2"

    if [[ ! -f "${path}" ]]; then
        # A non-existent file cannot contain anything — vacuously true.
        return 0
    fi
    if grep -qF "${substring}" "${path}"; then
        echo "ASSERT FAIL: '${substring}' was unexpectedly found in ${path}" >&2
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# assert_file_equals <path> <expected_content>
# ---------------------------------------------------------------------------
# Compares the entire file content (trimmed of trailing newlines) to expected.
function assert_file_equals() {
    local path="$1"
    local expected="$2"

    if [[ ! -f "${path}" ]]; then
        echo "ASSERT FAIL: file does not exist: ${path}" >&2
        return 1
    fi
    local actual
    actual=$(cat "${path}")
    if [[ "${actual}" == "${expected}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: file content mismatch in ${path}" >&2
    echo "  Expected: ${expected}" >&2
    echo "  Actual:   ${actual}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_file_empty <path>
# ---------------------------------------------------------------------------
function assert_file_empty() {
    local path="$1"
    local size
    size=$(wc -c < "${path}" 2>/dev/null || echo 1)
    if (( size == 0 )); then
        return 0
    fi
    echo "ASSERT FAIL: expected ${path} to be empty; found ${size} bytes" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_file_nonempty <path>
# ---------------------------------------------------------------------------
function assert_file_nonempty() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        echo "ASSERT FAIL: file does not exist: ${path}" >&2
        return 1
    fi
    local size
    size=$(wc -c < "${path}")
    if (( size > 0 )); then
        return 0
    fi
    echo "ASSERT FAIL: expected ${path} to be non-empty" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_mode <path> <octal_mode>
# ---------------------------------------------------------------------------
# Checks the Unix permission bits of a file or directory using `stat`.
# <octal_mode> is a string like "700" or "3770".
#
# `stat -c '%a'` prints the octal permissions on Linux.
# On macOS use `stat -f '%OLp'` — the test runner must supply the correct
# variant; here we default to Linux format.
function assert_mode() {
    local path="$1"
    local expected_mode="$2"
    local actual_mode
    actual_mode=$(stat -c '%a' "${path}" 2>/dev/null)
    if [[ "${actual_mode}" == "${expected_mode}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: mode mismatch on ${path}" >&2
    echo "  Expected: ${expected_mode}" >&2
    echo "  Actual:   ${actual_mode}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_owner <path> <username>
# ---------------------------------------------------------------------------
# Checks the owning username reported by `stat -c '%U'`.
function assert_owner() {
    local path="$1"
    local expected_owner="$2"
    local actual_owner
    actual_owner=$(stat -c '%U' "${path}" 2>/dev/null)
    if [[ "${actual_owner}" == "${expected_owner}" ]]; then
        return 0
    fi
    echo "ASSERT FAIL: owner mismatch on ${path}" >&2
    echo "  Expected: ${expected_owner}" >&2
    echo "  Actual:   ${actual_owner}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_exit_zero <description> <command...>
# ---------------------------------------------------------------------------
# Runs a command and asserts it exits 0.
# Usage: assert_exit_zero "git push succeeds" git push origin HEAD
function assert_exit_zero() {
    local description="$1"; shift
    "$@"
    local code=$?
    if (( code == 0 )); then
        return 0
    fi
    echo "ASSERT FAIL (${description}): expected exit 0, got ${code}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_exit_nonzero <description> <command...>
# ---------------------------------------------------------------------------
function assert_exit_nonzero() {
    local description="$1"; shift
    "$@"
    local code=$?
    if (( code != 0 )); then
        return 0
    fi
    echo "ASSERT FAIL (${description}): expected non-zero exit, got 0" >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_output_contains <substring> <command...>
# ---------------------------------------------------------------------------
# Runs a command, captures combined stdout+stderr, and checks for substring.
function assert_output_contains() {
    local substring="$1"; shift
    local output
    output=$( "$@" 2>&1 )
    if echo "${output}" | grep -qiF "${substring}"; then
        return 0
    fi
    echo "ASSERT FAIL: '${substring}' not found in output of: $*" >&2
    echo "  Output was:" >&2
    echo "${output}" | sed 's/^/    /' >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_output_not_contains <substring> <command...>
# ---------------------------------------------------------------------------
function assert_output_not_contains() {
    local substring="$1"; shift
    local output
    output=$( "$@" 2>&1 )
    if echo "${output}" | grep -qiF "${substring}"; then
        echo "ASSERT FAIL: '${substring}' was unexpectedly found in output of: $*" >&2
        return 1
    fi
    return 0
}
