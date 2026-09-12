#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Config Gap Fix
# Usage: zsh inf/fix_config_gap.zsh [--dry-run] [--only N,N] [--skip N,N] [--yes]
#        zsh inf/fix_config_gap.zsh --restore latest
#
# Fixes the production bug that the tutorial surfaced, and closes the blind
# spot in the test suite that hid it.
#
# THE BUG
#   conf/config never defined TOS_INPUT or TOS_CONTEXT. The tutorial exported
#   them, but the gateway re-executes itself through `sudo -n -u team_of_six`,
#   and sudo's env_reset strips them. The gateway therefore reached
#   `tee "$TOS_CONTEXT"` with an empty string, pipefail caught tee's failure,
#   and the run died.
#
# WHY 91 TESTS MISSED IT
#   tests/shared/zunit_helpers/scaffold.zsh appends its own
#   `export TOS_CONTEXT=...` and `export TOS_INPUT=...` to the deployed config.
#   The harness supplied what production omitted, so every unit test passed
#   over the top of the defect. Any future config key production forgets would
#   be invisible in exactly the same way — that is the class this fixes, not
#   just the instance.
#
# STEPS
#   1  conf/config                          — define TOS_INPUT and TOS_CONTEXT
#   2  tests/inf/05_config_completeness.zunit — new regression test
#   3  inf/post_test_cleanup.zsh            — find test repos on GitHub, not cwd
#
# Step 3 is included because the rewritten tutorial works in a mktemp dir under
# /tmp, so the old cwd-glob cleanup can no longer find anything to delete.
# ==============================================================================

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

# ------------------------------------------------------------------ arguments
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
        --help|-h)  sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

for required in bin/tos.zsh conf/config inf/tos_deploy.zsh; do
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
    _warn "$rel lacks the expected marker \"${marker:0:50}...\" — skipping"
    _warn "rather than overwriting a file that has diverged."
    return 1
}

already() { [[ -f "$1" ]] && grep -qF -- "$2" "$1" }

write_file() {
    local rel="$1"
    if (( DRY_RUN )); then echo "  ${DIM}[dry-run] would write ${rel}${NC}"; cat > /dev/null; return 0; fi
    mkdir -p "${rel:h}"
    cat > "$rel"
}

banner() { echo ""; echo "${BOLD}${BLUE}── STEP $1 ─ $2${NC}" }

echo ""
echo "${BOLD}TOS Config Gap Fix${NC}  ${DIM}(repo: ${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN — nothing will be written.${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — conf/config defines TOS_INPUT and TOS_CONTEXT
# ==============================================================================
if should_run 1; then
banner 1 "conf/config: define the IPC ribbon paths"
TARGET="conf/config"

if already "$TARGET" "export TOS_INPUT="; then
    _skip "$TARGET already defines TOS_INPUT"
elif guard "$TARGET" "export TOS_MNT_ROOT="; then
    backup "$TARGET"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would append TOS_INPUT/TOS_CONTEXT to ${TARGET}${NC}"
    else
        # The literal /mnt/team_of_six prefix is REQUIRED, not a hardcode:
        # inf/tos_deploy.zsh seds that exact string to the deployment root,
        # which is how the test harness retargets the whole tree into /tmp.
        #
        # ${SUDO_USER} must stay UNEXPANDED in the file. The gateway sets it
        # in Stage 1 (Security Perimeter) before Stage 2 sources this config,
        # so it resolves per-architect at source time — which is what keeps
        # multi-tenant operation correct.
        cat >> "$TARGET" <<'CONF_EOF'

# --- IPC ribbon (per-architect) ----------------------------------------------
# Resolved at source time from SUDO_USER, which the gateway sets in Stage 1.
# Do NOT substitute ${TOS_MNT_ROOT} for the literal path below: tos_deploy.zsh
# rewrites the literal string during deployment.
export TOS_INPUT=/mnt/team_of_six/.ipc/${SUDO_USER}/inbox.md
export TOS_CONTEXT=/mnt/team_of_six/.ipc/${SUDO_USER}/outbox.md
CONF_EOF
    fi
    _ok "Appended TOS_INPUT and TOS_CONTEXT to $TARGET"
    APPLIED_STEPS+=("1")
else
    DEFERRED_STEPS+=("1 — conf/config")
fi
fi

# ==============================================================================
# STEP 2 — regression test for config completeness
# ==============================================================================
if should_run 2; then
banner 2 "tests/inf: config completeness regression test"
TARGET="tests/inf/05_config_completeness.zunit"

if [[ -f "$TARGET" ]]; then
    _skip "$TARGET already exists"
else
    write_file "$TARGET" <<'TEST_EOF'
#!/usr/bin/env zunit
# =============================================================================
# tests/inf/05_config_completeness.zunit
# =============================================================================
# WHAT IS TESTED
#   That the config produced by inf/tos_deploy.zsh defines every variable the
#   gateway and its modules dereference at runtime.
#
# WHY THIS FILE EXISTS
#   TOS_INPUT and TOS_CONTEXT were absent from conf/config for the entire life
#   of the project. The gateway reached `tee "$TOS_CONTEXT"` with an empty
#   string and every real invocation died. The unit suite did not catch it
#   because tests/shared/zunit_helpers/scaffold.zsh APPENDS its own
#   `export TOS_CONTEXT=...` to the deployed config — the harness supplied
#   what production omitted.
#
#   These tests deliberately use sandbox_toolkit.zsh, NOT scaffold.zsh, so the
#   config under assertion is exactly what tos_deploy.zsh produces with no
#   harness overrides layered on top. Moving them to scaffold.zsh would make
#   them validate the harness instead of the product.
# =============================================================================

@setup {
  source "${PWD}/tests/shared/sandbox_toolkit.zsh"
  sandbox_provision
  _DEPLOYED_CONF="${TOS_ROOT}/conf/config"
}

@teardown {
  sandbox_destroy
}

# ---------------------------------------------------------------------------
# TEST 1 — every required variable is declared
# ---------------------------------------------------------------------------
@test 'Deployed config declares every variable the engine dereferences' {
  local missing=""
  local required=(
    AI_USER AI_GROUP
    TOS_MNT_ROOT TOS_IPC TOS_LOCKS TOS_SANDBOX TOS_BIN
    TOS_INPUT TOS_CONTEXT
  )

  for var in $required; do
    grep -q "export ${var}=" "$_DEPLOYED_CONF" || missing="${missing} ${var}"
  done

  if [[ -n "$missing" ]]; then
    fail "conf/config does not declare:${missing}"
  fi
  assert 1 equals 1
}

# ---------------------------------------------------------------------------
# TEST 2 — sourcing it yields non-empty values, not just declarations
# ---------------------------------------------------------------------------
# A declaration that expands to an empty string is the failure mode that
# actually broke production: `tee ""` rather than `tee` with no argument.
@test 'Sourcing the deployed config yields non-empty IPC paths' {
  local probe
  probe=$(
    SUDO_USER="test_architect" zsh -c "
      source '${_DEPLOYED_CONF}'
      print -r -- \"\${TOS_INPUT:-EMPTY}|\${TOS_CONTEXT:-EMPTY}\"
    "
  )

  if [[ "$probe" == *EMPTY* ]]; then
    fail "TOS_INPUT/TOS_CONTEXT expand to empty after sourcing: ${probe}"
  fi
  assert 1 equals 1
}

# ---------------------------------------------------------------------------
# TEST 3 — the IPC paths follow SUDO_USER, not a baked-in name
# ---------------------------------------------------------------------------
# Multi-tenant operation depends on each Architect resolving to their own
# ribbon. A literal username here would silently cross-wire two architects.
@test 'IPC paths resolve per-architect from SUDO_USER' {
  local probe_a probe_b
  probe_a=$(SUDO_USER="architect_a" zsh -c "source '${_DEPLOYED_CONF}'; print -r -- \$TOS_INPUT")
  probe_b=$(SUDO_USER="architect_b" zsh -c "source '${_DEPLOYED_CONF}'; print -r -- \$TOS_INPUT")

  if [[ "$probe_a" == "$probe_b" ]]; then
    fail "TOS_INPUT is identical for two architects: ${probe_a}"
  fi

  [[ "$probe_a" == *architect_a* ]] || fail "TOS_INPUT does not contain architect_a: ${probe_a}"
  assert 1 equals 1
}

# ---------------------------------------------------------------------------
# TEST 4 — deployment rewrote the literal mount root
# ---------------------------------------------------------------------------
# tos_deploy.zsh seds the literal /mnt/team_of_six to the target root. If a
# new config line hardcodes the path in a form the sed misses, the test
# sandbox silently points at the production mount.
@test 'Deployed config contains no unrewritten production mount path' {
  if [[ "$TOS_MNT_ROOT" == "/mnt/team_of_six" ]]; then
    echo "SKIP: deployed to the production root; nothing to rewrite." >&2
    assert 1 equals 1
    return 0
  fi

  if grep -q "/mnt/team_of_six" "$_DEPLOYED_CONF"; then
    fail "Deployed config still references /mnt/team_of_six despite --mnt-root"
  fi
  assert 1 equals 1
}
TEST_EOF
    _ok "Created $TARGET (4 tests)"
    APPLIED_STEPS+=("2")
fi
fi

# ==============================================================================
# STEP 3 — post_test_cleanup.zsh finds repos on GitHub, not in cwd
# ==============================================================================
if should_run 3; then
banner 3 "post_test_cleanup.zsh: query GitHub instead of globbing cwd"
TARGET="inf/post_test_cleanup.zsh"

if already "$TARGET" "gh repo list"; then
    _skip "$TARGET already queries GitHub"
elif guard "$TARGET" 'for repo in tos-trinity-test-*; do'; then
    backup "$TARGET"
    write_file "$TARGET" <<'CLEANUP_EOF'
#!/bin/zsh
# ==============================================================================
# Team of Six — Test session cleaner
#
# The interactive tutorial works in a mktemp directory under /tmp, so globbing
# the current directory finds nothing. This queries GitHub for the authoritative
# list of test repositories instead, then removes each one's remote, Ghost
# sandbox, and control-plane locks.
# ==============================================================================

set -e

if ! gh auth status >/dev/null 2>&1; then
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

if ! gh auth status 2>&1 | grep -q "delete_repo"; then
    echo "⚠️  Scope 'delete_repo' required. Authorizing..."
    gh auth refresh -h github.com -s delete_repo
fi

GIT_USER=$(gh api user -q .login)
SANDBOX_ROOT="${TOS_MNT_ROOT}/sandbox/${SUDO_USER:-$USER}"
LOCKS_ROOT="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"

# Authoritative list from the remote, not from whatever happens to be in cwd.
REPOS=($(gh repo list "$GIT_USER" --limit 200 --json name -q \
    '.[].name | select(startswith("tos-trinity-test-") or startswith("tos-e2e-test-"))'))

if (( ${#REPOS[@]} == 0 )); then
    echo "✅ No test repositories found on GitHub. Nothing to clean."
else
    echo "Found ${#REPOS[@]} test repositor$( (( ${#REPOS[@]} == 1 )) && echo y || echo ies ):"
    for repo in $REPOS; do echo "   $GIT_USER/$repo"; done
    echo ""
    read -q "REPLY?Delete all of these? (y/n) " || true
    echo ""

    if [[ "$REPLY" == [yY] ]]; then
        for repo in $REPOS; do
            echo "──────────────────────────────────────────"
            echo "Deleting remote: $GIT_USER/$repo"

            if gh repo delete "$GIT_USER/$repo" --yes; then
                echo "✅ Remote deleted."

                SANDBOX_REPO="$SANDBOX_ROOT/$repo"
                if [[ -d "$SANDBOX_REPO" ]]; then
                    echo "🧹 Removing Ghost sandbox @ $SANDBOX_REPO"
                    sudo -u "${AI_USER:-team_of_six}" rm -rf "$SANDBOX_REPO"
                fi

                for lock in "$LOCKS_ROOT/${repo}_trinity_"*(N); do
                    echo "🔓 Removing stale lock: $(basename "$lock")"
                    sudo -u "${AI_USER:-team_of_six}" rm -f "$lock"
                done

                # Architect-side copy, if the tutorial was run from cwd.
                [[ -d "$repo" ]] && { echo "🧹 Removing local folder ./$repo"; rm -rf "$repo"; }
            else
                echo "❌ Failed to delete $repo. Leaving local state intact for safety."
            fi
        done
    else
        echo "Skipped remote deletion."
    fi
fi

echo ""
echo "Note: tutorial working directories live under /tmp/tos_tutorial_* and"
echo "      are reclaimed on reboot. Remove them now with:"
echo "      rm -rf /tmp/tos_tutorial_*"
echo ""

read -q "REPLY?Revoke the 'delete_repo' scope? (y/n) " || true
echo ""
if [[ "$REPLY" == [yY] ]]; then
    gh auth refresh -h github.com --remove-scopes delete_repo
    echo "✅ Permissions reset."
fi
CLEANUP_EOF
    (( DRY_RUN )) || chmod +x "$TARGET"
    _ok "Rewrote $TARGET to query GitHub and clear stale locks"
    APPLIED_STEPS+=("3")
else
    DEFERRED_STEPS+=("3 — inf/post_test_cleanup.zsh")
fi
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "${BOLD}${BLUE}══════════════════════════ SUMMARY ══════════════════════════${NC}"
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
    echo "Restore:  zsh inf/fix_config_gap.zsh --restore ${STAMP}"
fi

cat <<'NEXT'

────────────────────────────────────────────────────────────────
NEXT — the config change does nothing until it is redeployed
────────────────────────────────────────────────────────────────

    git diff                          # review
    sudo ./inf/tos_deploy.zsh         # REQUIRED — the gateway reads the
                                      # DEPLOYED config, not this checkout
    grep TOS_CONTEXT "$TOS_MNT_ROOT/.local/conf/config"

    zunit tests/inf tests/unit        # 95 tests now, not 91

    sudo ./inf/post_test_cleanup.zsh  # clears the orphan from the failed run
    rm -rf /tmp/tos_tutorial_*

    zsh docs/tutos/interactive_tutorial.zsh

Sanity check worth doing once, since it is the exact thing that broke:

    sudo -n -u team_of_six zsh -c \
      'source /mnt/team_of_six/.local/conf/config; echo "CONTEXT=[$TOS_CONTEXT]"'

An empty value between the brackets means the fix did not take.

NEXT

exit 0
