#!/usr/bin/env zsh
# =============================================================================
# test/helpers/mocks.zsh
# =============================================================================
# PURPOSE
#   Replaces the real `gh`, `git`, and `sudo` binaries with zsh functions that
#   live only in the current shell's namespace. Because zsh resolves function
#   names before PATH lookups, these definitions shadow the real commands for
#   any code sourced afterwards in the same shell session.
#
# HOW FUNCTION-OVERRIDE MOCKING WORKS (for readers new to shell testing)
#   In zsh you can define a function with the same name as an external binary:
#
#       function git() { echo "fake git called with: $*"; }
#
#   After this definition, every invocation of `git` inside the same shell
#   (or any script sourced into it) runs YOUR function, not /usr/bin/git.
#   This is the primary mocking mechanism used throughout TOS tests.
#
# CONTROLLING MOCK BEHAVIOUR PER-TEST
#   Tests set shell variables before invoking the gateway:
#
#       TOS_MOCK_GH_OUTPUT  — text that mock `gh` prints to stdout
#       TOS_MOCK_GH_EXIT    — integer exit code mock `gh` returns (default 0)
#       TOS_MOCK_GIT_OUTPUT — text that mock `git` prints to stdout
#       TOS_MOCK_GIT_EXIT   — integer exit code mock `git` returns (default 0)
#
#   Call reset_mocks between tests to clear both the logs and these variables.
#
# LOG FILES
#   Every call appends its full argument list to a log file:
#       /tmp/tos_mock_gh_calls.log
#       /tmp/tos_mock_git_calls.log
#
#   Assertions read these files via assert_mock_called / assert_mock_not_called.
# =============================================================================

# ---------------------------------------------------------------------------
# gh — GitHub CLI mock
# ---------------------------------------------------------------------------
function gh() {
    # Append every argument, space-separated, as one line in the log.
    # "$*" expands all positional parameters as a single string.
    echo "$*" >> /tmp/tos_mock_gh_calls.log

    # Support per-command exit-code overrides.
    # Some tests need gh pr view to fail while gh issue create succeeds.
    # Convention: export TOS_MOCK_GH_EXIT_<VERB>=1 where VERB is the first arg.
    # e.g. TOS_MOCK_GH_EXIT_pr=1  makes all `gh pr ...` calls fail.
    local verb="${1:-}"
    local override_var="TOS_MOCK_GH_EXIT_${verb}"
    local exit_code="${(P)override_var:-${TOS_MOCK_GH_EXIT:-0}}"

    # Print whatever the test configured as mock output.
    echo "${TOS_MOCK_GH_OUTPUT:-}"

    return $(( exit_code ))
}

# ---------------------------------------------------------------------------
# git — Git mock
# ---------------------------------------------------------------------------
function git() {
    echo "$*" >> /tmp/tos_mock_git_calls.log

    # Allow per-verb overrides (e.g. TOS_MOCK_GIT_EXIT_push=1).
    local verb="${1:-}"
    local override_var="TOS_MOCK_GIT_EXIT_${verb}"
    local exit_code="${(P)override_var:-${TOS_MOCK_GIT_EXIT:-0}}"

    echo "${TOS_MOCK_GIT_OUTPUT:-}"

    return $(( exit_code ))
}

# ---------------------------------------------------------------------------
# sudo — privilege-escalation mock
# ---------------------------------------------------------------------------
# The real TOS gateway calls: sudo -n -u team_of_six <command> [args...]
# This mock strips those three flags and executes the remainder directly,
# so the command runs as the test user without requiring actual sudo.
#
# "$@" expands as separate quoted words (safer than "$*").
# "shift" pops the first positional argument; three shifts remove -n -u user.
function sudo() {
    shift  # drop -n
    shift  # drop -u
    shift  # drop team_of_six (or whatever user was specified)
    "$@"   # execute the remaining command in the current shell
}

# ---------------------------------------------------------------------------
# assert_mock_called <log_file> <expected_substring>
# ---------------------------------------------------------------------------
# Reads the given log file and returns 0 if any line contains the substring.
# Returns 1 (and prints a diagnostic) if no match is found.
#
# Usage:
#   assert_mock_called /tmp/tos_mock_gh_calls.log "pr merge --squash"
function assert_mock_called() {
    local log_file="$1"
    local expected="$2"

    if grep -qF "${expected}" "${log_file}" 2>/dev/null; then
        return 0
    else
        echo "ASSERT FAIL: expected mock call containing '${expected}'" >&2
        echo "  Log contents of ${log_file}:" >&2
        cat "${log_file}" 2>/dev/null | sed 's/^/    /' >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# assert_mock_not_called <log_file> <unexpected_substring>
# ---------------------------------------------------------------------------
# Returns 0 if the substring does NOT appear in the log (i.e. call was NOT made).
function assert_mock_not_called() {
    local log_file="$1"
    local unexpected="$2"

    if grep -qF "${unexpected}" "${log_file}" 2>/dev/null; then
        echo "ASSERT FAIL: unexpected mock call found: '${unexpected}'" >&2
        echo "  Log contents of ${log_file}:" >&2
        cat "${log_file}" 2>/dev/null | sed 's/^/    /' >&2
        return 1
    else
        return 0
    fi
}

# ---------------------------------------------------------------------------
# assert_mock_call_order <log_file> <first_substring> <second_substring>
# ---------------------------------------------------------------------------
# Asserts that a line matching <first_substring> appears BEFORE a line
# matching <second_substring> in the log. Used by the inbox-truncation tests
# and the delete-project PAT-before-delete ordering test.
function assert_mock_call_order() {
    local log_file="$1"
    local first="$2"
    local second="$3"

    local line_first line_second
    line_first=$(grep -nF "${first}" "${log_file}" 2>/dev/null | head -1 | cut -d: -f1)
    line_second=$(grep -nF "${second}" "${log_file}" 2>/dev/null | head -1 | cut -d: -f1)

    if [[ -z "${line_first}" ]]; then
        echo "ASSERT FAIL: '${first}' not found in ${log_file}" >&2; return 1
    fi
    if [[ -z "${line_second}" ]]; then
        echo "ASSERT FAIL: '${second}' not found in ${log_file}" >&2; return 1
    fi
    if (( line_first < line_second )); then
        return 0
    else
        echo "ASSERT FAIL: '${first}' (line ${line_first}) did not come before '${second}' (line ${line_second})" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# reset_mocks — clear all log files and unset per-test control variables
# ---------------------------------------------------------------------------
# Call this between test cases to prevent log contamination.
function reset_mocks() {
    : > /tmp/tos_mock_gh_calls.log
    : > /tmp/tos_mock_git_calls.log
    : > /tmp/tos_order.log

    # Unset all TOS_MOCK_* variables using parameter expansion pattern.
    # ${(k)parameters} gives all variable names; we filter by prefix.
    for var in ${(k)parameters[(I)TOS_MOCK_*]}; do
        unset "${var}"
    done
}
