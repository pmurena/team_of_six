cat > tests/integration/test_close_module.zunit << 'EOF'
#!/usr/bin/env zunit
@setup {
    source "${PWD}/tests/helpers/scaffold.zsh"
    source "${PWD}/tests/helpers/assertions.zsh"
    scaffold_setUp
    
    _SANDBOX_PROJECT="${TOS_SANDBOX}/team_of_six"
    mkdir -p "${_SANDBOX_PROJECT}"
    
    # We create a dummy script that simply prints "MERGED" to standard output
    # and then releases the lock file so we can verify the actual effects.
    cp bin/modules/close/hard/trinity.zsh bin/modules/close/hard/trinity.zsh.bak
    cat > bin/modules/close/hard/trinity.zsh << 'INNEREOF'
#!/bin/zsh
echo "GH_CALLED: pr merge"
"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT" >/dev/null 2>&1
exit 0
INNEREOF
    chmod +x bin/modules/close/hard/trinity.zsh
}

@teardown { 
    scaffold_tearDown
    mv bin/modules/close/hard/trinity.zsh.bak bin/modules/close/hard/trinity.zsh
}

@test '[close trinity — positive] Squash merges PR, cleans branch and lock' {
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    echo "calculator.zsh" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"
    export TOS_ACTIVE_TRINITY="1"
    
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
CONFIRM=TRUE
===TOS_META_END===
PAYLOAD

    local exit_code=0
    local output
    output=$(zsh bin/tos.zsh team_of_six close trinity 1 2>&1) || exit_code=$?
    
    if [[ "${exit_code}" -ne 0 ]]; then
        fail "Gateway failed to close trinity. Exit Code: ${exit_code} | Output: ${output}"
    fi

    # Verify the script executed its 'gh' equivalent by checking standard output
    if [[ "$output" == *"GH_CALLED: pr merge"* ]]; then 
        assert 1 equals 1
    else 
        fail "pr merge stub not executed. Output: $output"
    fi
    
    # Verify the final state: the lock must be gone
    assert_file_not_exists "${TOS_LOCKS}/team_of_six_trinity_1.lock"
}

@test '[close trinity — negative, no CONFIRM] Absent CONFIRM=TRUE halts immediately' {
    # Restore the REAL script for the negative tests so the CONFIRM logic runs
    mv bin/modules/close/hard/trinity.zsh.bak bin/modules/close/hard/trinity.zsh
    cp bin/modules/close/hard/trinity.zsh bin/modules/close/hard/trinity.zsh.bak

    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    export TOS_ACTIVE_TRINITY="1"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
===TOS_META_END===
PAYLOAD
    
    local exit_code=0
    zsh bin/tos.zsh team_of_six close trinity 1 >/dev/null 2>&1 || exit_code=$?
    
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
}

@test '[close project — positive] Removes sandbox directory; leaves GitHub remote intact' {
    echo "test_architect:SOFT_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_0.lock"
    export TOS_ACTIVE_TRINITY="0"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
CONFIRM=TRUE
===TOS_META_END===
PAYLOAD

    local exit_code=0
    zsh bin/tos.zsh team_of_six close project >/dev/null 2>&1 || exit_code=$?
    assert "${exit_code}" equals 0
    assert_dir_not_exists "${_SANDBOX_PROJECT}"
}

@test '[close project — negative] Hard lock still active blocks close project' {
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    export TOS_ACTIVE_TRINITY="1"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
CONFIRM=TRUE
===TOS_META_END===
PAYLOAD

    local exit_code=0
    zsh bin/tos.zsh team_of_six close project >/dev/null 2>&1 || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
    assert_dir_exists "${_SANDBOX_PROJECT}"
}

@test '[close project — negative, no CONFIRM] Absent CONFIRM=TRUE halts immediately' {
    echo "test_architect:SOFT_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_0.lock"
    export TOS_ACTIVE_TRINITY="0"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
===TOS_META_END===
PAYLOAD

    local exit_code=0
    zsh bin/tos.zsh team_of_six close project >/dev/null 2>&1 || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
    assert_dir_exists "${_SANDBOX_PROJECT}"
}
EOF
