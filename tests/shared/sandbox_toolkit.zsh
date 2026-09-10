#!/usr/bin/env zsh

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
MOCK_BIN_PATH="${REPO_ROOT}/tests/shared/bin"
API_MOCK_PATH="${REPO_ROOT}/tests/shared/mocks"

sandbox_provision() {
    local start_dir="$1"
    
    export TEST_RUN_ID=$(date +%s)_$$_${RANDOM}
    export TEST_MNT_ROOT="/tmp/tos_test_${TEST_RUN_ID}"
    
    # Deploy the engine to the unique temp path
    "${REPO_ROOT}/inf/tos_deploy.zsh" --mnt-root "$TEST_MNT_ROOT" --test-mode > /dev/null
    
    # Export Engine Context
    #
    # TOS_MNT_ROOT MUST be exported. The gateway resolves its config with
    #   export TOS_MNT_ROOT="${TOS_MNT_ROOT:-${BIN_DIR:h:h}}"
    # so an inherited value from /etc/profile.d/tos.sh wins, and the gateway
    # silently sources the PRODUCTION config instead of the sandboxed one.
    #
    # Only this variable is exported here. Everything downstream — TOS_LOCKS,
    # TOS_SANDBOX, TOS_INPUT, TOS_CONTEXT — is deliberately left to the
    # deployed config, so these tests exercise the real resolution chain
    # rather than a set of values the harness supplied to itself.
    export TOS_MNT_ROOT="$TEST_MNT_ROOT"
    export TOS_ROOT="${TEST_MNT_ROOT}/.local"
    export TOS_BIN="${TOS_ROOT}/bin"
    export TOS_WORKSPACE="${TEST_MNT_ROOT}/sandbox/$USER"
    export TOS_IPC="${TEST_MNT_ROOT}/.ipc/$USER"
    export TOS_TEST_MODE=1
    export INTERACTIVE=0
    
    # Path Interception
    if [[ "$TOS_SYSTEM_MODE" == "1" ]]; then
        export PATH="${MOCK_BIN_PATH}:${TOS_BIN}:${PATH}"
    else
        export PATH="${API_MOCK_PATH}:${MOCK_BIN_PATH}:${TOS_BIN}:${PATH}"
    fi
    rehash
    
    # Inject Start State (if provided)
    if [[ -n "$start_dir" && -d "$start_dir" ]]; then
        [[ -d "$start_dir/sandbox" ]] && cp -a "$start_dir/sandbox/"* "$TOS_WORKSPACE/" 2>/dev/null || true
        [[ -d "$start_dir/ipc" ]] && cp -a "$start_dir/ipc/"* "$TOS_IPC/" 2>/dev/null || true
    fi
}

sandbox_destroy() {
    if [[ -n "$TEST_MNT_ROOT" && "$TEST_MNT_ROOT" == /tmp/tos_test_* ]]; then
        rm -rf "$TEST_MNT_ROOT"
    fi
}

sandbox_match() {
    local end_dir="$1"
    local target_dir="$2"
    
    [[ ! -d "$end_dir" ]] && mkdir -p "/tmp/empty_ledger_dir_$$" && end_dir="/tmp/empty_ledger_dir_$$"

    local diff_output
    diff_output=$(diff -urN \
        -I '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' \
        -I '^TARGET_TRINITY=' \
        "$end_dir" "$target_dir" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "🚨 STATE DIVERGENCE DETECTED 🚨"
        echo "$diff_output"
        return 1
    fi
    return 0
}
