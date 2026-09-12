#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Ghost Isolation Fix
# Usage: zsh inf/fix_ghost_isolation.zsh [--dry-run] [--only N,N] [--skip N,N] [--yes]
#        zsh inf/fix_ghost_isolation.zsh --restore latest
#
# THE VIOLATION
#   bin/tos.zsh escalates to the Ghost in Stage 1, then runs caller-location
#   verification in Stage 3b:
#
#       exec sudo -n -u team_of_six "$REAL_PATH" "$@"      # Stage 1
#       ...
#       CURRENT_REMOTE=$(git remote get-url origin ...)    # Stage 3b
#
#   That `git remote get-url` executes as team_of_six, in the ARCHITECT's
#   working directory. It is the Ghost reading the Architect's working tree —
#   the exact thing the sandbox architecture exists to prevent (ADR: Isolated
#   Ghost Sandbox; docs/01-theSocialContract.md: "it cannot accidentally touch
#   your home directory, your personal SSH keys, or your active working tree").
#
#   It is also the wrong actor for the job: Stage 3b verifies where the CALLER
#   is standing, which is the caller's own business.
#
#   The failure is silent. `|| true` swallows the permission error, so a
#   directory the Ghost cannot traverse reports as "not a git repository" and
#   the Architect is told to run `create project` on a repo that already exists.
#
# THE FIX
#   Move the verification to Stage 0, before escalation, where it runs as the
#   Architect. Nothing downstream consumes CURRENT_REMOTE — it is a guard, not
#   a value — so the move is behaviour-preserving for every legitimate case.
#
# STEPS
#   1  bin/tos.zsh                      — verify caller location BEFORE escalating
#   2  bin/modules/sync/soft/project.zsh — same violation, second instance
#   3  docs/tutos/interactive_tutorial.zsh — undo the chmod workaround; preflight
#   4  governance/adr.md                — record the invariant
#   5  docs/06-security.md              — document it + the gh auth prerequisite
#   6  tests/unit/test_gateway_security.zunit — pin the ordering
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
        --help|-h)  sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

for required in bin/tos.zsh governance/adr.md; do
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
echo "${BOLD}TOS Ghost Isolation Fix${NC}  ${DIM}(repo: ${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN — nothing will be written.${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — gateway: verify caller location BEFORE escalating
# ==============================================================================
if should_run 1; then
banner 1 "Gateway: caller verification moves ahead of escalation"
TARGET="bin/tos.zsh"

if already "$TARGET" "STAGE 0: CALLER LOCATION VERIFICATION"; then
    _skip "$TARGET already verifies caller location pre-escalation"
elif guard "$TARGET" "# === STAGE 3b: CALLER LOCATION VERIFICATION ==="; then
    backup "$TARGET"

    # 1a — remove the post-escalation block
    replace_exact "$TARGET" \
'# === STAGE 3b: CALLER LOCATION VERIFICATION ===
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || true)
if [[ -n "$CURRENT_REMOTE" && "$CURRENT_REMOTE" != *"team_of_six"* ]]; then
    CURRENT_REPO=$(basename "$CURRENT_REMOTE" .git 2>/dev/null || true)
    if [[ -n "$CURRENT_REPO" && "$CURRENT_REPO" != "$PROJECT_NAME" ]]; then
        echo "🚨 [ERROR] Project mismatch: active is '"'"'$CURRENT_REPO'"'"' but called with '"'"'$PROJECT_NAME'"'"'." >&2
        exit 1
    fi
elif [[ -z "$CURRENT_REMOTE" ]]; then
    if [[ "$MODULE" != "create" || "$ACTION" != "project" ]]; then
        echo "🚨 [ERROR] Not in an initialized repository. Run '"'"'tos $PROJECT_NAME create project'"'"' first." >&2
        exit 1
    fi
    LOCAL_FOLDER=$(basename "$PWD")
    if [[ "$LOCAL_FOLDER" != "$PROJECT_NAME" ]]; then
        echo "🚨 [TYPO GUARD] Current folder name '"'"'$LOCAL_FOLDER'"'"' does not match requested project name '"'"'$PROJECT_NAME'"'"'." >&2
        exit 1
    fi
fi

' \
''

    # 1b — insert the pre-escalation block
    replace_exact "$TARGET" \
'# === STAGE 1: SECURITY PERIMETER ===' \
'# === STAGE 0: CALLER LOCATION VERIFICATION ===
# MUST run BEFORE the sudo escalation in Stage 1.
#
# This check inspects the ARCHITECT'"'"'s working directory. Performing it after
# escalation would mean the Ghost reads the Architect'"'"'s working tree, which
# the sandbox architecture exists to prevent, and which fails silently on any
# directory the Ghost cannot traverse (mode 0700 homes, mktemp -d, encrypted
# home mounts) — reporting "not a git repository" for a repo that plainly is.
#
# The guard below is skipped when already running as the Ghost, so the block
# is inert on the re-exec that Stage 1 performs.
if [[ "$(id -un)" != "${AI_USER:-team_of_six}" ]]; then
    _CALLER_PROJECT="${1:-}"; _CALLER_MODULE="${2:-}"; _CALLER_ACTION="${3:-}"

    if [[ -n "$_CALLER_PROJECT" ]]; then
        if _CALLER_REMOTE=$(git remote get-url origin 2>/dev/null); then
            if [[ "$_CALLER_REMOTE" != *"team_of_six"* ]]; then
                _CALLER_REPO=$(basename "$_CALLER_REMOTE" .git 2>/dev/null || true)
                if [[ -n "$_CALLER_REPO" && "$_CALLER_REPO" != "$_CALLER_PROJECT" ]]; then
                    echo "🚨 [ERROR] Project mismatch: active is '"'"'$_CALLER_REPO'"'"' but called with '"'"'$_CALLER_PROJECT'"'"'." >&2
                    exit 1
                fi
            fi
        else
            # No remote: only `create project` is legal here, and only in a
            # folder whose name matches the requested project.
            if [[ "$_CALLER_MODULE" != "create" || "$_CALLER_ACTION" != "project" ]]; then
                echo "🚨 [ERROR] Not in an initialized repository. Run '"'"'tos $_CALLER_PROJECT create project'"'"' first." >&2
                exit 1
            fi
            _CALLER_FOLDER=$(basename "$PWD")
            if [[ "$_CALLER_FOLDER" != "$_CALLER_PROJECT" ]]; then
                echo "🚨 [TYPO GUARD] Current folder name '"'"'$_CALLER_FOLDER'"'"' does not match requested project name '"'"'$_CALLER_PROJECT'"'"'." >&2
                exit 1
            fi
        fi
    fi
    unset _CALLER_PROJECT _CALLER_MODULE _CALLER_ACTION _CALLER_REMOTE _CALLER_REPO _CALLER_FOLDER
fi

# === STAGE 1: SECURITY PERIMETER ==='

    _ok "Moved caller verification to Stage 0 (pre-escalation) in $TARGET"
    APPLIED_STEPS+=("1")
else
    DEFERRED_STEPS+=("1 — bin/tos.zsh")
fi
fi

# ==============================================================================
# STEP 2 — sync project: second instance of the same violation
# ==============================================================================
if should_run 2; then
banner 2 "sync project: derive the remote from GitHub, not the Architect's cwd"
TARGET="bin/modules/sync/soft/project.zsh"

if already "$TARGET" "gh repo view"; then
    _skip "$TARGET already derives the remote from GitHub"
elif guard "$TARGET" 'REMOTE_URL=$(git remote get-url origin 2>/dev/null)'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'REMOTE_URL=$(git remote get-url origin 2>/dev/null)
[[ -z "$REMOTE_URL" ]] && { echo "⛔ ERROR: Run this from an initialized Architect repo."; exit 1; }' \
'# Derive the remote from GitHub, NOT from the Architect'"'"'s working directory.
# This module runs as the Ghost; reading the Architect'"'"'s tree here would
# breach sandbox isolation and fails outright on a non-traversable directory.
REPO_FULL=$(gh repo view "$PROJECT_NAME" --json nameWithOwner -q .nameWithOwner 2>/dev/null)
[[ -z "$REPO_FULL" ]] && { echo "⛔ ERROR: No GitHub repository named '"'"'$PROJECT_NAME'"'"' is visible to the Ghost."; exit 1; }
REMOTE_URL="https://github.com/${REPO_FULL}.git"'
    # The REPO_PATH derivation downstream is now redundant.
    replace_exact "$TARGET" \
'REPO_PATH=$(echo "$REMOTE_URL" | sed -e '"'"'s/.*github.com[:/]//'"'"' -e '"'"'s/\.git$//'"'"')
AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_PATH}.git"' \
'AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_FULL}.git"'
    _ok "Patched $TARGET to use gh repo view"
    APPLIED_STEPS+=("2")
else
    DEFERRED_STEPS+=("2 — bin/modules/sync/soft/project.zsh")
fi
fi

# ==============================================================================
# STEP 3 — tutorial: undo the chmod workaround, add the git-credential preflight
# ==============================================================================
if should_run 3; then
banner 3 "Tutorial: drop the chmod workaround, add preflight"
TARGET="docs/tutos/interactive_tutorial.zsh"
T_CHANGES=0

# 3a — remove the chmod 755 workaround if it was applied.
if [[ -f "$TARGET" ]] && grep -q 'chmod 755 "\$WORKDIR"' "$TARGET"; then
    backup "$TARGET"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would remove the chmod 755 \$WORKDIR workaround${NC}"
    else
        perl -0777 -i -pe 's/^.*The gateway escalates to the Ghost BEFORE.*\n(^#.*\n)*^chmod 755 "\$WORKDIR"\n//m' "$TARGET"
        perl -0777 -i -pe 's/^chmod 755 "\$WORKDIR"\n//m' "$TARGET"
    fi
    echo "  ${GREEN}·${NC} removed the chmod workaround (0700 is now correct and load-bearing)"
    T_CHANGES=$(( T_CHANGES + 1 ))
else
    _skip "3a: no chmod workaround present"
fi

# 3b — preflight: git must be able to authenticate to GitHub.
if [[ -f "$TARGET" ]] && ! grep -q "gh auth setup-git" "$TARGET"; then
    backup "$TARGET"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would add the git-credential preflight check${NC}"
    else
        replace_exact "$TARGET" \
'if ! gh auth status >/dev/null 2>&1; then
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi' \
'if ! gh auth status >/dev/null 2>&1; then
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

# gh being authenticated does NOT mean git is. gh keeps its token in
# ~/.config/gh/hosts.yml; plain git only sees it through a credential helper.
# Without this the Architect'"'"'s clone and pushes fall back to interactive
# password prompts, which GitHub has rejected since 2021.
if ! git config --get credential.'"'"'https://github.com'"'"'.helper >/dev/null 2>&1; then
    echo "⛔ git cannot authenticate to GitHub. Run: gh auth setup-git" >&2
    exit 1
fi'
    fi
    echo "  ${GREEN}·${NC} added the gh auth setup-git preflight check"
    T_CHANGES=$(( T_CHANGES + 1 ))
else
    _skip "3b: preflight already present"
fi

# 3c — clone via gh so it works regardless of helper configuration.
if [[ -f "$TARGET" ]] && grep -q 'git clone "https://github.com/\${GH_LOGIN}' "$TARGET"; then
    backup "$TARGET"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would switch the Architect clone to gh repo clone${NC}"
    else
        replace_exact "$TARGET" \
'git clone "https://github.com/${GH_LOGIN}/${TEST_REPO}.git" . -q' \
'gh repo clone "${GH_LOGIN}/${TEST_REPO}" . -- -q'
    fi
    echo "  ${GREEN}·${NC} Architect clone now uses gh repo clone"
    T_CHANGES=$(( T_CHANGES + 1 ))
else
    _skip "3c: clone already uses gh"
fi

if (( T_CHANGES > 0 )); then APPLIED_STEPS+=("3"); fi
fi

# ==============================================================================
# STEP 4 — record the invariant as an ADR
# ==============================================================================
if should_run 4; then
banner 4 "governance/adr.md: record the pre-escalation invariant"
TARGET="governance/adr.md"

if already "$TARGET" "Pre-Escalation Caller Verification"; then
    _skip "$TARGET already records this decision"
elif guard "$TARGET" "PAT MFA Isolation"; then
    backup "$TARGET"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would append the ADR row${NC}"
    else
        cat >> "$TARGET" <<'ADR_EOF'
| **Pre-Escalation Caller Verification** | The gateway escalated to the Ghost in Stage 1 and only then verified the Architect's working directory in Stage 3b. That check ran `git remote get-url origin` as `team_of_six`, inside the Architect's tree — the Ghost reading the Architect's filesystem, which the entire sandbox model exists to forbid. Because the failure was swallowed by `\|\| true`, any directory the Ghost could not traverse (a `0700` home, a `mktemp -d`, an encrypted home mount) reported as "not a git repository" and sent the Architect to `create project` for a repository that already existed. | All caller-location verification happens in **Stage 0, before the `sudo` escalation**, performed by the Architect against their own filesystem. **No module and no gateway stage running as the Ghost may read any path outside `${TOS_MNT_ROOT}`.** A guard on `id -un` makes the block inert on the re-exec. | Sandbox isolation is restored as a mechanical property rather than an aspiration: the Architect's working tree is unreadable to the Ghost, and a non-traversable project directory is now simply irrelevant instead of producing a misleading diagnostic. Any future check that needs to know where the Architect is standing must live in Stage 0. |
ADR_EOF
    fi
    _ok "Appended the ADR row to $TARGET"
    APPLIED_STEPS+=("4")
else
    DEFERRED_STEPS+=("4 — governance/adr.md")
fi
fi

# ==============================================================================
# STEP 5 — security doc: the invariant and the gh prerequisite
# ==============================================================================
if should_run 5; then
banner 5 "docs/06-security.md: invariant + gh auth setup-git"
TARGET="docs/06-security.md"

if already "$TARGET" "The Ghost Never Reads the Architect"; then
    _skip "$TARGET already documents the invariant"
elif guard "$TARGET" "## The Sudo Gateway"; then
    backup "$TARGET"
    replace_exact "$TARGET" \
'## The Sudo Gateway' \
'## The Ghost Never Reads the Architect'"'"'s Filesystem

This is the load-bearing invariant of the sandbox model, and it constrains
where checks may be placed, not merely what they do.

The gateway escalates to the Ghost in Stage 1. Every line after that point
executes as `team_of_six`. Any check that inspects the Architect'"'"'s working
directory must therefore run **before** Stage 1 — in Stage 0 — or it becomes
the Ghost reading the Architect'"'"'s tree.

Caller-location verification (project-name matching and the Typo Guard) lives
in Stage 0 for exactly this reason. It is the Architect'"'"'s own filesystem, so
the Architect is the correct actor to inspect it.

The practical consequence is that the Architect'"'"'s project directory needs no
particular permissions. A `0700` home, an encrypted home mount, or a
`mktemp -d` working directory are all fine — the Ghost never looks.

> **For contributors:** a module that calls `git`, `ls`, or `cat` on a path
> outside `${TOS_MNT_ROOT}` is a bug, however convenient. The value it wants
> is almost always available from `gh` or from the sandbox clone instead.

---

## Prerequisite: git must be able to authenticate

`gh auth login` authenticates the `gh` CLI. It does **not** authenticate
`git` — gh stores its token in `~/.config/gh/hosts.yml`, and plain `git`
only reaches it through a credential helper. Run:

```zsh
gh auth setup-git
```

Without this, the Architect'"'"'s own clones, pulls, and pushes fall back to
interactive password prompts, which GitHub has rejected since 2021. The
Ghost is unaffected — it builds an authenticated URL from the token in
`.token` — so the failure appears only on the Architect side and looks
unrelated to TOS.

---

## The Sudo Gateway'
    _ok "Documented the invariant and the gh prerequisite in $TARGET"
    APPLIED_STEPS+=("5")
else
    DEFERRED_STEPS+=("5 — docs/06-security.md")
fi
fi

# ==============================================================================
# STEP 6 — pin the ordering with a test
# ==============================================================================
if should_run 6; then
banner 6 "test_gateway_security.zunit: pin the Stage 0 ordering"
TARGET="tests/unit/test_gateway_security.zunit"

if already "$TARGET" "before the sudo escalation"; then
    _skip "$TARGET already pins the ordering"
elif guard "$TARGET" "@test 'Direct module invocation without TOS_CONTROLLER_LOCKED is inert' {"; then
    backup "$TARGET"
    replace_exact "$TARGET" \
"@test 'Direct module invocation without TOS_CONTROLLER_LOCKED is inert' {" \
"# The behavioural version of this test would need real privilege separation,
# which the harness deliberately mocks away. This is therefore a STRUCTURAL
# assertion: caller-location verification must appear before the sudo
# escalation in the gateway source. Crude, but it pins the one property that
# cannot be recovered once it regresses — see ADR: Pre-Escalation Caller
# Verification.
@test 'Caller verification appears before the sudo escalation' {
  local src=\"\${TOS_MNT_ROOT}/.local/bin/tos.zsh\"
  local line_check line_escalate

  line_check=\$(grep -n 'STAGE 0: CALLER LOCATION VERIFICATION' \"\$src\" | head -1 | cut -d: -f1)
  line_escalate=\$(grep -n 'exec sudo -n -u' \"\$src\" | head -1 | cut -d: -f1)

  if [[ -z \"\$line_check\" ]]; then
    fail 'No Stage 0 caller verification block found in the gateway'
  fi
  if [[ -z \"\$line_escalate\" ]]; then
    fail 'No sudo escalation found in the gateway'
  fi
  if (( line_check > line_escalate )); then
    fail \"Caller verification (line \$line_check) runs AFTER escalation (line \$line_escalate) — the Ghost would read the Architect's tree\"
  fi
  assert 1 equals 1
}

@test 'No gateway stage reads the Architect tree after escalation' {
  local src=\"\${TOS_MNT_ROOT}/.local/bin/tos.zsh\"
  local line_escalate
  line_escalate=\$(grep -n 'exec sudo -n -u' \"\$src\" | head -1 | cut -d: -f1)

  # Any bare 'git remote get-url' after the escalation line runs as the Ghost
  # in the Architect's cwd.
  local offender
  offender=\$(awk -v start=\"\$line_escalate\" 'NR > start && /git remote get-url/ { print NR\": \"\$0 }' \"\$src\")

  if [[ -n \"\$offender\" ]]; then
    fail \"Post-escalation read of the Architect tree: \$offender\"
  fi
  assert 1 equals 1
}

@test 'Direct module invocation without TOS_CONTROLLER_LOCKED is inert' {"
    _ok "Added 2 ordering assertions to $TARGET"
    APPLIED_STEPS+=("6")
else
    DEFERRED_STEPS+=("6 — tests/unit/test_gateway_security.zunit")
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
    echo "Restore:  zsh inf/fix_ghost_isolation.zsh --restore ${STAMP}"
fi

cat <<'FOOTER_EOF'

────────────────────────────────────────────────────────────────
NEXT — step 1 changes the gateway, so a redeploy IS required
────────────────────────────────────────────────────────────────

    git diff
    sudo ./inf/tos_deploy.zsh
    zunit tests/inf tests/unit        # 99 tests

    ./inf/post_test_cleanup.zsh
    rm -rf /tmp/tos_tutorial_*
    zsh docs/tutos/interactive_tutorial.zsh

Verify the isolation directly — this should now SUCCEED where it previously
reported "not an initialized repository":

    mkdir -p /tmp/iso_check && chmod 700 /tmp/iso_check
    cd /tmp/iso_check && mkdir -p demo && cd demo
    tos demo create project     # reaches the Typo Guard, not a false negative
    cd - && rm -rf /tmp/iso_check

STILL OPEN — not addressed here
────────────────────────────────────────────────────────────────

  · Stage 3b previously collapsed "no remote" and "cannot read this
    directory" into one message. Stage 0 no longer has the permission
    problem, but the two cases are still reported identically. Worth
    separating if you ever support repos the Architect cannot read either.

  · inf/grand_tutorial.zsh is untouched and still calls `write project`.

FOOTER_EOF

exit 0
