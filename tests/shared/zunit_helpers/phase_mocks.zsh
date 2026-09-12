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
