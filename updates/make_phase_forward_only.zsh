#!/usr/bin/env zsh
# ==============================================================================
# Title: Phase Gate — Forward-Only (GREEN PHASE)
# Usage: zsh updates/make_phase_forward_only.zsh [--dry-run] [--yes]
#        zsh updates/make_phase_forward_only.zsh --restore latest
#
# Turns the two red tests green.
#
#   [apply — negative] A backward transition is refused outright
#   [apply — negative] Skipping a phase is refused
#
# Invariant 4 becomes: the target must be EXACTLY ONE STEP ahead of the
# source, and the verdict must be APPROVED. Backward handling is removed
# rather than narrowed — there is no retreat path left in the code to
# resurrect later.
#
# WHY FORWARD-ONLY
#   The exit from a wrong phase is `close trinity`, which restores the
#   pre-Trinity state and returns the issue to the backlog. With a real exit
#   available, retreats buy nothing and cost the arbitrary-jump deadlocks the
#   gate exists to prevent.
#
# ONE TEST TO WATCH
#   [apply — negative] CHANGES_REQUESTED never moves the phase already passes,
#   but for the wrong reason: under bidirectional logic GREEN->REFACTOR was
#   "forward", and forward demanded APPROVED. After this change it passes for
#   the right reason — every transition demands APPROVED. If it goes red, the
#   verdict check was lost along with the direction logic.
#
# STEPS
#   1  bin/utils/phase_validate.zsh  — invariant 4, forward-only
#   2  tests/unit/test_phase_gate.zunit — assert state in the same-phase test
#   3  governance/adr.md             — the row still documents retreats
# ==============================================================================

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

DRY_RUN=0; ASSUME_YES=0; RESTORE_STAMP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --restore) RESTORE_STAMP="$2"; shift 2 ;;
        --help|-h) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
[[ -f bin/utils/phase_validate.zsh ]] || {
    _err "bin/utils/phase_validate.zsh not found — run updates/add_phase_gate.zsh first."
    exit 1
}

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
echo "${BOLD}Phase Gate — Forward-Only (GREEN PHASE)${NC}  ${DIM}(${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — invariant 4 becomes forward-only
# ==============================================================================
banner 1 "phase_validate.zsh: one step forward, APPROVED"
T="bin/utils/phase_validate.zsh"
if already "$T" "forward-only, exactly one step"; then
    _skip "$T is already forward-only"
elif guard "$T" '# same-phase tags are rejected outright (invariant 4)'; then
    backup "$T"
    patch_it "$T" \
'# same-phase tags are rejected outright (invariant 4)
if (( SRC_IDX == TGT_IDX )); then
    _die "[invariant 4] ${SRC}->${TGT} is not a transition. Source and target are the same phase."
fi

# invariant 4 — verdict must agree with direction
if (( TGT_IDX > SRC_IDX )); then
    DIRECTION="forward"
    if [[ "$C_STATE" != "APPROVED" ]]; then
        _die "[invariant 4] verdict is ${C_STATE} but ${SRC}->${TGT} is an advance —
    use --approve, or correct the tag."
    fi
else
    DIRECTION="backward"
    if [[ "$C_STATE" != "CHANGES_REQUESTED" ]]; then
        _die "[invariant 4] verdict is ${C_STATE} but ${SRC}->${TGT} is a retreat —
    use --request-changes, or correct the tag."
    fi
fi' \
'# invariant 4 — forward-only, exactly one step, verdict APPROVED.
#
# The gate does not move backwards and does not skip. The exit from a wrong
# phase is `close trinity`, which restores the pre-Trinity state and returns
# the issue to the backlog. With a real exit available, retreats buy nothing
# and cost the arbitrary-jump deadlocks this gate exists to prevent.
if (( TGT_IDX != SRC_IDX + 1 )); then
    if (( TGT_IDX <= SRC_IDX )); then
        _die "[invariant 4] ${SRC}->${TGT} is not forward. The phase gate advances
    one step at a time and never retreats.
    To abandon this Trinity and return the issue to the backlog:
      tos ${PROJECT} close trinity"
    else
        _die "[invariant 4] ${SRC}->${TGT} skips a phase. The gate advances exactly
    one step: the only legal move from ${SRC} is ${PHASES[$(( SRC_IDX + 2 ))]}.
    A phase with nothing to do still needs its approval."
    fi
fi

# Every transition is an advance, so every transition requires an approval.
# A review requesting changes is answered with `write code`; it does not move
# the phase.
if [[ "$C_STATE" != "APPROVED" ]]; then
    _die "[invariant 4] verdict is ${C_STATE}, but advancing ${SRC}->${TGT} requires
    --approve. A review requesting changes leaves the phase where it is; the
    Agent answers it with write code."
fi'
    _ok "invariant 4 is now forward-only"
    APPLIED+=("1")
else
    DEFERRED+=("1 — bin/utils/phase_validate.zsh")
fi

# ==============================================================================
# STEP 2 — the same-phase test runs no assertion on the pass path
# ==============================================================================
banner 2 "test_phase_gate.zunit: assert state in the same-phase test"
T="tests/unit/test_phase_gate.zunit"
# NOTE: already() uses grep -F, which treats an embedded newline as two
# alternative patterns. Multi-line markers silently match the wrong thing —
# use a unique single line.
if already "$T" "zunit flags a test that runs no assertion"; then
    _skip "$T same-phase test already asserts"
elif guard "$T" 'if [[ "$state" -eq 0 ]]; then fail "Applied a same-phase tag"; fi'; then
    backup "$T"
    patch_it "$T" \
'    if [[ "$state" -eq 0 ]]; then fail "Applied a same-phase tag"; fi
}' \
'    if [[ "$state" -eq 0 ]]; then fail "Applied a same-phase tag"; fi
    # zunit flags a test that runs no assertion on its pass path as risky.
    assert "$(phase_mock_current 1)" same_as "green"
}'
    _ok "same-phase test now asserts the phase did not move"
    APPLIED+=("2")
else
    DEFERRED+=("2 — tests/unit/test_phase_gate.zunit")
fi

# ==============================================================================
# STEP 3 — the ADR row still documents retreats
# ==============================================================================
banner 3 "governance/adr.md: the row describes a bidirectional gate"
T="governance/adr.md"

if already "$T" "The gate is forward-only"; then
    _skip "$T already records forward-only"
elif guard "$T" '`[PHASE:GREEN->RED]` with `--request-changes`'; then
    backup "$T"
    patch_it "$T" \
'— `[PHASE:GREEN->REFACTOR]` with `--approve`, `[PHASE:GREEN->RED]` with `--request-changes` — and runs `tos <project> write phase`; where several tagged reviews have accumulated, the latest wins.' \
'— `[PHASE:GREEN->REFACTOR]` with `--approve` — and runs `tos <project> write phase`; where several tagged reviews have accumulated, the latest wins. The gate is forward-only: a transition advances exactly one step and never retreats or skips, because `close trinity` restores the pre-Trinity state and is the exit from a wrong phase.'
    patch_it "$T" \
'its verdict must agree with the direction of travel' \
'its verdict must be APPROVED'
    _ok "ADR row now describes the forward-only gate"
    APPLIED+=("3")
else
    DEFERRED+=("3 — governance/adr.md")
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
    echo "Restore:  zsh updates/make_phase_forward_only.zsh --restore ${STAMP}"
fi

cat <<'FOOTER_EOF'

────────────────────────────────────────────────────────────────
NEXT
────────────────────────────────────────────────────────────────

    zsh -n bin/utils/phase_validate.zsh
    sudo ./inf/tos_deploy.zsh
    zunit tests/inf tests/unit

EXPECT 112 GREEN, 0 WARNINGS.

Watch two in particular:

  · [apply — negative] CHANGES_REQUESTED never moves the phase
    It passed before for the wrong reason. It should still pass, now for the
    right one. If it went red, the verdict check was lost with the direction
    logic.

  · [apply — positive] One step forward with APPROVED advances the phase
    The only remaining legal move. If it went red, the off-by-one in
    SRC_IDX + 1 is wrong.

AFTER GREEN — THE LAST MIGRATION SCRIPT
────────────────────────────────────────────────────────────────
    The ADR still describes `close trinity` as abandonment. It is not: it
    currently squash-merges and closes the issue as completed. That is a
    second, unaudited merge path bypassing both the MANIFEST audit and this
    gate, and the forward-only design above depends on close doing what the
    ADR claims.

    That correction is the first self-hosted work: an issue, a Trinity, a
    visa, phase-gated reviews, a merge. Its tests are its own Red phase.

    Until then there is no working escape from a Trinity that goes wrong.
    Recovery is manual — remove the lock, manifest and phase files, close
    the PR by hand.

FOOTER_EOF
exit 0
