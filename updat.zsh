cat << 'EOF' > tests/helpers/scaffold.zsh
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
    # 1. Fix PATH: Prepend mock bin AND ensure system bins are present
    export PATH="${PWD}/tests/helpers/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    # 2. Re-clean and build the tree
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null
    mkdir -p "${TOS_LOCKS}" \
             "${TOS_IPC}/${SUDO_USER}" \
             "${TOS_BIN}/utils" \
             "${TOS_CONF}" \
             "${TOS_SANDBOX}/${SUDO_USER}"

    # 3. Create config with the variable the script requires
    echo "export TOS_BIN=\"${TOS_BIN}\"" > "${TOS_CONF}/config"
    echo "FAKE_GH_TOKEN" > "${TOS_TOKEN_FILE}"
    
    # 4. Set strict permissions
    chmod 0700 "${TOS_LOCKS}"
    chmod 0700 "${TOS_SANDBOX}/${SUDO_USER}"
    chmod 3770 "${TOS_IPC}/${SUDO_USER}"
    chmod 0400 "${TOS_TOKEN_FILE}"

    : > "${TOS_INBOX}"
    : > "${TOS_OUTBOX}"
    touch "${TOS_BIN}/utils/error_trap.zsh"
}

function scaffold_tearDown() {
    setopt localoptions NULL_GLOB
    rm -rf "${TOS_MNT_ROOT}" 2>/dev/null
    rm -rf /tmp/tos_parse_test_* 2>/dev/null
}

function scaffold_write_inbox() {
    cp "$1" "${TOS_INBOX}"
}
EOF


# Fix Order and spelling for 'equal'
find tests -type f -name "*.zunit" -exec sed -i "s/assert equal \"\(.*\)\" \"\(.*\)\"/assert \"\1\" equal \"\2\"/g" {} +
find tests -type f -name "*.zunit" -exec sed -i "s/assert equals \"\(.*\)\" \"\(.*\)\"/assert \"\1\" equal \"\2\"/g" {} +

# Fix Order and spelling for 'not_equal'
find tests -type f -name "*.zunit" -exec sed -i "s/assert not_equal \"\(.*\)\" \"\(.*\)\"/assert \"\1\" not_equal \"\2\"/g" {} +
find tests -type f -name "*.zunit" -exec sed -i "s/assert not_equals \"\(.*\)\" \"\(.*\)\"/assert \"\1\" not_equal \"\2\"/g" {} +
mkdir -p tests/helpers/bin
cat << 'EOF' > tests/helpers/bin/sudo
#!/usr/bin/env zsh
# Mock sudo: strips flags if present, otherwise just executes
while [[ "$1" == -* ]]; do
    if [[ "$1" == "-u" ]]; then shift 2; else shift 1; fi
done
exec "$@"
EOF
chmod +x tests/helpers/bin/sudo

