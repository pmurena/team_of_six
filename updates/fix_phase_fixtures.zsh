#!/usr/bin/env zsh
# ==============================================================================
# Title: Phase Gate — Test Fixture Repairs
# Usage: zsh updates/fix_phase_fixtures.zsh [--dry-run] [--yes]
#        zsh updates/fix_phase_fixtures.zsh --restore latest
#
# Three repairs, all to test fixtures. No engine code is touched.
#
#   1. tests/unit/test_phase_gate.zunit
#      `_seed_green` is defined at file scope. zunit compiles each @test body
#      into an isolated function that cannot see file-scope definitions, so
#      eleven tests error with "command not found". Moved into @setup, which
#      is the pattern the rest of the suite already uses.
#
#   2. tests/unit/modules/test_write_trinity.zunit
#   3. tests/unit/modules/test_sync_module.zunit
#      These predate the phase gate. They stand up a Trinity with a lock and a
#      manifest but no .phase record, so CHECK 0 (write trinity) and the
#      snapshot validation (sync trinity) now refuse before the behaviour under
#      test is reached. The ENGINE IS CORRECT; the fixtures describe a world
#      that no longer exists.
#
#      Each needs a phase record AND a `gh` mock that answers the validator's
#      three lookups. Their current mocks return exit 0 with empty output, so
#      the validator dies resolving the repository rather than reaching the
#      MANIFEST audit or the handover.
#
# THE COUPLING THIS EXPOSES
#   Every test that syncs or merges a Trinity now needs a valid phase record
#   and a GitHub-shaped gh mock. That is the practical cost of validating in
#   full on every read, with no fast path. It is worth noticing now rather
#   than after it has spread further through the suite.
# ==============================================================================

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

DRY_RUN=0; ASSUME_YES=0; RESTORE_STAMP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --restore) RESTORE_STAMP="$2"; shift 2 ;;
        --help|-h) sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
done

NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;34m'
_ok()   { if (( DRY_RUN )); then echo "${DIM}   would: $*${NC}"; else echo "${GREEN}✔${NC} $*"; fi }
_warn() { echo "${YELLOW}⚠${NC} $*" >&2 }
_err()  { echo "${RED}✘${NC} $*" >&2 }
_skip() { echo "${DIM}·  skipped: $*${NC}" }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$REPO_ROOT" ]] || { _err "Not inside a git repository."; exit 1; }
cd "$REPO_ROOT"
[[ -f bin/tos.zsh ]] || { _err "Not the team_of_six repo."; exit 1; }

BACKUP_ROOT="${REPO_ROOT}/.gap_backup"
if [[ -n "$RESTORE_STAMP" ]]; then
    [[ "$RESTORE_STAMP" == "latest" ]] && RESTORE_STAMP="$(ls -1 "$BACKUP_ROOT" | sort | tail -1)"
    SRC="${BACKUP_ROOT}/${RESTORE_STAMP}"
    [[ -d "$SRC" ]] || { _err "No backup at $SRC"; exit 1; }
    ( cd "$SRC" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
        mkdir -p "${REPO_ROOT}/${f:h}"; cp "$SRC/$f" "${REPO_ROOT}/$f"; echo "  restored $f"
    done
    _ok "Restore complete."
    exit 0
fi

if [[ -n "$(git status --porcelain 2>/dev/null)" && $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 ]]; then
    _warn "Working tree is dirty."
    printf "Continue anyway? [y/N] "
    read -r reply
    [[ "$reply" == [yY]* ]] || { echo "Aborted."; exit 0; }
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
typeset -a APPLIED DEFERRED
APPLIED=(); DEFERRED=()

backup() {
    local rel="$1"
    [[ -f "$rel" ]] || return 0
    (( DRY_RUN )) && return 0
    [[ -f "${BACKUP_DIR}/${rel}" ]] && return 0
    mkdir -p "${BACKUP_DIR}/${rel:h}"; cp -p "$rel" "${BACKUP_DIR}/${rel}"
}
guard() {
    local rel="$1" marker="$2"
    [[ -f "$rel" ]] || { _warn "$rel not found — skipping."; return 1; }
    grep -qF -- "$marker" "$rel" && return 0
    _warn "$rel lacks the expected marker \"${marker:0:48}...\" — skipping."
    return 1
}
already() { [[ -f "$1" ]] && grep -qF -- "$2" "$1" }
patch_it() {
    local rel="$1" search="$2" repl="$3"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would patch ${rel}${NC}"; return 0; fi
    SEARCH="$search" REPL="$repl" perl -0777 -i -pe 's/\Q$ENV{SEARCH}\E/$ENV{REPL}/' "$rel"
}
banner() { echo ""; echo "${BOLD}${BLUE}── STEP $1 ─ $2${NC}" }

echo ""
echo "${BOLD}Phase Gate — Test Fixture Repairs${NC}  ${DIM}(${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — _seed_green must live inside @setup
# ==============================================================================
banner 1 "test_phase_gate.zunit: helper into @setup"
T="tests/unit/test_phase_gate.zunit"
if already "$T" "zunit compiles each @test"; then
    _skip "$T already defines the helper inside @setup"
elif guard "$T" '# A settled red→green transition, recorded and still present on the PR.'; then
    backup "$T"
    patch_it "$T" \
'    _V="${TOS_MNT_ROOT}/.local/bin/utils/phase_validate.zsh"
}

@teardown {
    phase_mock_teardown
    scaffold_tearDown
}

# A settled red→green transition, recorded and still present on the PR.
_seed_green() {
    phase_mock_review 101 APPROVED "$PHASE_C1" "2026-01-01T10:00:00Z" pat "[PHASE:RED->GREEN] contract agreed"
    phase_mock_record 1 green "101:${PHASE_C1}:2026-01-01T10:00:00Z"
}' \
'    _V="${TOS_MNT_ROOT}/.local/bin/utils/phase_validate.zsh"

    # A settled red→green transition, recorded and still present on the PR.
    #
    # Defined HERE rather than at file scope: zunit compiles each @test body
    # into an isolated function that cannot see file-scope definitions. A
    # helper declared outside @setup fails with "command not found".
    _seed_green() {
        phase_mock_review 101 APPROVED "$PHASE_C1" "2026-01-01T10:00:00Z" pat "[PHASE:RED->GREEN] contract agreed"
        phase_mock_record 1 green "101:${PHASE_C1}:2026-01-01T10:00:00Z"
    }
}

@teardown {
    phase_mock_teardown
    scaffold_tearDown
}'
    _ok "Moved _seed_green into @setup"
    APPLIED+=("1")
else
    DEFERRED+=("1 — test_phase_gate.zunit")
fi

# ==============================================================================
# STEP 2 — write trinity fixtures
# ==============================================================================
banner 2 "test_write_trinity.zunit: phase record + validator-aware gh mock"
T="tests/unit/modules/test_write_trinity.zunit"

# 2a — teach the gh mock the validator's three lookups
if already "$T" "phase gate queries GitHub"; then
    _skip "2a: gh mock already answers the validator"
elif guard "$T" 'cat > "${TOS_MOCK_BIN}/gh" <<'"'"'INNEREOF'"'"'
#!/usr/bin/env zsh
echo "$*" >> /tmp/tos_mock_gh_calls.log
exit 0
INNEREOF'; then
    backup "$T"
    patch_it "$T" \
'cat > "${TOS_MOCK_BIN}/gh" <<'"'"'INNEREOF'"'"'
#!/usr/bin/env zsh
echo "$*" >> /tmp/tos_mock_gh_calls.log
exit 0
INNEREOF' \
'cat > "${TOS_MOCK_BIN}/gh" <<'"'"'INNEREOF'"'"'
#!/usr/bin/env zsh
echo "$*" >> /tmp/tos_mock_gh_calls.log
# CHECK 0 runs the phase gate before CHECK 1, and the validator resolves the
# repository, the PR and the Ghost login before it can report a phase. Without
# these branches it dies on "No GitHub repository visible to the Ghost" and the
# MANIFEST audit under test is never reached.
if [[ "$*" == *"repo view"* ]]; then echo "test/team_of_six"; exit 0; fi
if [[ "$*" == *"pr view"* ]]; then echo "7"; exit 0; fi
if [[ "$1" == "api" && "$2" == "user" ]]; then echo "test_architect"; exit 0; fi
exit 0
INNEREOF'
    _ok "2a: gh mock now answers repo view, pr view and api user"
    APPLIED+=("2a")
else
    DEFERRED+=("2a — test_write_trinity.zunit gh mock")
fi

# 2b — a phase record at retrospect, so CHECK 0 passes
if already "$T" '_trinity_1.phase'; then
    _skip "2b: phase record already seeded"
elif guard "$T" 'printf "calculator.zsh\ntest_calculator.zsh\n" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"'; then
    backup "$T"
    patch_it "$T" \
'printf "calculator.zsh\ntest_calculator.zsh\n" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"' \
'printf "calculator.zsh\ntest_calculator.zsh\n" > "${TOS_LOCKS}/team_of_six_trinity_1.manifest"
    # The phase gate refuses to merge outside retrospect. These tests exercise
    # the MANIFEST audit, not the phase gate, so the Trinity is seeded at the
    # only phase from which a merge is legal. Slots are left empty: with none
    # recorded the validator has no reviews to re-resolve.
    printf "current=retrospect\nred=\ngreen=\nrefactor=\nretrospect=\n" > "${TOS_LOCKS}/team_of_six_trinity_1.phase"'
    _ok "2b: seeded a retrospect phase record"
    APPLIED+=("2b")
else
    DEFERRED+=("2b — test_write_trinity.zunit phase record")
fi

# ==============================================================================
# STEP 3 — sync trinity handover fixture
# ==============================================================================
banner 3 "test_sync_module.zunit: handover test needs a phase record"
T="tests/unit/modules/test_sync_module.zunit"

if already "$T" "The snapshot validates the phase"; then
    _skip "$T handover test already seeded"
elif guard "$T" "@test '[sync trinity — handover] Syncing from Trinity 0 skips pushing tos-work-0' {"; then
    backup "$T"
    patch_it "$T" \
"    # We are already on Trinity 0 (from @setup)
    cat > \"\${TOS_INBOX}\" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
===TOS_META_END===
PAYLOAD" \
"    # We are already on Trinity 0 (from @setup)
    cat > \"\${TOS_INBOX}\" <<'PAYLOAD'
===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=0
===TOS_META_END===
PAYLOAD

    # The snapshot validates the phase in full before emitting PHASE=, and
    # halts the sync if the record is missing. This test is about the handover
    # not pushing tos-work-0, so the destination Trinity is given a record.
    printf \"current=red\\nred=\\ngreen=\\nrefactor=\\nretrospect=\\n\" > \"\${TOS_LOCKS}/team_of_six_trinity_1.phase\""
    _ok "3a: seeded a phase record for the destination Trinity"
    APPLIED+=("3a")
else
    DEFERRED+=("3 — test_sync_module.zunit handover")
fi

# 3b — that test's gh comes from the generic mock, which returns nothing.
if already "$T" "validator resolves the repository"; then
    _skip "3b: handover gh mock already present"
elif guard "$T" '    chmod +x "${TOS_MOCK_BIN}/git"
    rm -f /tmp/tos_mock_git_push.log
    
    local exit_code=0
    local output'; then
    backup "$T"
    patch_it "$T" \
'    chmod +x "${TOS_MOCK_BIN}/git"
    rm -f /tmp/tos_mock_git_push.log
    
    local exit_code=0
    local output' \
'    chmod +x "${TOS_MOCK_BIN}/git"

    # The validator resolves the repository, the PR and the Ghost login before
    # it can report a phase. The generic mock returns empty output, which kills
    # it before the handover under test happens.
    cat > "${TOS_MOCK_BIN}/gh" <<'"'"'INNER'"'"'
#!/usr/bin/env zsh
if [[ "$*" == *"repo view"* ]]; then echo "test/team_of_six"; exit 0; fi
if [[ "$*" == *"pr view"* ]]; then echo "7"; exit 0; fi
if [[ "$1" == "api" && "$2" == "user" ]]; then echo "test_architect"; exit 0; fi
exit 0
INNER
    chmod +x "${TOS_MOCK_BIN}/gh"

    rm -f /tmp/tos_mock_git_push.log
    
    local exit_code=0
    local output'
    _ok "3b: added a validator-aware gh mock to the handover test"
    APPLIED+=("3b")
else
    DEFERRED+=("3b — test_sync_module.zunit gh mock")
fi

# ==============================================================================
echo ""
echo "${BOLD}${BLUE}═════════════════════════ SUMMARY ═════════════════════════${NC}"
(( ${#APPLIED} )) && { if (( DRY_RUN )); then echo "${DIM}   would apply: ${APPLIED[*]}${NC}"; else echo "${GREEN}✔${NC} Applied: ${APPLIED[*]}"; fi }
if (( ${#DEFERRED} )); then
    echo ""; _warn "Deferred (precondition not met — inspect manually):"
    for s in "${DEFERRED[@]}"; do echo "      $s"; done
fi
if (( DRY_RUN )); then
    echo ""; echo "${YELLOW}Dry run. Re-run without --dry-run to apply.${NC}"
else
    echo ""; echo "Backups:  ${BACKUP_DIR}"
    echo "Restore:  zsh updates/fix_phase_fixtures.zsh --restore ${STAMP}"
fi

cat <<'FOOTER_EOF'

────────────────────────────────────────────────────────────────
NEXT
────────────────────────────────────────────────────────────────

    zunit tests/inf tests/unit

EXPECT 112 TESTS, EXACTLY 3 RED — and only these three:

    · [apply — negative] A backward transition is refused outright
    · [apply — negative] Skipping a phase is refused
    · [apply — negative] CHANGES_REQUESTED never moves the phase

That is the forward-only change, and the red bar is the point.

Anything else red is a real problem. In particular, if
[write trinity — positive] or [sync trinity — handover] are still red, the
fixture seeding did not take and the diagnostic in the output will say which
of the validator's lookups failed.

GREEN PHASE AFTER THAT
    bin/utils/phase_validate.zsh — invariant 4 becomes "exactly one step
    ahead, verdict APPROVED". Backward handling removed, not narrowed.

FOOTER_EOF
exit 0
