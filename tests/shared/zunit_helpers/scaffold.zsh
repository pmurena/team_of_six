#!/usr/bin/env zsh

# Define these globally so they are available to the test runner process
export TOS_MNT_ROOT="/tmp/tos_test_root"
export SUDO_USER="test_architect"
export TOS_IPC="${TOS_MNT_ROOT}/.ipc"
export TOS_LOCKS="${TOS_IPC}/locks"
export TOS_SANDBOX="${TOS_MNT_ROOT}/sandbox"
export TOS_LOCAL="${TOS_MNT_ROOT}/.local"
export TOS_CONF="${TOS_LOCAL}/conf"
export TOS_TOKEN_FILE="${TOS_CONF}/.token"
export TOS_INBOX="${TOS_IPC}/${SUDO_USER}/inbox.md"
export TOS_OUTBOX="${TOS_IPC}/${SUDO_USER}/outbox.md"
export TOS_BIN="${TOS_LOCAL}/bin"

function scaffold_setUp() {
    # 1. Fix PATH: Prepend mock bin ONLY if defined, and ensure system bins are present
    if [[ -n "${TOS_MOCK_BIN:-}" ]]; then
        export PATH="${TOS_MOCK_BIN}:${PWD}/tests/shared/zunit_helpers/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    else
        export PATH="${PWD}/tests/shared/zunit_helpers/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    fi

    # 2. Re-clean and build the tree
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null
    mkdir -p "${TOS_LOCKS}" \
             "${TOS_IPC}/${SUDO_USER}" \
             "${TOS_BIN}/utils/lock" \
             "${TOS_CONF}" \
             "${TOS_SANDBOX}/${SUDO_USER}"

    # 3. Create config with all variables the gateway requires
    cat > "${TOS_CONF}/config" <<CONFEOF
export TOS_BIN="${TOS_BIN}"
export TOS_IPC="${TOS_IPC}"
export TOS_LOCKS="${TOS_LOCKS}"
export TOS_SANDBOX="${TOS_SANDBOX}"
export TOS_CONTEXT="${TOS_OUTBOX}"
export TOS_INPUT="${TOS_INBOX}"
export TOS_MNT_ROOT="${TOS_MNT_ROOT}"
CONFEOF

    echo "FAKE_GH_TOKEN" > "${TOS_TOKEN_FILE}"

    # 4. Set strict permissions
    chmod 0700 "${TOS_LOCKS}"
    chmod 0700 "${TOS_SANDBOX}/${SUDO_USER}"
    chmod 3770 "${TOS_IPC}/${SUDO_USER}"
    chmod 0400 "${TOS_TOKEN_FILE}"

    : > "${TOS_INBOX}"
    : > "${TOS_OUTBOX}"

    # 5. Symlink production utilities
    local _REAL_UTILS="${PWD}/bin/utils"
    for f in "${_REAL_UTILS}"/*.zsh(N); do
        ln -sf "$f" "${TOS_BIN}/utils/$(basename "$f")"
    done
    for f in "${_REAL_UTILS}/lock"/*.zsh(N); do
        ln -sf "$f" "${TOS_BIN}/utils/lock/$(basename "$f")"
    done

    touch "${TOS_BIN}/utils/error_trap.zsh"

    # 6. Symlink production modules
    local _REAL_MODULES="${PWD}/bin/modules"
    if [[ -d "${_REAL_MODULES}" ]]; then
        mkdir -p "${TOS_BIN}/modules"
        for mod_dir in "${_REAL_MODULES}"/*(N/); do
            local mod_name="${mod_dir:t}"
            mkdir -p "${TOS_BIN}/modules/${mod_name}"
            for tier in soft hard; do
                if [[ -d "${mod_dir}/${tier}" ]]; then
                    mkdir -p "${TOS_BIN}/modules/${mod_name}/${tier}"
                    for script in "${mod_dir}/${tier}"/*.zsh(N); do
                        ln -sf "$script" "${TOS_BIN}/modules/${mod_name}/${tier}/$(basename "$script")"
                    done
                fi
            done
        done
    fi
}

function scaffold_tearDown() {
    setopt localoptions NULL_GLOB
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null
    rm -rf /tmp/tos_parse_test_* 2>/dev/null
}

function scaffold_write_inbox() {
    cp "$1" "${TOS_INBOX}"
}
