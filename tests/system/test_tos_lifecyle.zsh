# =============================================================================
# tests/system/test_tos_lifecycle.zsh
# PURPOSE: The 100% Coverage God Test (ISOLATING STEP 1).
# =============================================================================

# 1. Initialize the Fixture (Handles Deployment and Teardown Hook)
source "tests/system/fixtures/standard.zsh"

# ---------------------------------------------------------------------------
# LIFECYCLE EXECUTION
# ---------------------------------------------------------------------------
echo "── STEP 1: verify gatekeeper ───────────────────────────────────────"
assert_false "Gatekeeper blocks empty call" "$TOS_BIN_CMD"

echo "\n── STEP 1.5: intentional failure test ──────────────────────────────"
assert_true "This assertion is designed to fail" false

# =============================================================================
# 🛑 FULL LIFECYCLE COMMENTED OUT FOR STEP 1 ISOLATION TESTING 🛑
# =============================================================================

echo "\n── STEP 2: create project ──────────────────────────────────────────"
write_inbox "===TOS_META_START===
TARGET_PROJECT=${REPO_NAME}
TITLE=${REPO_NAME}
BODY=E2E Test Repository
===TOS_META_END==="
"$TOS_BIN_CMD" "${REPO_NAME}" create project
assert_gh_succeeds "Repo exists on GitHub" repo view "${REPO_NAME}"

# echo "\n── STEP 3: sync project ────────────────────────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" sync project
# assert_dir_exists "Sandbox directory created" "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}"
# assert_file_exists "SOFT_LOCK acquired" "${TOS_LOCKS}/${REPO_NAME}_trinity_0.lock"

# echo "\n── STEP 4: create issue ────────────────────────────────────────────"
# write_inbox "===TOS_ISSUE_START===
# TITLE=Implement feature A
# BODY=Primary calculation.
# ===TOS_ISSUE_END===
# ===TOS_ISSUE_START===
# TITLE=Implement feature B
# BODY=Deferred to Trinity 2.
# ===TOS_ISSUE_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" create issue
# _issue_count=$(gh issue list --repo "${REPO_NAME}" --state open --json number --jq 'length' 2>/dev/null || echo 0)
# if (( _issue_count >= 2 )); then _pass "2 issues open on GitHub"; else _fail "Issues missing on GitHub"; fi

# echo "\n── STEP 5: create trinity 1 ────────────────────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" create trinity 1
# _is_draft=$(gh pr view 1 --repo "${REPO_NAME}" --json isDraft --jq '.isDraft' 2>/dev/null || echo "false")
# if [[ "${_is_draft}" == "true" ]]; then _pass "PR 1 is a Draft"; else _fail "PR 1 is not a Draft"; fi

# echo "\n── STEP 6: sync trinity 1 ──────────────────────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" sync trinity 1
# export TOS_ACTIVE_TRINITY="1"
# _outbox="${TOS_MNT_ROOT}/.ipc/${ARCHITECT_USER}/outbox.md"
# assert_file_exists "HARD_LOCK 1 acquired" "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock"
# assert_file_contains "Outbox contains snapshot" "${_outbox}" "TARGET_TRINITY=1"

# echo "\n── STEP 7: write plan ──────────────────────────────────────────────"
# write_inbox "===TOS_PLAN_START===
# APPROVED_FILES=feature_a.zsh
# ===TOS_PLAN_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" write plan
# assert_file_exists "Manifest visa created" "${TOS_LOCKS}/${REPO_NAME}_trinity_1.manifest"

# echo "\n── STEP 8: write code ──────────────────────────────────────────────"
# write_inbox "===TOS_META_START===
# TARGET_PROJECT=${REPO_NAME}
# TARGET_TRINITY=1
# ===TOS_META_END===
# ===TOS_FILE_START: feature_a.zsh===
# #!/bin/zsh
# echo 'Feature A'
# ===TOS_FILE_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" write code
# assert_true "feature_a.zsh in branch diff" git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" diff origin/main...origin/tos-work-1 --name-only | grep -q "feature_a.zsh"

# echo "\n── STEP 9: write comment ───────────────────────────────────────────"
# write_inbox "===TOS_COMMENT_START===
# TARGET=1
# BODY=Test comment on PR.
# ===TOS_COMMENT_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" write comment
# assert_gh_output_contains "Comment visible on PR" "Test comment on PR" pr view 1 --repo "${REPO_NAME}" --comments

# echo "\n── STEP 10: sync peek ──────────────────────────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" sync peek "feature_a.zsh"
# assert_file_contains "Outbox contains peeked content" "${_outbox}" "echo 'Feature A'"

# echo "\n── STEP 11: create trinity 2 ───────────────────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" create trinity 2
# _pr_state=$(gh pr view 2 --repo "${REPO_NAME}" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
# if [[ "${_pr_state}" == "OPEN" ]]; then _pass "PR 2 is OPEN"; else _fail "PR 2 state is '${_pr_state}'"; fi

# echo "\n── STEP 12: sync trinity 2 (Atomic Handover) ───────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" sync trinity 2
# export TOS_ACTIVE_TRINITY="2"
# assert_file_exists "HARD_LOCK 2 acquired" "${TOS_LOCKS}/${REPO_NAME}_trinity_2.lock"
# assert_file_not_exists "HARD_LOCK 1 released" "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock"
# 
# _t1_remote_sha=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" ls-remote origin tos-work-1 | awk '{print $1}')
# _t1_local_sha=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" rev-parse tos-work-1)
# if [[ -n "${_t1_remote_sha}" && "${_t1_remote_sha}" == "${_t1_local_sha}" ]]; then
#     _pass "Atomic Handover: tos-work-1 successfully pushed before branch swap"
# else
#     _fail "Atomic Handover: tos-work-1 remote SHA does not match local SHA"
# fi

# echo "\n── STEP 13: close trinity 2 (Squash Merge via Module) ──────────────"
# write_inbox "===TOS_META_START===
# TARGET_PROJECT=${REPO_NAME}
# TARGET_TRINITY=2
# CONFIRM=TRUE
# ===TOS_META_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" close trinity 2
# assert_gh_output_contains "PR 2 is MERGED" "MERGED" pr view 2 --repo "${REPO_NAME}" --json state

# echo "\n── STEP 14: sync trinity 1 (Return to T1) ──────────────────────────"
# "$TOS_BIN_CMD" "${REPO_NAME}" sync trinity 1
# export TOS_ACTIVE_TRINITY="1"
# assert_file_exists "HARD_LOCK 1 re-acquired" "${TOS_LOCKS}/${REPO_NAME}_trinity_1.lock"

# echo "\n── STEP 15: write trinity (Manifest Merge) ─────────────────────────"
# _manifest_files=$(git -C "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}" diff origin/main...origin/tos-work-1 --name-only 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
# write_inbox "===TOS_TRINITY_START===
# TARGET_PROJECT=${REPO_NAME}
# TARGET_TRINITY=1
# MANIFEST=${_manifest_files}
# ===TOS_TRINITY_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" write trinity
# assert_gh_output_contains "PR 1 is MERGED via Manifest" "MERGED" pr view 1 --repo "${REPO_NAME}" --json state

# echo "\n── STEP 16: close project ──────────────────────────────────────────"
# write_inbox "===TOS_META_START===
# TARGET_PROJECT=${REPO_NAME}
# TARGET_TRINITY=0
# CONFIRM=TRUE
# ===TOS_META_END==="
# export TOS_ACTIVE_TRINITY="0"
# "$TOS_BIN_CMD" "${REPO_NAME}" close project
# assert_dir_not_exists "Local sandbox directory removed" "${TOS_SANDBOX}/${ARCHITECT_USER}/${REPO_NAME}"

# echo "\n── STEP 17: delete project ─────────────────────────────────────────"
# write_inbox "===TOS_META_START===
# TARGET_PROJECT=${REPO_NAME}
# TARGET_TRINITY=0
# CONFIRM=TRUE
# ===TOS_META_END==="
# "$TOS_BIN_CMD" "${REPO_NAME}" delete project
# assert_gh_fails "gh repo view returns non-zero (repo gone)" repo view "${REPO_NAME}"

# ---------------------------------------------------------------------------
# Final result reporting to Stregone
# ---------------------------------------------------------------------------
echo ""
if (( _FAILURES > 0 )); then
    echo "🚨 SYSTEM TEST FAILED: ${_FAILURES} assertion(s) failed."
    exit 1
else
    echo "✅ SYSTEM TEST PASSED: All active lifecycle assertions successfully executed."
fi
