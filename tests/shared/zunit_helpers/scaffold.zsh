function scaffold_setUp() {
    export SUDO_USER="test_architect"

    # 1. Create a true, unique isolated temporary directory per test
    mkdir -p /tmp/tos_tests
    export TOS_MNT_ROOT=$(mktemp -d /tmp/tos_tests/run_XXXXXX)

    # 2. Deploy engine into the isolated mount root
    "${PWD}/inf/tos_deploy.zsh" --mnt-root "${TOS_MNT_ROOT}" --test-mode >/dev/null 2>&1

    # 3. Source config but enforce temporary test overrides
    [[ -f "${TOS_MNT_ROOT}/.local/conf/config" ]] && source "${TOS_MNT_ROOT}/.local/conf/config"
    
    export TOS_IPC="${TOS_MNT_ROOT}/.ipc"
    export TOS_LOCKS="${TOS_IPC}/locks"
    export TOS_SANDBOX="${TOS_MNT_ROOT}/sandbox"
    export TOS_BIN="${TOS_MNT_ROOT}/.local/bin"

    # 4. Initialize Test Architect specific paths
    export TOS_INBOX="${TOS_IPC}/${SUDO_USER}/inbox.md"
    export TOS_OUTBOX="${TOS_IPC}/${SUDO_USER}/outbox.md"
    mkdir -p "${TOS_IPC}/${SUDO_USER}"
    : > "${TOS_INBOX}"
    : > "${TOS_OUTBOX}"

    # 5. Inject Test-Specific Overrides (Context/Input routing)
    cat >> "${TOS_MNT_ROOT}/.local/conf/config" <<CONFEOF
export TOS_MNT_ROOT="${TOS_MNT_ROOT}"
export TOS_IPC="${TOS_IPC}"
export TOS_LOCKS="${TOS_LOCKS}"
export TOS_SANDBOX="${TOS_SANDBOX}"
export TOS_BIN="${TOS_BIN}"
export TOS_CONTEXT="${TOS_OUTBOX}"
export TOS_INPUT="${TOS_INBOX}"
export TOS_APP_PEM="${TOS_APP_PEM}"
export TOS_GHOST_LOGIN="ghost-bot"
CONFEOF


	export TOS_TOKEN_FILE="${TOS_MNT_ROOT}/.local/conf/.token"
    chmod 0600 "${TOS_TOKEN_FILE}" 2>/dev/null || true
    echo "FAKE_GH_TOKEN" > "${TOS_TOKEN_FILE}"
    chmod 0400 "${TOS_TOKEN_FILE}"
    # 6. Route the PATH to catch mocks first
    if [[ -n "${TOS_MOCK_BIN:-}" ]]; then
        export PATH="${TOS_MOCK_BIN}:${PWD}/tests/shared/zunit_helpers/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    else
        export PATH="${PWD}/tests/shared/zunit_helpers/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    fi
    # --- Ghost credentials (stub minter) --------------------------------
    # The gateway requires a GitHub App and has NO PAT fallback, so every
    # invocation would otherwise sign a JWT and call GitHub. A dummy key and
    # a stub minter keep the suite offline and deterministic.
    #
    # This lives in the harness, not behind a TOS_TEST_MODE branch in the
    # gateway. A production path that behaves differently under test is how
    # every harness-masked defect in this project happened.
    export TOS_APP_PEM="${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem"
    export TOS_APP_ID="000000"
    export TOS_APP_INSTALL_ID="000000"
    export TOS_GHOST_LOGIN="ghost-bot"
    mkdir -p "${TOS_MNT_ROOT}/.local/conf"
    echo "not-a-real-key" > "${TOS_APP_PEM}"
    chmod 0400 "${TOS_APP_PEM}"
    cat > "${TOS_BIN}/utils/mint_app_token.zsh" <<'MINTSTUB'
#!/bin/zsh
echo "FAKE_GH_TOKEN"
MINTSTUB
    chmod +x "${TOS_BIN}/utils/mint_app_token.zsh"

}

function scaffold_tearDown() {
    setopt localoptions NULL_GLOB
    if [[ -n "${TOS_MNT_ROOT:-}" && "${TOS_MNT_ROOT}" == /tmp/tos_tests/* ]]; then
        rm -rf "${TOS_MNT_ROOT}" 2>/dev/null
    fi
    rm -rf /tmp/tos_parse_test_* 2>/dev/null
    rm -rf /tmp/tos_mock_bin_* 2>/dev/null
}

function scaffold_write_inbox() {
    cp "$1" "${TOS_INBOX}"
}
