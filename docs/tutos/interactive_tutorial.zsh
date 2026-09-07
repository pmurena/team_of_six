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
