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

# invariant 4 — forward-only, exactly one step, verdict APPROVED.
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
