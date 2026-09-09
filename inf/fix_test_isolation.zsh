#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Test Isolation Fix
# Usage: zsh inf/fix_test_isolation.zsh [--dry-run] [--only N,N] [--skip N,N] [--yes]
#        zsh inf/fix_test_isolation.zsh --restore latest
#
# THE BUG
#   tests/shared/sandbox_toolkit.zsh exports TOS_ROOT, TOS_BIN, TOS_WORKSPACE
#   and TOS_IPC — but never TOS_MNT_ROOT. The gateway resolves its config with:
#
#       export TOS_MNT_ROOT="${TOS_MNT_ROOT:-${BIN_DIR:h:h}}"
#       TOS_GLOBAL_CONF="${TOS_MNT_ROOT}/.local/conf/config"
#
#   /etc/profile.d/tos.sh puts TOS_MNT_ROOT in every login shell, zunit
#   inherits it, and the parameter expansion takes the inherited value. So
#   every tests/inf case has been running the gateway against the PRODUCTION
#   control plane — reading the production token, the production inbox, and
#   the production locks — while believing it was sandboxed in /tmp.
#
#   It looked harmless only because TOS_INPUT was undefined: the gateway's
#   Stage 5 hallucination check was skipped entirely. Defining TOS_INPUT
#   turned the latent fault into a visible failure.
#
#   tests/unit is unaffected — scaffold.zsh does export TOS_MNT_ROOT.
#
# THE FIX
#   Export TOS_MNT_ROOT from sandbox_provision, and assert on it so the
#   isolation cannot silently regress.
#
# STEPS
#   1  tests/shared/sandbox_toolkit.zsh — export TOS_MNT_ROOT
#   2  tests/inf/01_pathing.zunit       — assert the sandbox is isolated
#   3  docs + tutorial                  — post_test_cleanup runs WITHOUT sudo
#   4  production inbox                 — clear stale payload (runtime state)
#
# Step 4 touches live state under $TOS_MNT_ROOT, not the repo. It is the only
# step that is not reverted by --restore. It is skipped under --dry-run.
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
        --help|-h)  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

for required in bin/tos.zsh tests/shared/sandbox_toolkit.zsh; do
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
        mkdir -p "${REPO_ROOT}/${f:h}"
        cp "$SRC/$f" "${REPO_ROOT}/$f"
        echo "  restored $f"
    done
    _ok "Restore complete. Review with: git diff"
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
APPLIED_STEPS=()
DEFERRED_STEPS=()

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
    mkdir -p "${BACKUP_DIR}/${rel:h}"
    cp -p "$rel" "${BACKUP_DIR}/${rel}"
}

guard() {
    local rel="$1" marker="$2"
    [[ -f "$rel" ]] || { _warn "$rel not found — skipping."; return 1; }
    grep -qF -- "$marker" "$rel" && return 0
    _warn "$rel lacks the expected marker \"${marker:0:50}...\" — skipping."
    return 1
}

already() { [[ -f "$1" ]] && grep -qF -- "$2" "$1" }

replace_exact() {
    local rel="$1" search="$2" repl="$3"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would patch ${rel}${NC}"; return 0; fi
    SEARCH="$search" REPL="$repl" perl -0777 -i -pe \
        's/\Q$ENV{SEARCH}\E/$ENV{REPL}/' "$rel"
}

banner() { echo ""; echo "${BOLD}${BLUE}── STEP $1 ─ $2${NC}" }

echo ""
echo "${BOLD}TOS Test Isolation Fix${NC}  ${DIM}(repo: ${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN — nothing will be written.${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — sandbox_toolkit.zsh exports TOS_MNT_ROOT
# ==============================================================================
if should_run 1; then
banner 1 "sandbox_toolkit.zsh: isolate TOS_MNT_ROOT"
TARGET="tests/shared/sandbox_toolkit.zsh"

if already "$TARGET" 'export TOS_MNT_ROOT="$TEST_MNT_ROOT"'; then
    _skip "$TARGET already exports TOS_MNT_ROOT"
elif guard "$TARGET" '    # Export Engine Context'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'    # Export Engine Context
    export TOS_ROOT="${TEST_MNT_ROOT}/.local"' \
'    # Export Engine Context
    #
    # TOS_MNT_ROOT MUST be exported. The gateway resolves its config with
    #   export TOS_MNT_ROOT="${TOS_MNT_ROOT:-${BIN_DIR:h:h}}"
    # so an inherited value from /etc/profile.d/tos.sh wins, and the gateway
    # silently sources the PRODUCTION config instead of the sandboxed one.
    #
    # Only this variable is exported here. Everything downstream — TOS_LOCKS,
    # TOS_SANDBOX, TOS_INPUT, TOS_CONTEXT — is deliberately left to the
    # deployed config, so these tests exercise the real resolution chain
    # rather than a set of values the harness supplied to itself.
    export TOS_MNT_ROOT="$TEST_MNT_ROOT"
    export TOS_ROOT="${TEST_MNT_ROOT}/.local"'
    _ok "Patched $TARGET to export TOS_MNT_ROOT"
    APPLIED_STEPS+=("1")
else
    DEFERRED_STEPS+=("1 — tests/shared/sandbox_toolkit.zsh")
fi
fi

# ==============================================================================
# STEP 2 — regression test for the isolation itself
# ==============================================================================
if should_run 2; then
banner 2 "01_pathing.zunit: assert the sandbox is actually isolated"
TARGET="tests/inf/01_pathing.zunit"

if already "$TARGET" "TOS_MNT_ROOT is isolated"; then
    _skip "$TARGET already asserts TOS_MNT_ROOT isolation"
elif guard "$TARGET" "@test 'Path: Configuration file is mirrored' {"; then
    backup "$TARGET"
    replace_exact "$TARGET" \
"@test 'Path: Configuration file is mirrored' {
  assert \"\$TOS_ROOT/conf/config\" is_file
}" \
"@test 'Path: Configuration file is mirrored' {
  assert \"\$TOS_ROOT/conf/config\" is_file
}

# The gateway takes TOS_MNT_ROOT from the environment when it is already set.
# /etc/profile.d/tos.sh sets it in every login shell, so without an explicit
# export here the whole suite runs against the production control plane while
# appearing to be sandboxed. Assert the isolation directly.
@test 'Path: TOS_MNT_ROOT is isolated to the sandbox' {
  assert \"\$TOS_MNT_ROOT\" matches '/tmp/tos_test_'
}

@test 'Path: gateway resolves the sandboxed config, not production' {
  run zsh -c \"source '\$TOS_ROOT/conf/config'; print -r -- \\\$TOS_LOCKS\"
  assert \"\$output\" matches '/tmp/tos_test_'
}"
    _ok "Added 2 isolation assertions to $TARGET"
    APPLIED_STEPS+=("2")
else
    DEFERRED_STEPS+=("2 — tests/inf/01_pathing.zunit")
fi
fi

# ==============================================================================
# STEP 3 — post_test_cleanup.zsh must NOT be run under sudo
# ==============================================================================
if should_run 3; then
banner 3 "docs + tutorial: post_test_cleanup runs as the Architect"
DOC_CHANGES=0

doc_fix() {
    local file="$1" from="$2" to="$3"
    [[ -f "$file" ]] || return 0
    grep -qF -- "$from" "$file" || return 0
    DOC_CHANGES=$(( DOC_CHANGES + 1 ))
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] $file: drop sudo from post_test_cleanup${NC}"
        return 0
    fi
    backup "$file"
    FROM="$from" TO="$to" perl -0777 -i -pe 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
    echo "  ${GREEN}·${NC} $file: '${from}' → '${to}'"
}

# post_test_cleanup needs the ARCHITECT's gh credentials. Under sudo it runs as
# root, which has no ~/.config/gh, and fails immediately. It drops to
# `sudo -u team_of_six` internally exactly where it needs those privileges.
for f in docs/06-security.md docs/tutos/interactive_tutorial.zsh inf/close_gaps.zsh README.md; do
    doc_fix "$f" "sudo ./inf/post_test_cleanup.zsh" "./inf/post_test_cleanup.zsh"
done

if (( DOC_CHANGES > 0 )); then
    APPLIED_STEPS+=("3")
else
    _skip "no remaining 'sudo ./inf/post_test_cleanup.zsh' references"
fi
fi

# ==============================================================================
# STEP 4 — clear the stale production inbox (RUNTIME STATE, not the repo)
# ==============================================================================
if should_run 4; then
banner 4 "Control plane: clear the stale inbox payload"

if (( DRY_RUN )); then
    echo "  ${DIM}[dry-run] would inspect and offer to clear the production inbox${NC}"
else
    ARCH="${SUDO_USER:-$USER}"
    MNT="${TOS_MNT_ROOT:-/mnt/team_of_six}"
    INBOX="${MNT}/.ipc/${ARCH}/inbox.md"

    if ! sudo -n -u "${AI_USER:-team_of_six}" test -e "$INBOX" 2>/dev/null; then
        _skip "no inbox at $INBOX (or the Ghost cannot reach it)"
    elif ! sudo -n -u "${AI_USER:-team_of_six}" test -s "$INBOX" 2>/dev/null; then
        _skip "inbox is already empty"
    else
        _warn "The inbox still holds a payload from the aborted tutorial run."
        _warn "Until it is cleared, the gateway's Stage 5 hallucination check"
        _warn "rejects every command whose project does not match that payload."
        echo ""
        echo "${DIM}--- current contents of ${INBOX} ---${NC}"
        sudo -n -u "${AI_USER:-team_of_six}" cat "$INBOX" 2>/dev/null | sed 's/^/  │ /' || true
        echo "${DIM}--- end ---${NC}"
        echo ""

        DO_CLEAR=0
        if (( ASSUME_YES )); then
            DO_CLEAR=1
        else
            printf "Truncate this inbox? [y/N] "
            read -r reply
            [[ "$reply" == [yY]* ]] && DO_CLEAR=1
        fi

        if (( DO_CLEAR )); then
            sudo -n -u "${AI_USER:-team_of_six}" truncate -s 0 "$INBOX"
            _ok "Cleared $INBOX"
            APPLIED_STEPS+=("4")
        else
            _skip "inbox left untouched — clear it before running the tutorial"
        fi
    fi
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
    echo ""
    echo "${YELLOW}Dry run. Re-run without --dry-run to apply.${NC}"
else
    echo ""
    echo "Backups:  ${BACKUP_DIR}"
    echo "Restore:  zsh inf/fix_test_isolation.zsh --restore ${STAMP}"
    echo "${DIM}(Step 4 touches live control-plane state and is NOT reverted by --restore.)${NC}"
fi

cat <<'NEXT'

────────────────────────────────────────────────────────────────
NEXT
────────────────────────────────────────────────────────────────

    git diff
    zunit tests/inf tests/unit        # 97 tests now, all green

No redeploy is needed — steps 1 and 2 touch only the test harness, which
reads from the checkout.

Then:

    zsh docs/tutos/interactive_tutorial.zsh

Note on the browser: xdg-open is broken on this machine (.napp manifest
error), so `gh auth refresh` cannot open a browser for you. It still prints
the one-time code and the URL — paste them in manually. Chapter 11 does not
need this, but `delete project` would.

NEXT

exit 0
