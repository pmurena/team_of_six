#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Forward-Only Phase Gate — RED PHASE
# Usage: zsh updates/add_forward_only_tests.zsh [--dry-run] [--yes]
#
# INSTALLS TESTS ONLY. THEY ARE EXPECTED TO FAIL.
#
# The phase gate becomes FORWARD-ONLY. A transition must advance exactly one
# step (red → green → refactor → retrospect) and carry an APPROVED verdict.
# Backward transitions and skips are refused. `--request-changes` reverts to
# an ordinary review the Agent answers via `write code`, leaving the phase
# untouched.
#
# This is the last migration script before TOS builds TOS. Everything after
# it goes through the protocol: an issue, a trinity, a visa, phase-gated
# reviews, a merge.
#
# FILES INSTALLED
#   tests/shared/zunit_helpers/phase_mocks.zsh   (NEW)
#   tests/unit/test_phase_gate.zunit             (NEW)
#
# WHY NEW MOCKS
#   The existing mocks return exit 0 and a fixed string for everything. Run
#   the validator against them and it passes — not because the invariants
#   hold, but because nothing can fail. These serve realistic review records
#   over a real git history containing a commit that is genuinely not an
#   ancestor of HEAD, without which invariant 6 cannot be tested at all.
# ==============================================================================

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

DRY_RUN=0; ASSUME_YES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --help|-h) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

if [[ -n "$(git status --porcelain 2>/dev/null)" && $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 ]]; then
    _warn "Working tree is dirty."
    printf "Continue anyway? [y/N] "
    read -r reply
    [[ "$reply" == [yY]* ]] || { echo "Aborted."; exit 0; }
fi

write_file() {
    local rel="$1"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would write ${rel}${NC}"; cat > /dev/null; return 0; fi
    mkdir -p "${rel:h}"; cat > "$rel"
}
banner() { echo ""; echo "${BOLD}${BLUE}── $1${NC}" }

echo ""
echo "${BOLD}TOS Forward-Only Phase Gate — RED PHASE${NC}  ${DIM}(${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN${NC}"

# ==============================================================================
banner "tests/shared/zunit_helpers/phase_mocks.zsh"
T="tests/shared/zunit_helpers/phase_mocks.zsh"
if [[ -f "$T" ]]; then _skip "$T exists"; else
write_file "$T" <<'MOCKS_EOF'
#!/usr/bin/env zsh
# =============================================================================
# tests/shared/zunit_helpers/phase_mocks.zsh
# =============================================================================
# A realistic mock surface for the phase gate.
#
# WHY NOT REUSE mocks.zsh
#   The general mocks return exit 0 and a fixed string for every invocation.
#   Run the phase validator against them and it passes — not because the
#   invariants hold, but because nothing can fail.
#
# WHAT THIS PROVIDES
#   · a real git history in the sandbox, including an orphan commit that is
#     genuinely not an ancestor of HEAD (invariant 6 is untestable without it)
#   · a `gh` mock serving configurable review records as TSV
#
# USAGE
#   phase_mock_setup
#   phase_mock_review 101 APPROVED "$PHASE_C1" 2026-01-01T10:00:00Z pat "[PHASE:RED->GREEN] ok"
#   phase_mock_record 1 green "101:${PHASE_C1}:2026-01-01T10:00:00Z"
#   ...
#   phase_mock_teardown
# =============================================================================

phase_mock_setup() {
    local project="${1:-team_of_six}"
    export _PHASE_PROJECT="$project"
    export _SANDBOX_PROJECT="${TOS_SANDBOX}/${project}"
    mkdir -p "${_SANDBOX_PROJECT}"

    local g="git -C ${_SANDBOX_PROJECT}"
    ${=g} init -q 2>/dev/null || true
    ${=g} checkout -q -b main 2>/dev/null || true
    ${=g} config user.email "ghost@teamofsix.local"
    ${=g} config user.name "Team of Six (Ghost)"

    echo one > "${_SANDBOX_PROJECT}/a.txt"
    ${=g} add -A && ${=g} commit -qm "c1"
    export PHASE_C1=$(${=g} rev-parse HEAD)

    echo two > "${_SANDBOX_PROJECT}/b.txt"
    ${=g} add -A && ${=g} commit -qm "c2"
    export PHASE_C2=$(${=g} rev-parse HEAD)

    # An orphan commit. Not an ancestor of HEAD by construction — this is what
    # a force-pushed-away review commit looks like.
    ${=g} checkout -q --orphan stray
    ${=g} commit -q --allow-empty -m "stray"
    export PHASE_ORPHAN=$(${=g} rev-parse HEAD)
    ${=g} checkout -q main

    export PHASE_REVIEWS="/tmp/tos_phase_reviews_$$"
    : > "$PHASE_REVIEWS"

    export PHASE_GHOST_LOGIN="ghost-bot"

    export PHASE_MOCK_BIN="/tmp/tos_phase_bin_$$"
    mkdir -p "$PHASE_MOCK_BIN"

    cat > "$PHASE_MOCK_BIN/gh" <<'INNER'
#!/usr/bin/env zsh
case "$*" in
    *"repo view"*) echo "acme/${TOS_ACTIVE_PROJECT:-team_of_six}"; exit 0 ;;
    "api user"*)   echo "${PHASE_GHOST_LOGIN}"; exit 0 ;;
    *"/reviews"*)  cat "$PHASE_REVIEWS"; exit 0 ;;
    *"pr view"*)   echo "7"; exit 0 ;;
esac
exit 0
INNER
    chmod +x "$PHASE_MOCK_BIN/gh"
    export PATH="${PHASE_MOCK_BIN}:$PATH"
    rehash 2>/dev/null || true
}

# phase_mock_review <id> <state> <commit> <submitted_at> <login> <body>
phase_mock_review() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$PHASE_REVIEWS"
}

# phase_mock_record <trinity> <current> [red] [green] [refactor] [retrospect]
phase_mock_record() {
    local trinity="$1" current="$2"
    mkdir -p "${TOS_LOCKS}"
    {
        echo "current=${current}"
        echo "red=${3:-}"
        echo "green=${4:-}"
        echo "refactor=${5:-}"
        echo "retrospect=${6:-}"
    } > "${TOS_LOCKS}/${_PHASE_PROJECT}_trinity_${trinity}.phase"
}

phase_mock_current() {
    grep '^current=' "${TOS_LOCKS}/${_PHASE_PROJECT}_trinity_${1:-1}.phase" 2>/dev/null | cut -d= -f2
}

phase_mock_teardown() {
    rm -rf "$PHASE_MOCK_BIN" 2>/dev/null
    rm -f "$PHASE_REVIEWS" 2>/dev/null
}
MOCKS_EOF
_ok "Created $T"
fi

# ==============================================================================
banner "tests/unit/test_phase_gate.zunit"
T="tests/unit/test_phase_gate.zunit"
if [[ -f "$T" ]]; then _skip "$T exists"; else
write_file "$T" <<'PHASE_TESTS_EOF'
#!/usr/bin/env zunit
# =============================================================================
# tests/unit/test_phase_gate.zunit
# =============================================================================
# The phase gate is FORWARD-ONLY.
#
# A transition must advance exactly one step (red → green → refactor →
# retrospect) and carry an APPROVED verdict. Backward transitions and skips
# are refused. `--request-changes` is an ordinary review the Agent answers
# via `write code`; it does not move the phase.
#
# The exit from a wrong phase is `close trinity`, which restores the
# pre-Trinity state and returns the issue to the backlog. That is why
# backward transitions are unnecessary — and why allowing them would
# reintroduce the arbitrary-jump deadlocks the gate exists to prevent.
# =============================================================================

@setup {
    source "${PWD}/tests/shared/zunit_helpers/scaffold.zsh"
    source "${PWD}/tests/shared/zunit_helpers/assertions.zsh"
    source "${PWD}/tests/shared/zunit_helpers/phase_mocks.zsh"
    scaffold_setUp
    phase_mock_setup
    export TOS_ACTIVE_PROJECT="team_of_six"
    _V="${TOS_MNT_ROOT}/.local/bin/utils/phase_validate.zsh"
}

@teardown {
    phase_mock_teardown
    scaffold_tearDown
}

# A settled red→green transition, recorded and still present on the PR.
_seed_green() {
    phase_mock_review 101 APPROVED "$PHASE_C1" "2026-01-01T10:00:00Z" pat "[PHASE:RED->GREEN] contract agreed"
    phase_mock_record 1 green "101:${PHASE_C1}:2026-01-01T10:00:00Z"
}

# ---------------------------------------------------------------------------
# VERIFY
# ---------------------------------------------------------------------------
@test '[verify — positive] A consistent record validates and reports its phase' {
    _seed_green
    run zsh "$_V" verify team_of_six 1
    assert "$state" equals 0
    assert "$output" same_as "green"
}

@test '[verify — negative] A recorded review deleted from the PR refuses' {
    phase_mock_record 1 green "101:${PHASE_C1}:2026-01-01T10:00:00Z"
    run zsh "$_V" verify team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Validated a record whose review no longer exists"; fi
    assert "$output" contains "invariant 2"
}

@test '[verify — negative] No phase record at all refuses with recovery advice' {
    run zsh "$_V" verify team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Validated a nonexistent record"; fi
    assert "$output" contains "close trinity"
}

# ---------------------------------------------------------------------------
# FORWARD-ONLY
# ---------------------------------------------------------------------------
@test '[apply — positive] One step forward with APPROVED advances the phase' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->REFACTOR] implementation satisfies the contract"
    run zsh "$_V" apply team_of_six 1
    assert "$state" equals 0
    assert "$output" same_as "refactor"
    assert "$(phase_mock_current 1)" same_as "refactor"
}

@test '[apply — negative] A backward transition is refused outright' {
    _seed_green
    phase_mock_review 102 CHANGES_REQUESTED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->RED] start over"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Applied a backward transition — the gate is forward-only"; fi
    assert "$output" contains "forward"
    assert "$(phase_mock_current 1)" same_as "green"
}

@test '[apply — negative] Skipping a phase is refused' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->RETROSPECT] skip the refactor"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Applied a two-step jump"; fi
    assert "$(phase_mock_current 1)" same_as "green"
}

@test '[apply — negative] CHANGES_REQUESTED never moves the phase' {
    _seed_green
    phase_mock_review 102 CHANGES_REQUESTED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->REFACTOR] not yet"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "A CHANGES_REQUESTED review advanced the phase"; fi
    assert "$(phase_mock_current 1)" same_as "green"
}

@test '[apply — negative] Same-phase tag is not a transition' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->GREEN] nothing"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Applied a same-phase tag"; fi
}

# ---------------------------------------------------------------------------
# INVARIANTS
# ---------------------------------------------------------------------------
@test '[invariant 3] A tag whose source is not the current phase is stale' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:REFACTOR->RETROSPECT] x"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Applied a tag written against a superseded state"; fi
    assert "$output" contains "invariant 3"
}

@test '[invariant 6] A review whose commit was force-pushed away is refused' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_ORPHAN" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->REFACTOR] x"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Accepted an approval attesting to a commit not in the branch"; fi
    assert "$output" contains "invariant 6"
}

@test '[invariant 8] The Ghost cannot approve its own phase transition' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" ghost-bot "[PHASE:GREEN->REFACTOR] x"
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "The Ghost self-approved — it is a gatekeeper, not an authority"; fi
    assert "$output" contains "invariant 8"
}

@test '[latest wins] The most recent unconsumed review is the one applied' {
    _seed_green
    phase_mock_review 102 APPROVED "$PHASE_C2" "2026-01-02T10:00:00Z" pat "[PHASE:GREEN->REFACTOR] first"
    phase_mock_review 103 APPROVED "$PHASE_C2" "2026-01-03T10:00:00Z" pat "[PHASE:GREEN->REFACTOR] on reflection"
    run zsh "$_V" apply team_of_six 1
    assert "$state" equals 0
    assert "$(phase_mock_current 1)" same_as "refactor"
    if ! grep -q "green=103:" "${TOS_LOCKS}/team_of_six_trinity_1.phase"; then
        fail "Recorded the older review; latest must win"
    fi
}

@test '[no new tag] A consumed review is not offered again' {
    _seed_green
    run zsh "$_V" apply team_of_six 1
    if [[ "$state" -eq 0 ]]; then fail "Re-applied a review already consumed by a slot"; fi
    assert "$output" contains "No new transition tag"
}
PHASE_TESTS_EOF
_ok "Created $T"
fi

echo ""
echo "${BOLD}${BLUE}═════════════════════════ SUMMARY ═════════════════════════${NC}"
cat <<'FOOTER_EOF'

RUN THEM. THREE SHOULD FAIL.

    zunit tests/inf tests/unit

Expected red — the forward-only change:
    · [apply — negative] A backward transition is refused outright
    · [apply — negative] Skipping a phase is refused
    · [apply — negative] CHANGES_REQUESTED never moves the phase

The validator is still bidirectional, so all three currently succeed where
they must refuse.

Expected green — the other ten. If any is red, the phase gate is broken
independently of this work and that is worth knowing before going on.

A RED BAR HERE IS THE POINT. Do not fix the tests to match the code.

GREEN PHASE
    bin/utils/phase_validate.zsh — invariant 4 becomes "exactly one step
    ahead, verdict APPROVED". Backward handling is removed, not narrowed.

THEN THE ADR
    It currently documents backward transitions and describes close trinity
    as abandonment. Both are wrong and both need amending.

AFTER THAT, TOS BUILDS TOS
    close trinity and delete trinity are the first self-hosted work. Their
    tests are the Red phase of their own Trinities and are deliberately not
    written here.

    Worth knowing before you start: until close trinity is rewritten, there
    is no working escape from a Trinity that goes wrong. Recovery is manual —
    remove the lock, manifest and phase files, close the PR by hand.

FOOTER_EOF
exit 0
