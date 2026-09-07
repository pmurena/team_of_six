#!/usr/bin/env zsh
# ==============================================================================
# Title: TOS Gap Closure Migration
# Usage: zsh inf/close_gaps.zsh [--dry-run] [--only N,N] [--skip N,N] [--yes]
#
# Closes the gaps between the documented TOS architecture and the shipped
# engine, and rewrites the interactive tutorial against the current command
# surface.
#
# DESIGN CONTRACT
#   - Idempotent. Every step detects whether it has already been applied.
#   - Precondition-guarded. Every step greps for a marker proving the file is
#     the version this script was written against. Mismatch = skip + warn,
#     never a blind overwrite.
#   - Backed up. Every touched file is copied to .gap_backup/<timestamp>/
#     preserving its relative path, before anything is written.
#   - Reversible. Run with --restore <timestamp> to put everything back.
#
# STEPS
#   1  sync/soft/trinity.zsh   — branch checkout + real Clean Room Snapshot
#   2  write/hard/code.zsh     — route manifest check through the shared util
#   3  write/hard/code.zsh     — fix literal \n in commit messages
#   4  write/hard/plan.zsh     — align lock path resolution
#   5  write/hard/trinity.zsh  — align lock path + fix post-merge sync handover
#   6  docs/tutos/interactive_tutorial.zsh — full rewrite
#   7  docs + README           — link rot and stale command names
#   8  update.zsh              — retire the unapplied pivot script
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
        --help|-h)
            sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unknown flag: $1 (try --help)" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------- colour
NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;34m'

_info()  { echo "${BLUE}▸${NC} $*" }
_ok()    { if (( DRY_RUN )); then echo "${DIM}   would: $*${NC}"; else echo "${GREEN}✔${NC} $*"; fi }
_warn()  { echo "${YELLOW}⚠${NC} $*" >&2 }
_err()   { echo "${RED}✘${NC} $*" >&2 }
_skip()  { echo "${DIM}·  skipped: $*${NC}" }

# ------------------------------------------------------------- repo detection
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    _err "Not inside a git repository. Run this from the team_of_six checkout."
    exit 1
fi
cd "$REPO_ROOT"

for required in bin/tos.zsh governance/adr.md bin/utils/parse_blocks.zsh; do
    if [[ ! -f "$required" ]]; then
        _err "This does not look like the team_of_six repo (missing $required)."
        exit 1
    fi
done

BACKUP_ROOT="${REPO_ROOT}/.gap_backup"

# ------------------------------------------------------------------- restore
if [[ -n "$RESTORE_STAMP" ]]; then
    if [[ "$RESTORE_STAMP" == "latest" ]]; then
        RESTORE_STAMP="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -1)"
        [[ -n "$RESTORE_STAMP" ]] || { _err "No backups found under $BACKUP_ROOT"; exit 1; }
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

# ------------------------------------------------------------- worktree check
if [[ -n "$(git status --porcelain 2>/dev/null)" && $DRY_RUN -eq 0 ]]; then
    _warn "Working tree is dirty. This script rewrites tracked files."
    _warn "Commit or stash first so 'git diff' shows only what this script did."
    if [[ $ASSUME_YES -eq 0 ]]; then
        printf "Continue anyway? [y/N] "
        read -r reply
        [[ "$reply" == [yY]* ]] || { echo "Aborted."; exit 0; }
    fi
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"

# --------------------------------------------------------------------- helpers
CHANGED=0
typeset -a APPLIED_STEPS DEFERRED_STEPS
APPLIED_STEPS=()
DEFERRED_STEPS=()

# should_run <step_number>
should_run() {
    local n="$1"
    if (( ${#ONLY_STEPS} )); then
        [[ " ${ONLY_STEPS[*]} " == *" $n "* ]] || return 1
    fi
    if (( ${#SKIP_STEPS} )); then
        [[ " ${SKIP_STEPS[*]} " == *" $n "* ]] && return 1
    fi
    return 0
}

# backup <relative_path>
backup() {
    local rel="$1"
    [[ -f "$rel" ]] || return 0
    (( DRY_RUN )) && return 0
    # Only ever capture the PRE-RUN state. Several steps touch the same file;
    # without this guard the second one would back up the first one's output.
    [[ -f "${BACKUP_DIR}/${rel}" ]] && return 0
    mkdir -p "${BACKUP_DIR}/${rel:h}"
    cp -p "$rel" "${BACKUP_DIR}/${rel}"
}

# guard <relative_path> <marker_string>
# Returns 0 if the file exists and contains the marker (safe to patch).
guard() {
    local rel="$1" marker="$2"
    if [[ ! -f "$rel" ]]; then
        _warn "$rel not found — skipping this step."
        return 1
    fi
    if ! grep -qF -- "$marker" "$rel"; then
        _warn "$rel does not contain the expected marker:"
        _warn "    \"${marker:0:60}...\""
        _warn "It may already be patched, or diverged from the version this"
        _warn "script targets. Skipping rather than overwriting."
        return 1
    fi
    return 0
}

# already <relative_path> <marker_string>  -> 0 if patch is already present
already() {
    [[ -f "$1" ]] && grep -qF -- "$2" "$1"
}

write_file() {
    local rel="$1"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would write ${rel}${NC}"
        cat > /dev/null
        return 0
    fi
    mkdir -p "${rel:h}"
    cat > "$rel"
    chmod +x "$rel"
    CHANGED=1
}

# replace_block <file> <perl_search> <perl_replace>
replace_exact() {
    local rel="$1" search="$2" repl="$3"
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would patch ${rel}${NC}"
        return 0
    fi
    SEARCH="$search" REPL="$repl" perl -0777 -i -pe \
        's/\Q$ENV{SEARCH}\E/$ENV{REPL}/' "$rel"
    CHANGED=1
}

banner() {
    echo ""
    echo "${BOLD}${BLUE}── STEP $1 ─ $2${NC}"
}

echo ""
echo "${BOLD}TOS Gap Closure${NC}  ${DIM}(repo: ${REPO_ROOT})${NC}"
(( DRY_RUN )) && echo "${YELLOW}DRY RUN — nothing will be written.${NC}"
(( DRY_RUN )) || echo "${DIM}Backups: ${BACKUP_DIR}${NC}"

# ==============================================================================
# STEP 1 — sync/soft/trinity.zsh: checkout + real Clean Room Snapshot
# ==============================================================================
if should_run 1; then
banner 1 "Atomic Handover + Clean Room Snapshot"
TARGET="bin/modules/sync/soft/trinity.zsh"

if already "$TARGET" "=== TOS CLEAN ROOM SNAPSHOT ==="; then
    _skip "$TARGET already generates a Clean Room Snapshot"
elif guard "$TARGET" "[TOS 1.0 PATCH] CLEAN ROOM SNAPSHOT"; then
    backup "$TARGET"
    write_file "$TARGET" <<'MODULE_EOF'
#!/bin/zsh
# ==============================================================================
# Title: Atomic Handover + Clean Room Snapshot
# Usage: tos <project> sync trinity <ID>
#
# Performs the Atomic Handover (03-trinity.md) and regenerates the Clean Room
# Snapshot in the Architect's outbox:
#
#   1. Push the outgoing branch (only when leaving a hard lock)
#   2. Release the old lock
#   3. Acquire the new lock
#   4. Fetch, check out the target branch, fast-forward from origin
#   5. Emit the snapshot to stdout (the gateway tees it to the outbox)
#
# The push in step 1 is the safety guarantee: the Ghost's work reaches the
# remote before any local state changes. Step 4 uses --ff-only — a divergence
# halts the sync rather than being silently resolved (ADR: Out-of-Band
# Recovery Doctrine).
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="${1:-$TOS_ACTIVE_PROJECT}"
NEW_TRINITY="$2"

if [[ -z "$NEW_TRINITY" ]]; then
    echo "🚨 [ERROR] sync trinity: Missing trinity ID." >&2
    echo "    Usage: tos $PROJECT_NAME sync trinity <ID>" >&2
    exit 1
fi

if [[ ! "$NEW_TRINITY" =~ ^[0-9]+$ ]]; then
    echo "🚨 [ERROR] sync trinity: Trinity ID must be numeric (got '$NEW_TRINITY')." >&2
    exit 1
fi

cd "$TOS_SANDBOX/$PROJECT_NAME" || {
    echo "🚨 [ERROR] No sandbox for '$PROJECT_NAME'." >&2
    echo "    Run: tos $PROJECT_NAME sync project" >&2
    exit 1
}

echo "🔄 Syncing Trinity..."

# --- 1. PRESERVE -------------------------------------------------------------
if [[ -n "$TOS_ACTIVE_TRINITY" && "$TOS_ACTIVE_TRINITY" -gt 0 ]]; then
    OUTGOING="tos-work-$TOS_ACTIVE_TRINITY"
    if git show-ref --verify --quiet "refs/heads/$OUTGOING"; then
        echo "⬆️  Preserving $OUTGOING on remote before handover..."
        git push origin "$OUTGOING" || {
            echo "🚨 FATAL: Push failed. Halting sync — no self-healing." >&2
            echo "    Resolve on the remote, then re-run this command." >&2
            exit 1
        }
    else
        echo "⏭️  $OUTGOING no longer exists locally. Nothing to preserve."
    fi
else
    echo "⏭️  Project Soft Lock detected (Trinity 0). Skipping push."
fi

# --- 2. HANDOVER -------------------------------------------------------------
"$TOS_BIN/utils/lock/release.zsh" "$PROJECT_NAME" >/dev/null 2>&1
"$TOS_BIN/utils/lock/acquire.zsh" "$PROJECT_NAME" "$NEW_TRINITY" "$SUDO_USER" >/dev/null 2>&1 || {
    echo "🚨 [ERROR] Failed to acquire lock for trinity $NEW_TRINITY." >&2
    exit 1
}

# --- 3. ALIGN ----------------------------------------------------------------
git fetch origin --prune -q || {
    echo "🚨 FATAL: git fetch failed. Halting sync." >&2
    exit 1
}

if [[ "$NEW_TRINITY" == "0" ]]; then
    TARGET_BRANCH="main"
else
    TARGET_BRANCH="tos-work-$NEW_TRINITY"
fi

if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    git checkout "$TARGET_BRANCH" -q
elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    git checkout -b "$TARGET_BRANCH" --track "origin/$TARGET_BRANCH" -q
else
    echo "🚨 [ERROR] Branch '$TARGET_BRANCH' exists neither locally nor on origin." >&2
    echo "    Run: tos $PROJECT_NAME create trinity $NEW_TRINITY" >&2
    exit 1
fi

# Absorb any Architect review commits. --ff-only: a divergence is the
# Architect's to resolve, not the Ghost's.
if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    git pull --ff-only origin "$TARGET_BRANCH" -q || {
        echo "🚨 FATAL: '$TARGET_BRANCH' has diverged from origin/$TARGET_BRANCH." >&2
        echo "    Resolve out-of-band, then re-run this command." >&2
        exit 1
    }
fi

echo "✅ Sync complete. Handed over to trinity $NEW_TRINITY on $TARGET_BRANCH."

# --- 4. CLEAN ROOM SNAPSHOT --------------------------------------------------
echo ""
echo "=== TOS CLEAN ROOM SNAPSHOT ==="
echo "TARGET_PROJECT=$PROJECT_NAME"
echo "TARGET_TRINITY=$NEW_TRINITY"
echo "BRANCH=$TARGET_BRANCH"
echo "GENERATED=$(date '+%Y-%m-%d %H:%M:%S')"

if [[ "$NEW_TRINITY" != "0" ]]; then
    echo ""
    echo "## ISSUE #$NEW_TRINITY"
    gh issue view "$NEW_TRINITY" --comments 2>/dev/null \
        || echo "_(no issue found for #$NEW_TRINITY)_"

    echo ""
    echo "## PULL REQUEST"
    if gh pr view "$TARGET_BRANCH" &>/dev/null; then
        gh pr view "$TARGET_BRANCH" --comments 2>/dev/null
    else
        echo "_(no pull request open for $TARGET_BRANCH)_"
    fi

    echo ""
    echo "## CHANGED FILES (vs origin/main)"
    git diff --name-only origin/main...HEAD 2>/dev/null || echo "_(none)_"

    echo ""
    echo "## DIFF vs origin/main"
    echo '```diff'
    git diff origin/main...HEAD 2>/dev/null
    echo '```'
else
    echo ""
    echo "## OPEN ISSUES"
    gh issue list 2>/dev/null || echo "_(unavailable)_"

    echo ""
    echo "## OPEN PULL REQUESTS"
    gh pr list 2>/dev/null || echo "_(none)_"
fi

echo ""
echo "## REPOSITORY SIGNATURE MAP"
if command -v ctags >/dev/null 2>&1; then
    ctags -R -x --_xformat="%-32N %-12K %5n  %F" . 2>/dev/null | head -n 250
else
    git ls-files
fi

echo ""
echo "## WORKING TREE"
git status -s

echo ""
echo "## RECENT COMMITS"
git log --oneline -10

echo ""
echo "=== END SNAPSHOT ==="
MODULE_EOF
    _ok "Rewrote $TARGET (checkout, ff-only pull, full snapshot)"
    APPLIED_STEPS+=("1")
else
    DEFERRED_STEPS+=("1 — sync/soft/trinity.zsh")
fi
fi

# ==============================================================================
# STEP 2 — write/hard/code.zsh: use the shared manifest visa checker
# ==============================================================================
if should_run 2; then
banner 2 "Manifest visa: substring match → word-exact shared util"
TARGET="bin/modules/write/hard/code.zsh"

if already "$TARGET" "check_manifest_visa.zsh"; then
    _skip "$TARGET already delegates to check_manifest_visa.zsh"
elif guard "$TARGET" 'if ! grep -qF "$FILE_PATH" "$MANIFEST_FILE" 2>/dev/null; then'; then
    backup "$TARGET"
    read -r -d '' OLD_BLOCK <<'OLD' || true
        # [SECURITY] Manifest Visa Verification (ADR 9)
        MANIFEST_FILE="$TOS_MNT_ROOT/.ipc/locks/${TOS_ACTIVE_PROJECT}_trinity_${ACTIVE_TRINITY}.manifest"
        if ! grep -qF "$FILE_PATH" "$MANIFEST_FILE" 2>/dev/null; then
            echo "🚨 SEC-FAULT: File '$FILE_PATH' is not authorized by the manifest visa."
            exit 1
        fi
OLD
    read -r -d '' NEW_BLOCK <<'NEW' || true
        # [SECURITY] Manifest Visa Verification (ADR 9)
        # Delegated to the shared util: word-exact matching, not substring.
        # A manifest listing "src/config.zsh" must NOT authorise "config.zsh".
        "$TOS_BIN/utils/check_manifest_visa.zsh" \
            "$FILE_PATH" "$TOS_ACTIVE_PROJECT" "$ACTIVE_TRINITY" || exit 1
NEW
    replace_exact "$TARGET" "$OLD_BLOCK" "$NEW_BLOCK"
    _ok "Patched $TARGET to call bin/utils/check_manifest_visa.zsh"
    APPLIED_STEPS+=("2")
else
    DEFERRED_STEPS+=("2 — write/hard/code.zsh manifest check")
fi
fi

# ==============================================================================
# STEP 3 — write/hard/code.zsh: literal \n in commit message
# ==============================================================================
if should_run 3; then
banner 3 "Commit message: literal backslash-n → real newlines"
TARGET="bin/modules/write/hard/code.zsh"

if already "$TARGET" 'COMMIT_MSG=$(printf'; then
    _skip "$TARGET already builds the commit message with printf"
elif guard "$TARGET" 'git commit -m "$TITLE\n\n$BODY\n\nFixes #$ACTIVE_TRINITY"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
        'git commit -m "$TITLE\n\n$BODY\n\nFixes #$ACTIVE_TRINITY"' \
        'COMMIT_MSG=$(printf '\''%s\n\n%s\n\nFixes #%s\n'\'' "$TITLE" "$BODY" "$ACTIVE_TRINITY")
git commit -m "$COMMIT_MSG"'
    _ok "Patched $TARGET commit message construction"
    APPLIED_STEPS+=("3")
else
    DEFERRED_STEPS+=("3 — write/hard/code.zsh commit message")
fi
fi

# ==============================================================================
# STEP 4 — write/hard/plan.zsh: lock path resolution
# ==============================================================================
if should_run 4; then
banner 4 "write plan: align lock path with the rest of the engine"
TARGET="bin/modules/write/hard/plan.zsh"

if already "$TARGET" 'GLOBAL_LOCKS="${TOS_LOCKS:-'; then
    _skip "$TARGET already resolves the lock directory consistently"
elif guard "$TARGET" 'echo "$MANIFEST" > "${TOS_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TOS_ACTIVE_TRINITY}.manifest"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
        '# Write the visa file to the control plane
echo "$MANIFEST" > "${TOS_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TOS_ACTIVE_TRINITY}.manifest"' \
        '# Write the visa file to the control plane.
# Resolution must match check_manifest_visa.zsh and the lock utilities.
GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"
mkdir -p "$GLOBAL_LOCKS"
echo "$MANIFEST" > "${GLOBAL_LOCKS}/${TOS_ACTIVE_PROJECT}_trinity_${TOS_ACTIVE_TRINITY}.manifest"'
    _ok "Patched $TARGET lock path resolution"
    APPLIED_STEPS+=("4")
else
    DEFERRED_STEPS+=("4 — write/hard/plan.zsh lock path")
fi
fi

# ==============================================================================
# STEP 5 — write/hard/trinity.zsh: lock path + post-merge handover
# ==============================================================================
if should_run 5; then
banner 5 "write trinity: lock path + post-merge sync handover"
TARGET="bin/modules/write/hard/trinity.zsh"

# 5a — lock path
if already "$TARGET" 'GLOBAL_LOCKS="${TOS_LOCKS:-'; then
    _skip "5a: $TARGET already resolves the lock directory consistently"
elif guard "$TARGET" 'GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
        'GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"' \
        'GLOBAL_LOCKS="${TOS_LOCKS:-${TOS_MNT_ROOT}/.ipc/locks}"'
    _ok "5a: patched $TARGET lock path resolution"
    APPLIED_STEPS+=("5a")
else
    DEFERRED_STEPS+=("5a — write/hard/trinity.zsh lock path")
fi

# 5b — the post-merge sync inherits TOS_ACTIVE_TRINITY=N and tries to push a
#      branch that write trinity just deleted. Force trinity 0 for that call.
if already "$TARGET" 'TOS_ACTIVE_TRINITY=0 "$TOS_BIN/modules/sync/soft/trinity.zsh"'; then
    _skip "5b: post-merge handover already forces trinity 0"
elif guard "$TARGET" '"$TOS_BIN/modules/sync/soft/trinity.zsh" "$TOS_ACTIVE_PROJECT" "0"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
        '"$TOS_BIN/modules/sync/soft/trinity.zsh" "$TOS_ACTIVE_PROJECT" "0"' \
        '# The hard lock is gone and tos-work-N has been deleted on both ends.
# Force TOS_ACTIVE_TRINITY=0 so the sync does not try to push a dead branch.
TOS_ACTIVE_TRINITY=0 "$TOS_BIN/modules/sync/soft/trinity.zsh" "$TOS_ACTIVE_PROJECT" "0"'
    _ok "5b: patched $TARGET post-merge handover"
    APPLIED_STEPS+=("5b")
else
    DEFERRED_STEPS+=("5b — write/hard/trinity.zsh post-merge handover")
fi

# 5c — literal \n in the verification comment
if already "$TARGET" 'COMMENT=$(printf'; then
    _skip "5c: $TARGET already builds its comment with printf"
elif guard "$TARGET" 'COMMENT="[VERIFIED] Trinity #$TOS_ACTIVE_TRINITY finalized at rev $REV_HASH. Audit Manifest match: OK.\nContext: $ISSUE_URL"'; then
    backup "$TARGET"
    replace_exact "$TARGET" \
        'COMMENT="[VERIFIED] Trinity #$TOS_ACTIVE_TRINITY finalized at rev $REV_HASH. Audit Manifest match: OK.\nContext: $ISSUE_URL"' \
        'COMMENT=$(printf '\''[VERIFIED] Trinity #%s finalized at rev %s. Audit Manifest match: OK.\nContext: %s\n'\'' "$TOS_ACTIVE_TRINITY" "$REV_HASH" "$ISSUE_URL")'
    _ok "5c: patched $TARGET verification comment"
    APPLIED_STEPS+=("5c")
else
    DEFERRED_STEPS+=("5c — write/hard/trinity.zsh comment newlines")
fi
fi

# ==============================================================================
# STEP 6 — interactive tutorial: full rewrite
# ==============================================================================
if should_run 6; then
banner 6 "Interactive tutorial: rewrite against the current command surface"
TARGET="docs/tutos/interactive_tutorial.zsh"

if already "$TARGET" "TOS_TUTORIAL_REVISION=2"; then
    _skip "$TARGET is already the rewritten revision"
else
    [[ -f "$TARGET" ]] && backup "$TARGET"
    write_file "$TARGET" <<'TUTORIAL_EOF'
#!/usr/bin/env zsh
# ==============================================================================
# Team of Six — The Contextual Trinity Interactive Tutorial
# TOS_TUTORIAL_REVISION=2
#
# Walks the full lifecycle against a real GitHub repository, using only
# commands the engine actually implements:
#
#   create project → write issue → sync trinity 0 → create trinity 1
#   → sync trinity 1 → write plan → write code (red) → write comment
#   → write code (green) → write plan (widen) → write code (refactor/retro)
#   → write trinity → close project
#
# REQUIREMENTS
#   - `gh` authenticated with repo + issue scope
#   - TOS deployed (inf/tos_deploy.zsh) and your user onboarded
#   - Write access to create repositories under the authenticated account
#
# The repository created here is named tos-trinity-test-<epoch> so that
# inf/post_test_cleanup.zsh can find and remove it afterwards.
# ==============================================================================

set -e
[[ -z "$ZSH_VERSION" ]] && exec zsh "$0" "$@"

# --- Configuration & Validation ----------------------------------------------
SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"

CONF="${REPO_ROOT}/conf/config"
if [[ ! -f "$CONF" ]]; then
    echo "⛔ Config not found at $CONF" >&2
    exit 1
fi
source "$CONF"

: "${TOS_MNT_ROOT:?TOS_MNT_ROOT is not set by conf/config}"

TEST_REPO="tos-trinity-test-$(date +%s)"
TOS_BIN_CMD="$TOS_MNT_ROOT/.local/bin/tos.zsh"

if [[ ! -x "$TOS_BIN_CMD" ]]; then
    echo "⛔ Gateway not found at $TOS_BIN_CMD. Run inf/tos_deploy.zsh first." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

# The tutorial runs as the Architect ($USER), so IPC paths map directly.
export TOS_IPC="$TOS_MNT_ROOT/.ipc/$USER"
export TOS_INPUT="$TOS_IPC/inbox.md"
export TOS_CONTEXT="$TOS_IPC/outbox.md"
export TOS_SANDBOX="$TOS_MNT_ROOT/sandbox/$USER"

WORKDIR="$(mktemp -d "/tmp/tos_tutorial_XXXXXX")"
GH_LOGIN="$(gh api user -q .login)"

# --- UI Engine ---------------------------------------------------------------
NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
CYAN=$'\033[1;36m'; YELLOW=$'\033[1;33m'; PURPLE=$'\033[1;35m'
BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; RED=$'\033[1;31m'

present_chapter() {
    clear
    echo "${BLUE}================================================================================${NC}"
    echo "$1"
    echo "${BLUE}================================================================================${NC}"
    echo ""
    printf "${YELLOW}🚀 Press [Enter] to initiate this turn, or [Ctrl+C] to abort... ${NC}"
    read -r
}

show_role() {
    local color=$1 role=$2 text=$3
    echo ""
    echo "${BOLD}${color}[$role]${NC} $text"
}

terminal_view() {
    echo "${DIM}┌─[ $1 ]───────────────────────────────────────────────────────${NC}"
    printf '%s\n' "$2" | sed 's/^/│ /'
    echo "${DIM}└──────────────────────────────────────────────────────────────${NC}"
}

end_turn() {
    printf "\n${YELLOW}🛑 Execution complete. Press [Enter] for the next chapter... ${NC}"
    read -r
}

write_inbox() { printf '%s\n' "$1" > "$TOS_INPUT"; }

tos() { "$TOS_BIN_CMD" "$TEST_REPO" "$@"; }

# --- Cleanup trap ------------------------------------------------------------
_cleanup() {
    local code=$?
    echo ""
    if (( code != 0 )); then
        echo "${RED}⚠️  Tutorial aborted (exit $code).${NC}"
        echo "    Workspace preserved for inspection: $WORKDIR"
    fi
    echo "${DIM}To remove the test repository and sandbox afterwards, run:${NC}"
    echo "${DIM}    sudo ./inf/post_test_cleanup.zsh${NC}"
}
trap _cleanup EXIT

# ==============================================================================
# INTRODUCTION
# ==============================================================================
present_chapter "$(cat <<'EOF'
# The Philosophy of the Contextual Trinity

LLMs fail in development because they operate in a vacuum — losing track of
file state, hallucinating structures, drifting from the actual repository.
TOS hard-codes a context window that cannot drift: the Contextual Trinity.

  1 Issue   (Required Context)  — the only source of truth for what is built
  1 PR      (Active Context)    — the only isolated space where code changes
  1 Feature (Cognitive Context) — the only logic the Agent processes

Enforced by a global project:trinity lock, a manifest visa that authorises
the Agent's blast radius up front, and payload-level hallucination checks
at the gateway.

This tutorial creates a REAL GitHub repository and destroys nothing you own.
EOF
)"

# ==============================================================================
# CHAPTER 0 — THE GENESIS
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 0: The Genesis (Establishing Remote Truth)

Goal:  Create the Remote Truth and provision the Ghost's sandbox.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> create project
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Preparing an empty project folder (the Typo Guard requires the folder name to match the project name)..."
mkdir -p "$WORKDIR/$TEST_REPO"
cd "$WORKDIR/$TEST_REPO"

write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TITLE=$TEST_REPO
BODY=A fast integer calculator in Zsh, built through the TOS tutorial.
===TOS_META_END==="

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO create project"
tos create project

show_role "$YELLOW" "ARCHITECT" "Cloning the Remote Truth into my own working copy..."
git clone "https://github.com/${GH_LOGIN}/${TEST_REPO}.git" . -q

show_role "$YELLOW" "ARCHITECT" "Adding a shared utility so the Agent has something to discover later..."
echo 'log() { echo "[LOG] $1"; }' > utils.zsh
git add utils.zsh
git commit -m "chore: add shared logging utility" -q
git push origin main -q

terminal_view "ls -la" "$(ls -la)"
show_role "$PURPLE" "GHOST" "Remote Truth established. Sandbox provisioned. Trinity 0 soft-lock held."
end_turn

# ==============================================================================
# CHAPTER 1 — THE AIR-GAP
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 1: The Air-Gap

Goal:  Inspect the control plane the Ghost operates through.
Role:  The Ghost (System Bridge)

The IPC ribbon is two files. The inbox is yours to write; the outbox is the
Ghost's to write. The lock lives in a directory you cannot edit.
EOF
)"

show_role "$PURPLE" "GHOST" "IPC ribbon state:"
terminal_view "ls -l \$TOS_IPC" "$(ls -l "$TOS_INPUT" "$TOS_CONTEXT")"

show_role "$PURPLE" "GHOST" "Active locks for this project:"
terminal_view "lock status" "$(ls -1 "$TOS_MNT_ROOT/.ipc/locks/" 2>/dev/null | grep "$TEST_REPO" || echo '(locks dir is Ghost-exclusive — mode 0700)')"
end_turn

# ==============================================================================
# CHAPTER 2 — SCOPING
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 2: Scoping (The Trinity Mandate)

Goal:  Break the feature set into atomic issues.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write issue

Issue creation is a soft-lock operation — appropriate in Trinity 0, the
Sanctuary, where brainstorming is allowed and code writing is not.
EOF
)"

show_role "$CYAN" "AGENT" "Proposing two atomic tickets."
PAYLOAD="===TOS_ISSUE_START===
TITLE=Implement add() function
BODY=Implement integer addition in calculator.zsh using native Zsh arithmetic. Must support negative numbers.
===TOS_ISSUE_END===
===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Deferred to a future trinity.
===TOS_ISSUE_END==="
write_inbox "$PAYLOAD"

show_role "$YELLOW" "ARCHITECT" "Reviewing the scoping payload before it executes..."
terminal_view "cat inbox.md" "$PAYLOAD"

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO write issue"
tos write issue

show_role "$YELLOW" "ARCHITECT" "Verifying Remote Truth..."
terminal_view "gh issue list" "$(gh issue list)"
end_turn

# ==============================================================================
# CHAPTER 3 — OPENING THE WORKSPACE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 3: Opening the Workspace

Goal:  Align the sandbox with main, create the Trinity, cross the Event Horizon.
Role:  The Ghost (System Bridge)
Cmds:  tos <project> sync trinity 0
       tos <project> create trinity 1
       tos <project> sync trinity 1

sync trinity 0 pulls the Architect's utils.zsh commit into the sandbox so
the new branch is cut from current main, not a stale one.
EOF
)"

show_role "$PURPLE" "GHOST" "Aligning the sandbox with main..."
tos sync trinity 0 >/dev/null

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO create trinity 1"
tos create trinity 1

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO sync trinity 1 (Atomic Handover + Clean Room Snapshot)"
tos sync trinity 1 >/dev/null

show_role "$CYAN" "AGENT" "My context is now a verified snapshot, not a memory."
terminal_view "head -n 20 outbox.md" "$(head -n 20 "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 4 — SURGICAL CONTEXT INJECTION
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 4: Surgical Context Injection (Peek)

Goal:  Feed the Agent's context window precisely, one file at a time.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> sync peek <file>

Peek APPENDS to the outbox. It does not reset the snapshot.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Executing: tos $TEST_REPO sync peek utils.zsh"
tos sync peek utils.zsh >/dev/null

show_role "$CYAN" "AGENT" "I can now see log(). I will use it rather than inventing my own."
terminal_view "tail -n 12 outbox.md" "$(tail -n 12 "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 5 — THE INTENT LOCK
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 5: The Intent Lock (write plan)

Goal:  Declare the exact blast radius BEFORE any code is written.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write plan

This writes a .manifest visa into the control plane. From here on, any
write code payload touching a file outside this list is rejected with a
SEC-FAULT before a single byte reaches the sandbox. The visa lives in a
directory you cannot edit from your own account — only write plan changes it.
EOF
)"

show_role "$CYAN" "AGENT" "Declaring intent: two files, no more."
PLAN="===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh
===TOS_PLAN_END==="
write_inbox "$PLAN"
terminal_view "cat inbox.md" "$PLAN"

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO write plan"
tos write plan
end_turn

# ==============================================================================
# CHAPTER 6 — THE RED PHASE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 6: The Red Phase

Goal:  Write a failing test before any implementation exists.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write code

The payload declares TARGET_PROJECT and TARGET_TRINITY. The gateway checks
both against the active lock before executing anything.
EOF
)"

show_role "$CYAN" "AGENT" "Writing the failing test."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Initial test suite using native Zsh arithmetic and the shared log() utility.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log \"Running tests...\"
[[ \"\$(add 5 5)\" == \"10\" ]] || exit 1
log \"PASS: add 5 5 = 10\"
===TOS_FILE_END==="

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO write code"
tos write code

show_role "$YELLOW" "ARCHITECT" "Fetching the Ghost's commit and verifying the diff..."
git fetch origin -q
terminal_view "git diff origin/main...origin/tos-work-1" "$(git diff origin/main...origin/tos-work-1 --stat)"
end_turn

# ==============================================================================
# CHAPTER 7 — ASYNC REVIEW & ROUTING
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 7: Review & Ghost Routing

Goal:  Architect intervenes with Wisdom; the Agent routes feedback by flag type.
Role:  Shared (Architect tags → Agent routes)

  [FIXME]     → fix now via write code
  [CHALLENGE] → defend or adjust the logic first
  [QUESTION]  → answer via write comment
  [TODO]      → defer via write issue
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Checking out the Ghost's branch and injecting review tags inline..."
git checkout tos-work-1 -q
git pull origin tos-work-1 -q

gh issue comment 1 -b "[QUESTION] Should we support negative numbers?" >/dev/null
sed -i 's|log "Running tests..."|log "Running tests..." # [CHALLENGE] Why native Zsh math instead of bc?|' test_calculator.zsh
git commit -am "review: architect tags injected inline" -q
git push origin tos-work-1 -q

show_role "$PURPLE" "GHOST" "Syncing the Architect's review back into the Agent's context..."
tos sync trinity 1 >/dev/null

show_role "$CYAN" "AGENT" "Tags detected. Routing: QUESTION and CHALLENGE both answer via write comment."
write_inbox "===TOS_COMMENT_START===
TARGET=1
BODY=**[ANSWER]**: Yes. Native Zsh arithmetic handles negative operands directly.
===TOS_COMMENT_END===
===TOS_COMMENT_START===
TARGET=tos-work-1
BODY=**[FEEDBACK on test_calculator.zsh]**: Native Zsh math avoids the subshell overhead of invoking an external binary like bc. Materially faster for unit tests.
===TOS_COMMENT_END==="
tos write comment

show_role "$CYAN" "AGENT" "Deferring the divide() idea to its own trinity rather than widening this one."
write_inbox "===TOS_ISSUE_START===
TITLE=Implement divide()
BODY=Deferred from the Trinity 1 review thread.
===TOS_ISSUE_END==="
tos write issue
end_turn

# ==============================================================================
# CHAPTER 8 — THE GREEN PHASE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 8: The Green Phase

Goal:  Minimum implementation to turn the test green. No premature abstraction.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write code

Note the manifest visa from Chapter 5 is still active. calculator.zsh is on
the approved list, so this passes. Anything else would not.
EOF
)"

show_role "$PURPLE" "GHOST" "Re-syncing so the sandbox carries the Architect's review commit..."
tos sync trinity 1 >/dev/null

show_role "$CYAN" "AGENT" "Implementing add()."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Green: implement add()
BODY=Implements add() to satisfy the failing test. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo \$(( \$1 + \$2 )); }
===TOS_FILE_END==="

tos write code
show_role "$YELLOW" "ARCHITECT" "Implementation committed. The diff matches the Wisdom."
end_turn

# ==============================================================================
# CHAPTER 9 — REFACTOR & RETROSPECTIVE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 9: Refactor & Retrospective

Goal:  Clean up, then encode the session's learnings into the repository.
Role:  Team of Six (Agent / Doer)
Cmds:  tos <project> write plan   (widen the visa — documentation is new scope)
       tos <project> write code

The Retrospective is mandatory. Domain rules the Agent had to infer get
written into the project's docs so the next Trinity starts better calibrated.
Widening scope requires a NEW write plan — the visa is not negotiable.
EOF
)"

show_role "$CYAN" "AGENT" "Documentation is outside my current visa. Re-declaring intent."
write_inbox "===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh README.md docs/learnings.md
===TOS_PLAN_END==="
tos write plan

show_role "$CYAN" "AGENT" "Refactoring and writing the retrospective."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Refactor: document add() and record session learnings
BODY=Adds docstrings, documents usage in README, and encodes two domain rules discovered during this trinity.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
# Adds two integers using native Zsh arithmetic. Negative operands supported.
add() { echo \$(( \$1 + \$2 )); }
===TOS_FILE_END===
===TOS_FILE_START: README.md===
# ${TEST_REPO}

## Calculator Module

\`add(a, b)\` returns the sum of two integers, including negative operands.
Implemented with native Zsh arithmetic rather than an external binary.
===TOS_FILE_END===
===TOS_FILE_START: docs/learnings.md===
# Domain Rules

1. Use native Zsh arithmetic. Do not shell out to \`bc\`.
2. Validate operand count before evaluating any arithmetic block.
===TOS_FILE_END==="

tos write code

show_role "$YELLOW" "ARCHITECT" "Reviewing the Ghost Journal in the outbox..."
terminal_view "tail -n 30 outbox.md" "$(tail -n 30 "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 10 — TRINITY CLOSURE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 10: The Closure

Goal:  Prove the Agent knows exactly what it did, then merge.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> write trinity

The MANIFEST must match `git diff --name-only origin/main...HEAD` exactly.
The Agent is FORBIDDEN from guessing it from memory — the Architect supplies
the verified list. A mismatch aborts the merge as a context hallucination.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Pulling the Ghost's work and running the tests locally..."
git fetch origin -q
git pull --ff-only origin tos-work-1 -q
if zsh ./test_calculator.zsh; then
    echo "${GREEN}✅ Local tests passed.${NC}"
else
    echo "${RED}❌ Local tests failed — halting before merge.${NC}"
    exit 1
fi

show_role "$YELLOW" "ARCHITECT" "Formally reviewing the Pull Request..."
gh pr review tos-work-1 --comment -b "Tests pass locally. Documentation updated. Approved for merge." >/dev/null

show_role "$YELLOW" "ARCHITECT" "Computing the verified MANIFEST — never from the Agent's memory."
MANIFEST_FILES="$(git diff --name-only origin/main...HEAD | tr '\n' ' ' | sed 's/ *$//')"
terminal_view "git diff --name-only origin/main...HEAD" "$MANIFEST_FILES"

show_role "$PURPLE" "GHOST" "Re-syncing the sandbox so its diff matches the Architect's..."
tos sync trinity 1 >/dev/null

show_role "$CYAN" "AGENT" "Declaring the closure MANIFEST."
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=$MANIFEST_FILES
===TOS_TRINITY_END==="

show_role "$PURPLE" "GHOST" "Executing: tos $TEST_REPO write trinity"
if ! tos write trinity; then
    echo ""
    echo "${RED}🚨 Tutorial halted: write trinity aborted.${NC}"
    echo "    The workspace is preserved at $WORKDIR for inspection."
    exit 1
fi

show_role "$YELLOW" "ARCHITECT" "Cleaning up my local branch..."
git checkout main -q
git pull origin main -q
git branch -D tos-work-1 -q 2>/dev/null || true

terminal_view "gh issue view 1" "$(gh issue view 1 | grep -i state || true)"
end_turn

# ==============================================================================
# CHAPTER 11 — TEARDOWN
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 11: Teardown (close project)

Goal:  Remove the Ghost's sandbox. The remote survives untouched.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> close project

Every close and delete operation requires the literal string CONFIRM=TRUE in
the META block. The gateway aborts before evaluating any other logic if it is
absent. This is the HITL Destructive Gate.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Issuing the destructive gate."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=0
TITLE=Close project
BODY=Tutorial complete. Removing the local sandbox.
CONFIRM=TRUE
===TOS_META_END==="

tos close project

echo ""
echo "${GREEN}${BOLD}🏁 Tutorial complete.${NC}"
echo ""
echo "The remote repository still exists: ${BOLD}https://github.com/${GH_LOGIN}/${TEST_REPO}${NC}"
echo "Your local working copy: ${BOLD}${WORKDIR}/${TEST_REPO}${NC}"
echo ""
echo "To purge both, run: ${BOLD}sudo ./inf/post_test_cleanup.zsh${NC}"
echo ""
TUTORIAL_EOF
    _ok "Rewrote $TARGET (12 chapters, current command surface, dynamic MANIFEST)"
    APPLIED_STEPS+=("6")
fi
fi

# ==============================================================================
# STEP 7 — documentation: link rot and stale command names
# ==============================================================================
if should_run 7; then
banner 7 "Documentation: broken links and stale command names"

doc_fix() {
    local file="$1" from="$2" to="$3"
    [[ -f "$file" ]] || return 0
    grep -qF -- "$from" "$file" || return 0
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] $file: '${from}' → '${to}'${NC}"
        return 0
    fi
    backup "$file"
    FROM="$from" TO="$to" perl -0777 -i -pe 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
    echo "  ${GREEN}·${NC} $file: '${from}' → '${to}'"
    CHANGED=1
    DOC_CHANGES=$(( DOC_CHANGES + 1 ))
}
DOC_CHANGES=0

# Link rot: 00-llm-pitfalls.md is referenced as 01-llm-pitfalls.md throughout
for f in docs/*.md README.md; do
    doc_fix "$f" "01-llm-pitfalls.md" "00-llm-pitfalls.md"
done

# 00's footer points to 02 instead of 01
doc_fix "docs/00-llm-pitfalls.md" \
    "← [README.md](../README.md) | Next: [02-architecture.md](02-architecture.md)" \
    "← [README.md](../README.md) | Next: [01-theSocialContract.md](01-theSocialContract.md)"

# Tutorial path moved to docs/tutos/
for f in README.md docs/*.md; do
    doc_fix "$f" "test/interactive_tutorial.zsh" "docs/tutos/interactive_tutorial.zsh"
done

# sync start was renamed to sync project
for f in docs/*.md; do
    doc_fix "$f" "sync start" "sync project"
done

# write tasks was renamed to write issue
for f in docs/*.md; do
    doc_fix "$f" "write tasks" "write issue"
done

# 03-trinity.md still documents a `remove` command that does not exist
doc_fix "docs/03-trinity.md" \
    "Locks are released explicitly by \`tos <project> remove <N>\`" \
    "Locks are released explicitly by \`tos <project> write trinity\`"

# The Neovim keymap table mislabels 6wt
doc_fix "docs/07-neovim-plugin.md" \
    "| \`<leader>6wt\` | Write Tasks | Smart-yanks \`TOS_ISSUE\` blocks and runs \`tos <pro" \
    "| \`<leader>6wi\` | Write Issue | Smart-yanks \`TOS_ISSUE\` blocks and runs \`tos <pro"

if (( DOC_CHANGES > 0 )); then
    APPLIED_STEPS+=("7")
else
    _skip "documentation already consistent"
fi
fi

# ==============================================================================
# STEP 8 — retire update.zsh
# ==============================================================================
if should_run 8; then
banner 8 "Retire the unapplied pivot script"

if [[ ! -f "update.zsh" ]]; then
    _skip "update.zsh already removed"
elif grep -q "export TOS_MNT_ROOT=\"\${BIN_DIR:h:h}\"" bin/tos.zsh 2>/dev/null \
  || grep -q 'TOS_MNT_ROOT:-\${BIN_DIR:h:h}' bin/tos.zsh 2>/dev/null; then
    _warn "update.zsh has NOT been applied — bin/tos.zsh still computes"
    _warn "TOS_MNT_ROOT from \${BIN_DIR:h:h}."
    if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would move update.zsh to ${BACKUP_DIR}/update.zsh${NC}"
    else
        backup "update.zsh"
        rm -f "update.zsh"
        _ok "Moved update.zsh into the backup. Decide deliberately whether the"
        _ok "deployment-driven-config pivot is still wanted; do not run it blind."
        CHANGED=1
    fi
    APPLIED_STEPS+=("8")
else
    _warn "bin/tos.zsh looks like update.zsh may already have been applied."
    _warn "Leaving update.zsh in place — inspect it manually."
    DEFERRED_STEPS+=("8 — update.zsh (ambiguous state)")
fi
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "${BOLD}${BLUE}════════════════════════════ SUMMARY ════════════════════════════${NC}"

if (( ${#APPLIED_STEPS} )); then
    _ok "Applied: ${APPLIED_STEPS[*]}"
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
    echo "Restore:  zsh inf/close_gaps.zsh --restore ${STAMP}"
    echo "Review:   git diff"
fi

cat <<'REMAINING'

────────────────────────────────────────────────────────────────
NOT CLOSED BY THIS SCRIPT — these are design decisions, not fixes
────────────────────────────────────────────────────────────────

  · create issue          documented in 02-architecture.md, not implemented
  · delete trinity        documented in ipc_contracts.md, not implemented
  · drop trinity          llm_agents/code.md instructs the Ghost to emit
                          TOS_DROP payloads for a command that does not exist.
                          Either implement it or remove section 3 of the prompt.
  · system export-parsers no modules/system/ dispatch path exists, and no
                          .config/parsers/parsers.json is present anywhere, so
                          the Neovim plugin always falls back to full-buffer
                          mode. Decide whether the parser cache is still wanted.
  · grand_tutorial.zsh    still calls `write project` and `sync project` in the
                          old order; left untouched deliberately since it
                          creates and destroys real repos.
  · delete project        `gh auth refresh -s delete_repo` cannot complete an
                          interactive browser flow under `sudo -n`. The MFA
                          isolation is architecturally sound but has never run
                          end to end. Test it by hand before 1.0.

Suggested next commands:

    zsh inf/close_gaps.zsh --dry-run     # inspect first
    zsh inf/close_gaps.zsh               # apply
    zunit tests/unit tests/inf           # confirm nothing regressed
    zsh docs/tutos/interactive_tutorial.zsh

REMAINING

exit 0
