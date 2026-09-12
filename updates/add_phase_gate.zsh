#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Phase Gate — Engine Implementation
# Usage: zsh inf/add_phase_gate.zsh [--dry-run] [--only N,N] [--skip N,N] [--yes]
#        zsh inf/add_phase_gate.zsh --restore latest
#
# Implements governance/adr-phase-gate.md (ACCEPTED).
#
# SCOPE: engine only. Tests, documentation and the tutorial chapter are
# deliberately NOT included — they are written against this code once it has
# run at least once.
#
# STEPS
#   1  governance/adr.md                    — append the accepted ADR row
#   2  bin/utils/phase_validate.zsh         — the eight invariants (NEW)
#   3  bin/modules/write/hard/phase.zsh     — the command (NEW)
#   4  bin/modules/create/soft/trinity.zsh  — initialise the phase file
#   5  bin/modules/sync/soft/trinity.zsh    — validate + emit PHASE=
#   6  bin/modules/write/hard/trinity.zsh   — refuse unless retrospect
#   7  bin/utils/lock/release.zsh           — remove .phase alongside .manifest
#
# AFTER RUNNING: `sudo ./inf/tos_deploy.zsh` — this changes the engine.
# The existing suite will still pass (nothing it exercises reaches the new
# code paths) but that is NOT evidence the gate works. It has no tests yet.
# ==============================================================================

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

DRY_RUN=0
ASSUME_YES=0
RESTORE_STAMP=""
typeset -a ONLY_STEPS SKIP_STEPS
ONLY_STEPS=()
SKIP_STEPS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=1; shift ;;
        --yes|-y)   ASSUME_YES=1; shift ;;
        --only)     ONLY_STEPS=(${(s:,:)2}); shift 2 ;;
        --skip)     SKIP_STEPS=(${(s:,:)2}); shift 2 ;;
        --restore)  RESTORE_STAMP="$2"; shift 2 ;;
        --help|-h)  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown flag: $1 (try --help)" >&2; exit 1 ;;
    esac
done

NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;34m'

_info() { echo "${BLUE}▸${NC} $*" }
_ok()   { if (( DRY_RUN )); then echo "${DIM}   would: $*${NC}"; else echo "${GREEN}✔${NC} $*"; fi }
_warn() { echo "${YELLOW}⚠${NC} $*" >&2 }
_err()  { echo "${RED}✘${NC} $*" >&2 }
_skip() { echo "${DIM}·  skipped: $*${NC}" }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$REPO_ROOT" ]] || { _err "Not inside a git repository."; exit 1; }
cd "$REPO_ROOT"

for required in bin/tos.zsh governance/adr.md bin/utils/check_manifest_visa.zsh; do
    [[ -f "$required" ]] || { _err "Not the team_of_six repo (missing $required)."; exit 1; }
done

BACKUP_ROOT="${REPO_ROOT}/.gap_backup"

if [[ -n "$RESTORE_STAMP" ]]; then
    if [[ "$RESTORE_STAMP" == "latest" ]]; then
        RESTORE_STAMP="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -1)"
        [[ -n "$RESTORE_STAMP" ]] || { _err "No backups under $BACKUP_ROOT"; exit 1; }
        _info "Latest backup is ${RESTORE_STAMP}"
    fi
    SRC="${BACKUP_ROOT}/${RESTORE_STAMP}"
    [[ -d "$SRC" ]] || { _err "No backup at $SRC"; exit 1; }
    _info "Restoring from ${SRC}..."
    ( cd "$SRC" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
        mkdir -p "${REPO_ROOT}/${f:h}"; cp "$SRC/$f" "${REPO_ROOT}/$f"; echo "  restored $f"
    done
    _warn "Files CREATED by this script are not removed by --restore:"
    _warn "  bin/utils/phase_validate.zsh, bin/modules/write/hard/phase.zsh"
    _ok "Restore complete. Review with: git status"
    exit 0
fi

if [[ -n "$(git status --porcelain 2>/dev/null)" && $DRY_RUN -eq 0 ]]; then
    _warn "Working tree is dirty. Commit or stash so 'git diff' shows only this."
    if [[ $ASSUME_YES -eq 0 ]]; then
        printf "Continue anyway? [y/N] "
        read -r reply
        [[ "$reply" == [yY]* ]] || { echo "Aborted."; exit 0; }
    fi
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
typeset -a APPLIED_STEPS DEFERRED_STEPS
APPLIED_STEPS=(); DEFERRED_STEPS=()

should_run() {
    local n="$1"
    if (( ${#ONLY_STEPS} )); then [[ " ${ONLY_STEPS[*]} " == *" $n "* ]] || return 1; fi
    if (( ${#SKIP_STEPS} )); then [[ " ${SKIP_STEPS[*]} " == *" $n "* ]] && return 1; fi
    return 0
}
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
    _warn "$rel lacks the expected marker \"${marker:0:50}...\" — skipping."
    return 1
}
already() { [[ -f "$1" ]] && grep -qF -- "$2" "$1" }
write_file() {
    local rel="$1"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would write ${rel}${NC}"; cat > /dev/null; return 0; fi
    mkdir -p "${rel:h}"; cat > "$rel"; chmod +x "$rel"
}
replace_exact() {
    local rel="$1" search="$2" repl="$3"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would patch ${rel}${NC}"; return 0; fi
    SEARCH="$search" REPL="$repl" perl -0777 -i -pe 's/\Q$ENV{SEARCH}\E/$ENV{REPL}/' "$rel"
}
banner() { echo ""; echo "${BOLD}${BLUE}── STEP $1 ─ $2${NC}" }

echo ""
echo "${BOLD}TOS Phase Gate — Engine Implementation${NC}  ${DIM}(${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN — nothing will be written.${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — ADR row
# ==============================================================================
if should_run 1; then
banner 1 "governance/adr.md: append the accepted ADR row"
TARGET="governance/adr.md"
if already "$TARGET" "The Phase Gate"; then
    _skip "$TARGET already records The Phase Gate"
elif guard "$TARGET" "Pre-Escalation Caller Verification"; then
    backup "$TARGET"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would append the ADR row${NC}"
    else
        cat >> "$TARGET" <<'ADR_ROW'
| **The Phase Gate** | TOS makes explicit what the Agent may see, touch and do, but not where it stands in the Red-Green-Refactor-Retrospect cycle. The phase is not derivable from the repository: green and refactor are indistinguishable, since a refactor changes implementation without changing behaviour and leaves no artifact. An Agent asked to know its phase is therefore guessing over an unbounded set — the exact failure the framework exists to prevent. Separately, `write trinity` merges without consulting review state, leaving the one step that reaches `main` unguarded. | Store an explicit phase per Trinity in a Ghost-exclusive `.phase` file beside the lock, initialised to red by `create trinity`. The phase moves only when the Architect submits a review carrying a transition tag naming both endpoints — `[PHASE:GREEN->REFACTOR]` with `--approve`, `[PHASE:GREEN->RED]` with `--request-changes` — and runs `tos <project> write phase`; where several tagged reviews have accumulated, the latest wins. Every read re-derives the whole record from GitHub with no fast path: the review must resolve on the current PR, its source must equal the current phase, its verdict must agree with the direction of travel, it must be chronologically later than the last transition, its commit must be an ancestor of HEAD, and its author must not be the Ghost. GitHub is authoritative — on disagreement the command refuses and never silently repairs. `write trinity` refuses unless the phase is retrospect, checked before the MANIFEST audit; `sync trinity` reports `PHASE=` in the snapshot; `close trinity` is the sole command that does not validate, making abandonment the recovery path for a corrupted record. | The Agent is told its phase rather than selecting one, closing the last axis on which it was permitted to guess. Skipping the Retrospective becomes mechanically impossible and the Architect's approvals become load-bearing. Costs a fifth control-plane artifact, a new command, three forward reviews per Trinity, and an API call on every sync. A corrupted record costs the Trinity — deliberately: a record thrashed badly enough to lock it is evidence the Trinity was scoped too large, and the enforced restart reports something true about the work. Branch protection on `main` remains necessary independently — it is the only guarantee that survives a compromised gateway, and this gate is layered above it rather than replacing it. |
ADR_ROW
    fi
    _ok "Appended The Phase Gate to $TARGET"
    APPLIED_STEPS+=("1")
else
    DEFERRED_STEPS+=("1 — governance/adr.md")
fi
fi

# ==============================================================================
# STEP 2 — the validator
# ==============================================================================
if should_run 2; then
banner 2 "bin/utils/phase_validate.zsh: the eight invariants"
TARGET="bin/utils/phase_validate.zsh"
if [[ -f "$TARGET" ]]; then
    _skip "$TARGET already exists"
else
    write_file "$TARGET" <<'VALIDATOR_EOF'
#!/bin/zsh
# ==============================================================================
# Title: Phase Gate Validator
# Usage: phase_validate.zsh verify <project> <trinity_id>
#        phase_validate.zsh apply  <project> <trinity_id>
#
# Implements the eight invariants of ADR "The Phase Gate".
#
#   verify — re-validate every recorded transition against GitHub.
#            Prints the current phase to stdout. Exit 0 if the record holds.
#
#   apply  — verify, then find the latest review carrying a transition tag,
#            validate it, and apply it. Prints the NEW current phase.
#
# There is no fast path. Both modes validate in full (invariant 7): a cheap
# mode that is correct almost always is the same shape as the phase inference
# this gate exists to remove, and being cheap it would become the default.
#
# Callers: sync trinity (verify), write trinity (verify), write phase (apply).
# close trinity deliberately does NOT call this — see the ADR. It is the sole
# recovery path for a corrupted record.
# ==============================================================================

MODE="$1"
PROJECT="$2"
TRINITY_ID="$3"

if [[ -z "$MODE" || -z "$PROJECT" || -z "$TRINITY_ID" ]]; then
    echo "🚨 [PHASE] Usage: phase_validate.zsh <verify|apply> <project> <trinity_id>" >&2
    exit 1
fi

GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
PHASE_FILE="${GLOBAL_LOCKS}/${PROJECT}_trinity_${TRINITY_ID}.phase"
SANDBOX="${TOS_SANDBOX}/${PROJECT}"
BRANCH="tos-work-${TRINITY_ID}"

PHASES=(red green refactor retrospect)

# ---------------------------------------------------------------- helpers ---
_idx() {
    local p="$1" i=1
    for known in $PHASES; do
        [[ "$known" == "$p" ]] && { echo $(( i - 1 )); return 0; }
        (( i++ ))
    done
    echo "-1"
}

_field() {
    # _field <key> -> value from the phase file
    grep "^${1}=" "$PHASE_FILE" 2>/dev/null | head -1 | cut -d= -f2-
}

_die() { echo "🚨 [PHASE] $*" >&2; exit 1 }

# ------------------------------------------------------- preconditions ------
[[ -f "$PHASE_FILE" ]] || _die "No phase record for ${PROJECT} trinity ${TRINITY_ID}.
    Trinities created before the phase gate are not supported (ADR: no migration).
    Run: tos ${PROJECT} close trinity   then re-create the Trinity."

CURRENT="$(_field current)"
[[ -n "$CURRENT" ]] || _die "Phase record is malformed: no 'current' field."
[[ "$(_idx "$CURRENT")" != "-1" ]] || _die "Phase record names an unknown phase: '${CURRENT}'."

# ------------------------------------------------------- GitHub fetch -------
REPO_FULL=$(gh repo view "$PROJECT" --json nameWithOwner -q .nameWithOwner 2>/dev/null)
[[ -n "$REPO_FULL" ]] || _die "No GitHub repository named '${PROJECT}' is visible to the Ghost."

PR_NUM=$(gh pr view "$BRANCH" --repo "$REPO_FULL" --json number -q .number 2>/dev/null)
[[ -n "$PR_NUM" ]] || _die "No pull request open for ${BRANCH}.
    The phase record refers to reviews on a PR that no longer exists.
    Recovery: tos ${PROJECT} close trinity   (the sole command that does not validate)."

# One call supplies every field the invariants need.
REVIEWS_TSV=$(gh api "repos/${REPO_FULL}/pulls/${PR_NUM}/reviews" \
    --jq '.[] | [(.id|tostring), .state, (.commit_id // ""), .submitted_at, .user.login, (.body // "" | gsub("[\n\t]"; " "))] | @tsv' \
    2>/dev/null) || _die "Could not read reviews for PR #${PR_NUM}."

GHOST_LOGIN=$(gh api user -q .login 2>/dev/null)
[[ -n "$GHOST_LOGIN" ]] || _die "Could not resolve the Ghost's GitHub login."

# _review_field <review_id> <column>  (1=id 2=state 3=commit 4=when 5=login 6=body)
_review_field() {
    printf '%s\n' "$REVIEWS_TSV" | awk -F'\t' -v id="$1" -v col="$2" '$1 == id { print $col; exit }'
}

# --------------------------------------------- per-review invariant checks --
# _validate_review <review_id> <expected_commit> <expected_when> <label>
#   invariant 2 — still resolves on the current PR
#   invariant 6 — commit is an ancestor of HEAD
#   invariant 8 — author is not the Ghost
_validate_review() {
    local rid="$1" want_commit="$2" want_when="$3" label="$4"

    local got_state got_commit got_when got_login
    got_state=$(_review_field "$rid" 2)
    [[ -n "$got_state" ]] || _die "[invariant 2] The ${label} review (#${rid}) no longer exists on PR #${PR_NUM}.
    GitHub is authoritative and the record cannot be repaired silently.
    Recovery: tos ${PROJECT} close trinity"

    got_commit=$(_review_field "$rid" 3)
    if [[ -n "$want_commit" && "$got_commit" != "$want_commit" ]]; then
        _die "[invariant 2] The ${label} review (#${rid}) now reports commit ${got_commit}, recorded as ${want_commit}."
    fi

    got_when=$(_review_field "$rid" 4)
    if [[ -n "$want_when" && "$got_when" != "$want_when" ]]; then
        _die "[invariant 2] The ${label} review (#${rid}) now reports ${got_when}, recorded as ${want_when}."
    fi

    got_login=$(_review_field "$rid" 5)
    if [[ "$got_login" == "$GHOST_LOGIN" ]]; then
        _die "[invariant 8] The ${label} review was submitted by the Ghost (${GHOST_LOGIN}).
    The Ghost is a gatekeeper, not an authority. A phase cannot be self-approved."
    fi

    if [[ -n "$got_commit" ]]; then
        if ! git -C "$SANDBOX" merge-base --is-ancestor "$got_commit" HEAD 2>/dev/null; then
            _die "[invariant 6] The ${label} review approved commit ${got_commit}, which is no longer
    an ancestor of HEAD. The branch history was rewritten after the review, so
    the approval attests to code that is not there. Re-review the current state."
        fi
    fi
}

# ------------------------------------------- validate the stored record -----
# Invariants 2, 5, 6, 8 across every recorded slot. Invariants 3 and 4 are
# properties of a transition and are checked in apply mode. Invariant 7 is the
# absence of a fast path: this runs in full on every call.
LAST_WHEN=""
for p in $PHASES; do
    entry="$(_field "$p")"
    [[ -z "$entry" ]] && continue

    rid="${entry%%:*}"
    rest="${entry#*:}"
    commit="${rest%%:*}"
    when="${rest#*:}"

    _validate_review "$rid" "$commit" "$when" "$p"

    # invariant 5 — chronology across recorded transitions
    if [[ -n "$LAST_WHEN" && ! "$when" > "$LAST_WHEN" ]]; then
        _die "[invariant 5] Recorded transitions are not in chronological order:
    ${when} (${p}) is not later than ${LAST_WHEN}."
    fi
    LAST_WHEN="$when"
done

if [[ "$MODE" == "verify" ]]; then
    echo "$CURRENT"
    exit 0
fi

[[ "$MODE" == "apply" ]] || _die "Unknown mode '${MODE}'. Use verify or apply."

# ================================= APPLY ====================================
# Find the latest review carrying a transition tag. Latest wins (ADR): the
# Architect's most recent expressed intent supersedes earlier ones.
# Reviews already consumed by a recorded transition are excluded: a review
# keeps its tag forever, so without this the last applied review would remain
# the newest candidate and every repeat call would refuse with a confusing
# invariant-3 diagnostic instead of an honest "nothing new".
CONSUMED=""
for p in $PHASES; do
    e="$(_field "$p")"
    [[ -n "$e" ]] && CONSUMED="${CONSUMED} ${e%%:*}"
done

CANDIDATE=$(printf '%s\n' "$REVIEWS_TSV" \
    | awk -F'\t' -v used=" ${CONSUMED} " '
        $6 ~ /\[PHASE:[A-Za-z]+->[A-Za-z]+\]/ && index(used, " " $1 " ") == 0' \
    | sort -t$'\t' -k4,4 \
    | tail -1)

[[ -n "$CANDIDATE" ]] || _die "No new transition tag on PR #${PR_NUM}. The Trinity stays in '${CURRENT}'.
    Submit a review carrying a tag, for example:
      gh pr review ${BRANCH} --approve --body \"[PHASE:${CURRENT}-><next>] ...\""

C_ID=$(printf '%s' "$CANDIDATE" | cut -f1)
C_STATE=$(printf '%s' "$CANDIDATE" | cut -f2)
C_COMMIT=$(printf '%s' "$CANDIDATE" | cut -f3)
C_WHEN=$(printf '%s' "$CANDIDATE" | cut -f4)
C_BODY=$(printf '%s' "$CANDIDATE" | cut -f6)

if [[ "$C_BODY" =~ '\[PHASE:([A-Za-z]+)->([A-Za-z]+)\]' ]]; then
    SRC="${match[1]:l}"
    TGT="${match[2]:l}"
else
    _die "Could not parse a transition tag from review #${C_ID}."
fi

SRC_IDX=$(_idx "$SRC")
TGT_IDX=$(_idx "$TGT")
[[ "$SRC_IDX" != "-1" ]] || _die "Transition tag names an unknown source phase: '${SRC}'."
[[ "$TGT_IDX" != "-1" ]] || _die "Transition tag names an unknown target phase: '${TGT}'."

# invariant 3 — the tag's source must equal current
if [[ "$SRC" != "$CURRENT" ]]; then
    _die "[invariant 3] Review #${C_ID} declares ${SRC}->${TGT}, but the Trinity is in '${CURRENT}'.
    The review was written against a state that has since moved. Applying it
    would perform a transition you did not intend. Re-review from ${CURRENT}."
fi

# same-phase tags are rejected outright (invariant 4)
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
fi

# invariants 2, 6, 8 on the incoming review
_validate_review "$C_ID" "$C_COMMIT" "$C_WHEN" "incoming"

# invariant 5 — strictly later than the last recorded transition
if [[ -n "$LAST_WHEN" && ! "$C_WHEN" > "$LAST_WHEN" ]]; then
    _die "[invariant 5] Review #${C_ID} (${C_WHEN}) is not later than the last
    recorded transition (${LAST_WHEN})."
fi

# ------------------------------------------------------------- write --------
umask 077
TMP="${PHASE_FILE}.tmp.$$"
{
    echo "current=${TGT}"
    for p in $PHASES; do
        if [[ "$p" == "$SRC" ]]; then
            echo "${p}=${C_ID}:${C_COMMIT}:${C_WHEN}"
        else
            echo "${p}=$(_field "$p")"
        fi
    done
} > "$TMP"
mv "$TMP" "$PHASE_FILE"

echo "$TGT"
VALIDATOR_EOF
    _ok "Created $TARGET"
    APPLIED_STEPS+=("2")
fi
fi

# ==============================================================================
# STEP 3 — write phase
# ==============================================================================
if should_run 3; then
banner 3 "bin/modules/write/hard/phase.zsh: the command"
TARGET="bin/modules/write/hard/phase.zsh"
if [[ -f "$TARGET" ]]; then
    _skip "$TARGET already exists"
else
    write_file "$TARGET" <<'PHASE_EOF'
#!/bin/zsh
# ==============================================================================
# Title: Phase Transition
# Usage: tos <project> write phase
#
# Applies the latest transition tag the Architect has submitted on the
# Trinity's pull request. All validation lives in utils/phase_validate.zsh;
# this module is deliberately thin.
#
# hard/ placement means an active trinity is required — the gateway enforces
# that before dispatch.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="${1:-$TOS_ACTIVE_PROJECT}"

cd "$TOS_SANDBOX/$PROJECT_NAME" || {
    echo "🚨 [ERROR] No sandbox for '$PROJECT_NAME'." >&2
    exit 1
}

echo "🔍 Validating the phase record against GitHub..."

BEFORE=$("$TOS_BIN/utils/phase_validate.zsh" verify "$PROJECT_NAME" "$TOS_ACTIVE_TRINITY") || exit 1

AFTER=$("$TOS_BIN/utils/phase_validate.zsh" apply "$PROJECT_NAME" "$TOS_ACTIVE_TRINITY") || exit 1

echo "✅ Phase transition applied: ${BEFORE} → ${AFTER}"
echo ""
echo "TARGET_PROJECT=$PROJECT_NAME"
echo "TARGET_TRINITY=$TOS_ACTIVE_TRINITY"
echo "PHASE=$AFTER"

if [[ "$AFTER" == "retrospect" ]]; then
    echo ""
    echo "The Retrospective is the final phase. Once its learnings are committed,"
    echo "run: tos $PROJECT_NAME write trinity"
fi
PHASE_EOF
    _ok "Created $TARGET"
    APPLIED_STEPS+=("3")
fi
fi

# ==============================================================================
# STEP 4 — create trinity initialises the phase file
# ==============================================================================
if should_run 4; then
banner 4 "create trinity: initialise the phase record"
TARGET="bin/modules/create/soft/trinity.zsh"
if already "$TARGET" "PHASE GATE"; then
    _skip "$TARGET already initialises the phase record"
elif guard "$TARGET" 'if ! gh pr create --draft --title "Trinity #$TRINITY_ID"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'# 3. Open the Draft PR
if ! gh pr create --draft --title "Trinity #$TRINITY_ID" --body "Fixes #$TRINITY_ID" --base main --head "tos-work-$TRINITY_ID"; then
    echo "🚨 [ERROR] create trinity: Failed to create pull request." >&2
    exit 1
fi' \
'# 3. Open the Draft PR
if ! gh pr create --draft --title "Trinity #$TRINITY_ID" --body "Fixes #$TRINITY_ID" --base main --head "tos-work-$TRINITY_ID"; then
    echo "🚨 [ERROR] create trinity: Failed to create pull request." >&2
    exit 1
fi

# 4. PHASE GATE — initialise the phase record at red.
# Written only after the PR exists: the record refers to reviews on that PR,
# and a record without a PR is unvalidatable from birth.
GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
PHASE_FILE="${GLOBAL_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TRINITY_ID}.phase"
umask 077
{
    echo "current=red"
    echo "red="
    echo "green="
    echo "refactor="
    echo "retrospect="
} > "$PHASE_FILE"
echo "🔴 Phase record initialised at red."
echo "   Advance with a tagged review, then: tos $TOS_ACTIVE_PROJECT write phase"
echo "     gh pr review tos-work-$TRINITY_ID --approve --body \"[PHASE:RED->GREEN] ...\""'
    _ok "Patched $TARGET"
    APPLIED_STEPS+=("4")
else
    DEFERRED_STEPS+=("4 — create/soft/trinity.zsh")
fi
fi

# ==============================================================================
# STEP 5 — sync trinity validates and reports
# ==============================================================================
if should_run 5; then
banner 5 "sync trinity: validate, then report PHASE= in the snapshot"
TARGET="bin/modules/sync/soft/trinity.zsh"
if already "$TARGET" 'echo "PHASE='; then
    _skip "$TARGET already reports PHASE="
elif guard "$TARGET" 'echo "BRANCH=$TARGET_BRANCH"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'echo "BRANCH=$TARGET_BRANCH"
echo "GENERATED=$(date '"'"'+%Y-%m-%d %H:%M:%S'"'"')"' \
'echo "BRANCH=$TARGET_BRANCH"
echo "GENERATED=$(date '"'"'+%Y-%m-%d %H:%M:%S'"'"')"

# PHASE GATE — the snapshot must not carry an unvalidated phase. Every read
# validates in full (invariant 7); there is no fast path. A failure here halts
# the sync rather than emitting a phase the Agent would act on confidently.
if [[ "$NEW_TRINITY" != "0" ]]; then
    PHASE_NOW=$("$TOS_BIN/utils/phase_validate.zsh" verify "$PROJECT_NAME" "$NEW_TRINITY") || {
        echo "" >&2
        echo "🚨 FATAL: the phase record failed validation. No snapshot emitted." >&2
        echo "    The Agent must not receive a context whose phase cannot be trusted." >&2
        echo "    Recovery: tos $PROJECT_NAME close trinity" >&2
        exit 1
    }
    echo "PHASE=$PHASE_NOW"
fi'
    _ok "Patched $TARGET"
    APPLIED_STEPS+=("5")
else
    DEFERRED_STEPS+=("5 — sync/soft/trinity.zsh")
fi
fi

# ==============================================================================
# STEP 6 — write trinity refuses outside retrospect
# ==============================================================================
if should_run 6; then
banner 6 "write trinity: refuse unless the phase is retrospect"
TARGET="bin/modules/write/hard/trinity.zsh"
if already "$TARGET" "CHECK 0: PHASE"; then
    _skip "$TARGET already gates on the phase"
elif guard "$TARGET" "# === CHECK 1: INBOX MUST NOT BE EMPTY ==="; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'# === CHECK 1: INBOX MUST NOT BE EMPTY ===' \
'# === CHECK 0: PHASE MUST BE RETROSPECT ===
# Runs before everything else: it is the coarsest gate and gives the clearest
# diagnostic. Merging a feature whose Retrospective never happened is the
# failure this catches.
_PHASE_NOW=$("$TOS_BIN/utils/phase_validate.zsh" verify "$TOS_ACTIVE_PROJECT" "$TOS_ACTIVE_TRINITY") || exit 1
if [[ "$_PHASE_NOW" != "retrospect" ]]; then
    echo "🚨 [ERROR] write trinity: the Trinity is in '"'"'${_PHASE_NOW}'"'"', not '"'"'retrospect'"'"'." >&2
    echo "    A Trinity cannot be merged until its Retrospective has been completed" >&2
    echo "    and approved. Advance the phase with a tagged review, then:" >&2
    echo "      tos $TOS_ACTIVE_PROJECT write phase" >&2
    exit 1
fi

# === CHECK 1: INBOX MUST NOT BE EMPTY ==='
    _ok "Patched $TARGET"
    APPLIED_STEPS+=("6")
else
    DEFERRED_STEPS+=("6 — write/hard/trinity.zsh")
fi
fi

# ==============================================================================
# STEP 7 — release.zsh removes the phase file
# ==============================================================================
if should_run 7; then
banner 7 "release.zsh: remove .phase alongside .lock and .manifest"
TARGET="bin/utils/lock/release.zsh"
if already "$TARGET" '.phase"'; then
    _skip "$TARGET already removes the phase record"
elif guard "$TARGET" 'rm -f "$file" "${file%.lock}.manifest"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'rm -f "$file" "${file%.lock}.manifest"' \
'rm -f "$file" "${file%.lock}.manifest" "${file%.lock}.phase"'
    _ok "Patched $TARGET"
    APPLIED_STEPS+=("7")
else
    DEFERRED_STEPS+=("7 — bin/utils/lock/release.zsh")
fi
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "${BOLD}${BLUE}═════════════════════════ SUMMARY ═════════════════════════${NC}"
if (( ${#APPLIED_STEPS} )); then
    if (( DRY_RUN )); then echo "${DIM}   would apply: ${APPLIED_STEPS[*]}${NC}"
    else echo "${GREEN}✔${NC} Applied: ${APPLIED_STEPS[*]}"; fi
fi
if (( ${#DEFERRED_STEPS} )); then
    echo ""
    _warn "Deferred (precondition not met — inspect manually):"
    for s in "${DEFERRED_STEPS[@]}"; do echo "      $s"; done
fi
if (( DRY_RUN )); then
    echo ""; echo "${YELLOW}Dry run. Re-run without --dry-run to apply.${NC}"
else
    echo ""
    echo "Backups:  ${BACKUP_DIR}"
    echo "Restore:  zsh inf/add_phase_gate.zsh --restore ${STAMP}"
fi

cat <<'FOOTER_EOF'

────────────────────────────────────────────────────────────────
NEXT
────────────────────────────────────────────────────────────────

    git diff
    zsh -n bin/utils/phase_validate.zsh
    zsh -n bin/modules/write/hard/phase.zsh
    sudo ./inf/tos_deploy.zsh
    zunit tests/inf tests/unit        # still 99 — see the warning below

⚠️  THE EXISTING SUITE PROVES NOTHING ABOUT THIS CODE
────────────────────────────────────────────────────────────────
    99 green means no regression, not that the phase gate works. Nothing in
    the suite reaches phase_validate.zsh. The write-trinity tests will now
    exercise CHECK 0 — if they still pass, look closely: they may be passing
    because the mocked `gh` returns exit 0 for everything, which would make
    the validator succeed for the wrong reason.

    That is the next piece of work, and it is the larger half. Validating
    these invariants needs mocks that return realistic review JSON — several
    reviews with distinct states, timestamps, authors and commit SHAs — plus
    a real git history where a commit is genuinely NOT an ancestor of HEAD.
    That is a bigger mock surface than anything currently in tests/.

STILL TO COME
────────────────────────────────────────────────────────────────
  · tests/unit/test_phase_gate.zunit     — the eight invariants, paired
  · docs/03-trinity.md                   — the phase section
  · docs/05-workflow.md                  — phase placement in the lifecycle
  · docs/06-security.md                  — the fifth control-plane artifact
  · llm_agents/code.md § 3               — the Agent is TOLD its phase now
  · docs/tutos/interactive_tutorial.zsh  — positive and negative cases

UNVERIFIED ASSUMPTION
────────────────────────────────────────────────────────────────
    Whether the Ghost's token can approve a Trinity PR has not been tested.
    Invariant 8 checks it explicitly, so the gate holds either way — but if
    GitHub also refuses author self-approval, that is a second independent
    barrier worth knowing you have.

FOOTER_EOF

exit 0
