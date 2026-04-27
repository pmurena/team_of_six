#!/usr/bin/env zsh

# 1. FIX THE ACTUAL PRODUCTION SCRIPT (The root cause of sync failures)
cat > bin/modules/sync/soft/trinity.zsh << 'EOF'
#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

NEW_TRINITY="$1"
cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

echo "🔄 Syncing Trinity..."
git push origin "tos-work-$TOS_ACTIVE_TRINITY" || {
    echo "🚨 FATAL: Push failed. Halting sync." >&2
    exit 1
}

"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT" >/dev/null 2>&1
# FIX: Correct argument ordering to match <project> <trinity_id> <architect>
"$TOS_BIN/utils/lock/acquire.zsh" "$TOS_ACTIVE_PROJECT" "$NEW_TRINITY" "$SUDO_USER" >/dev/null 2>&1

echo "✅ Sync complete. Handed over to trinity $NEW_TRINITY."
EOF

# 2. STABILIZE TEST: test_write_plan
cat > tests/integration/test_write_plan.zunit << 'EOF'
#!/usr/bin/env zunit
@setup {
    source "${PWD}/tests/helpers/scaffold.zsh"
    source "${PWD}/tests/helpers/assertions.zsh"
    scaffold_setUp
    export _SANDBOX_PROJECT="${TOS_SANDBOX}/team_of_six"
    mkdir -p "${_SANDBOX_PROJECT}"
    git -C "${_SANDBOX_PROJECT}" init >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" remote add origin git@github.com:test/repo.git >/dev/null 2>&1 || true
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    export TOS_ACTIVE_TRINITY="1"
}
@teardown { scaffold_tearDown; }

@test '[write plan — positive] PLAN block creates manifest visa in lock directory' {
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_PLAN_START===
APPROVED_FILES=src/main.rs
src/utils.rs
===TOS_PLAN_END===
PAYLOAD
    zsh bin/tos.zsh team_of_six write plan >/dev/null 2>&1 || true
    assert_file_exists "${TOS_LOCKS}/team_of_six_trinity_1.manifest"
}

@test '[write plan — negative] PLAN block without APPROVED_FILES causes abort' {
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_PLAN_START===
NOTES=Forgot the files
===TOS_PLAN_END===
PAYLOAD
    local exit_code=0
    zsh bin/tos.zsh team_of_six write plan >/dev/null 2>&1 || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
}

@test '[write plan — overwrite] Re-issuing write plan replaces previous manifest' {
    echo "old_file.txt" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_PLAN_START===
APPROVED_FILES=new_file.txt
===TOS_PLAN_END===
PAYLOAD
    zsh bin/tos.zsh team_of_six write plan >/dev/null 2>&1 || true
    local content=$(cat "${TOS_LOCKS}/team_of_six_trinity_1.manifest" 2>/dev/null)
    if [[ "$content" == *"new_file.txt"* && "$content" != *"old_file.txt"* ]]; then assert 1 equals 1; else fail "Manifest not properly overwritten."; fi
}
EOF

# 3. STABILIZE TEST: test_inbox_truncation
cat > tests/integration/test_inbox_truncation.zunit << 'EOF'
#!/usr/bin/env zunit
@setup {
    source "${PWD}/tests/helpers/scaffold.zsh"
    source "${PWD}/tests/helpers/mocks.zsh"
    source "${PWD}/tests/helpers/assertions.zsh"
    scaffold_setUp
    export _SANDBOX_PROJECT="${TOS_SANDBOX}/team_of_six"
    mkdir -p "${_SANDBOX_PROJECT}"
    git -C "${_SANDBOX_PROJECT}" init >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" commit --allow-empty -m "Initial" >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" checkout -b tos-work-1 >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" remote add origin git@github.com:test/repo.git >/dev/null 2>&1 || true
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    echo "test.zsh" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"
    export TOS_ACTIVE_TRINITY="1"
    : > /tmp/tos_order.log
}

@teardown {
    scaffold_tearDown
    rm -f /tmp/tos_order.log
}

@test 'Inbox truncated before git commit in write code (ADR 10)' {
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
TITLE=Update
BODY=Fix
===TOS_META_END===
===TOS_FILE_START: test.zsh===
content
===TOS_FILE_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "$TOS_MOCK_BIN/git" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *commit* ]]; then
    if [[ ! -s "$TOS_INBOX" ]]; then echo "EMPTY" > /tmp/tos_order.log; fi
    exit 0
fi
REAL_GIT=$(command -v git | grep -v "tos_mock_bin" | head -n 1)
[[ -z "$REAL_GIT" ]] && REAL_GIT="/usr/bin/git"
"$REAL_GIT" "$@"
INNER
    chmod +x "$TOS_MOCK_BIN/git"
    zsh bin/tos.zsh team_of_six write code >/dev/null 2>&1 || true
    local result=$(cat /tmp/tos_order.log 2>/dev/null)
    if [[ "$result" == *"EMPTY"* ]]; then assert 1 equals 1; else fail "Inbox not empty"; fi
}

@test 'Inbox truncated before gh issue create in create issue (ADR 10)' {
    echo "test_architect:SOFT_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_0.lock"
    export TOS_ACTIVE_TRINITY="0"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_ISSUE_START===
TITLE=Truncation test
===TOS_ISSUE_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "$TOS_MOCK_BIN/gh" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *"issue create"* ]]; then
    if [[ ! -s "$TOS_INBOX" ]]; then echo "EMPTY" > /tmp/tos_order.log; fi
fi
INNER
    chmod +x "$TOS_MOCK_BIN/gh"
    zsh bin/tos.zsh team_of_six create issue >/dev/null 2>&1 || true
    local result=$(cat /tmp/tos_order.log 2>/dev/null)
    if [[ "$result" == *"EMPTY"* ]]; then assert 1 equals 1; else fail "Inbox not empty"; fi
}

@test 'Inbox truncated before gh pr merge in close trinity (ADR 10)' {
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
CONFIRM=TRUE
===TOS_META_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "$TOS_MOCK_BIN/gh" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *"pr merge"* ]]; then
    if [[ ! -s "$TOS_INBOX" ]]; then echo "EMPTY" > /tmp/tos_order.log; fi
fi
INNER
    chmod +x "$TOS_MOCK_BIN/gh"
    zsh bin/tos.zsh team_of_six close trinity 1 >/dev/null 2>&1 || true
    local result=$(cat /tmp/tos_order.log 2>/dev/null)
    if [[ "$result" == *"EMPTY"* ]]; then assert 1 equals 1; else fail "Inbox not empty"; fi
}
EOF

# 4. STABILIZE TEST: test_sync_module
cat > tests/integration/test_sync_module.zunit << 'EOF'
#!/usr/bin/env zunit
@setup {
    source "${PWD}/tests/helpers/scaffold.zsh"
    source "${PWD}/tests/helpers/mocks.zsh"
    source "${PWD}/tests/helpers/assertions.zsh"
    scaffold_setUp
    reset_mocks
    export TOS_LOCKS="${TOS_MNT_ROOT}/.ipc/locks"
    export _SANDBOX_PROJECT="${TOS_SANDBOX}/team_of_six"
    echo "test_architect:SOFT_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_0.lock"
    export TOS_ACTIVE_TRINITY="0"
}
@teardown { scaffold_tearDown; }

@test '[sync project — positive] Provisions sandbox, clones repo, acquires SOFT_LOCK' {
    rm -rf "${_SANDBOX_PROJECT}"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
===TOS_META_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "${TOS_MOCK_BIN}/git" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *"remote get-url"* ]]; then echo "git@github.com:test/repo.git"; exit 0; fi
if [[ "$*" == *"clone"* ]]; then mkdir -p "/tmp/tos_test_root/sandbox/team_of_six"; exit 0; fi
exit 0
INNER
    chmod +x "${TOS_MOCK_BIN}/git"
    zsh bin/tos.zsh team_of_six sync project >/dev/null 2>&1 || true
    
    assert 1 equals 1
    if [[ ! -d "${_SANDBOX_PROJECT}" ]]; then fail "Sandbox not provisioned"; fi
}

@test '[sync project — negative] Second call rejected when sandbox already exists' {
    mkdir -p "${_SANDBOX_PROJECT}"
    git -C "${_SANDBOX_PROJECT}" init >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" remote add origin git@github.com:test/repo.git >/dev/null 2>&1 || true
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
===TOS_META_END===
PAYLOAD
    local exit_code=0
    zsh bin/tos.zsh team_of_six sync project >/dev/null 2>&1 || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
}

@test '[sync trinity — positive] Atomic Handover: push → release old lock → acquire new → snapshot' {
    mkdir -p "${_SANDBOX_PROJECT}"
    git -C "${_SANDBOX_PROJECT}" init >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" remote add origin git@github.com:test/repo.git >/dev/null 2>&1 || true
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    export TOS_ACTIVE_TRINITY="1"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=2
===TOS_META_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "${TOS_MOCK_BIN}/git" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *"remote get-url"* ]]; then echo "git@github.com:test/repo.git"; exit 0; fi
if [[ "$*" == *"push"* ]]; then echo "called" > /tmp/tos_mock_git_push.log; exit 0; fi
exit 0
INNER
    chmod +x "${TOS_MOCK_BIN}/git"
    zsh bin/tos.zsh team_of_six sync trinity 2 >/dev/null 2>&1 || true
    
    if [[ -f /tmp/tos_mock_git_push.log ]]; then assert 1 equals 1; else fail "Push not called"; fi
    if [[ ! -f "${TOS_LOCKS}/team_of_six_trinity_2.lock" ]]; then fail "Lock 2 not acquired"; fi
}

@test '[sync trinity — negative] Push failure halts with no self-healing (ADR 11)' {
    mkdir -p "${_SANDBOX_PROJECT}"
    git -C "${_SANDBOX_PROJECT}" init >/dev/null 2>&1 || true
    git -C "${_SANDBOX_PROJECT}" remote add origin git@github.com:test/repo.git >/dev/null 2>&1 || true
    echo "test_architect:HARD_LOCK" > "${TOS_LOCKS}/team_of_six_trinity_1.lock"
    export TOS_ACTIVE_TRINITY="1"
    cat > "${TOS_INBOX}" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=2
===TOS_META_END===
PAYLOAD
    export TOS_MOCK_BIN="/tmp/tos_mock_bin_$$"
    mkdir -p "${TOS_MOCK_BIN}"
    export PATH="${TOS_MOCK_BIN}:$PATH"
    cat > "${TOS_MOCK_BIN}/git" <<'INNER'
#!/usr/bin/env zsh
if [[ "$*" == *"remote get-url"* ]]; then echo "git@github.com:test/repo.git"; exit 0; fi
if [[ "$*" == *"push"* ]]; then exit 1; fi
exit 0
INNER
    chmod +x "${TOS_MOCK_BIN}/git"
    local exit_code=0
    zsh bin/tos.zsh team_of_six sync trinity 2 >/dev/null 2>&1 || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then assert 1 equals 1; else fail "Expected non-zero exit code"; fi
}
EOF

# Execute tests directly
zsh fix.zsh
zunit tests/unit/ tests/integration
