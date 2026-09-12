#!/usr/bin/env zsh
# ==============================================================================
# Team of Six — The Contextual Trinity Interactive Tutorial
# TOS_TUTORIAL_REVISION=3
#
# A guided walkthrough of the full lifecycle against a real GitHub repository,
# structured around a single premise:
#
#     Do it this way and it works. Do it that way and the system refuses.
#
# Every safeguard is demonstrated twice — once succeeding, once being enforced.
# A guard you have watched refuse is worth more than one you have read about.
#
# SOURCES OF TRUTH
#   Protocol payloads are loaded from tests/shared/payloads/ — the same
#   fixtures the test suite asserts against and docs/04-protocol.md documents.
#   Nothing here re-types a payload by hand, so the protocol cannot drift
#   between the tests, the docs and this walkthrough.
#
#   Explanations live in docs/. Each chapter cites the section that covers it
#   rather than paraphrasing it.
#
# REQUIREMENTS
#   - `gh` authenticated (`gh auth login`)
#   - TOS deployed (inf/tos_deploy.zsh) and your user onboarded
#   - Write access to create repositories under the authenticated account
#
#   Your own git credentials are your business. If your remote is SSH with a
#   passphrase, you will be prompted when the Architect pushes — that is your
#   deliberate speed bump before touching remote truth, and the tutorial does
#   not try to remove it. The Ghost never prompts: it authenticates over HTTPS
#   with the PAT from .token, process-scoped, and never reads your keys.
#
# The repository created here is named tos-trinity-test-<epoch> so that
# inf/post_test_cleanup.zsh can find and remove it afterwards.
# ==============================================================================

set -e
[[ -z "$ZSH_VERSION" ]] && exec zsh "$0" "$@"

# --- Configuration & Validation ----------------------------------------------
SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
PAYLOADS="${REPO_ROOT}/tests/shared/payloads"

CONF="${REPO_ROOT}/conf/config"
[[ -f "$CONF" ]] || { echo "⛔ Config not found at $CONF" >&2; exit 1; }
source "$CONF"

: "${TOS_MNT_ROOT:?TOS_MNT_ROOT is not set by conf/config}"

TEST_REPO="tos-trinity-test-$(date +%s)"
TOS_BIN_CMD="$TOS_MNT_ROOT/.local/bin/tos.zsh"

[[ -x "$TOS_BIN_CMD" ]] || {
    echo "⛔ Gateway not found at $TOS_BIN_CMD. Run inf/tos_deploy.zsh first." >&2
    exit 1
}
[[ -d "$PAYLOADS" ]] || {
    echo "⛔ Payload fixtures not found at $PAYLOADS" >&2
    exit 1
}
gh auth status >/dev/null 2>&1 || {
    echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
}

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

tos() { "$TOS_BIN_CMD" "$TEST_REPO" "$@"; }

write_inbox() { printf '%s\n' "$1" > "$TOS_INPUT"; }
clear_inbox() { : > "$TOS_INPUT"; }

# ---------------------------------------------------------------------------
# load_payload <fixture-name>
# ---------------------------------------------------------------------------
# Copies a fixture from tests/shared/payloads/ into the inbox, retargeting it
# at this run's repository. The fixtures declare TARGET_PROJECT=team_of_six;
# only that literal is substituted, so a fixture that deliberately declares a
# WRONG project (meta_wrong_project.md) keeps its wrongness intact.
load_payload() {
    local name="$1"
    local src="${PAYLOADS}/${name}"
    [[ -f "$src" ]] || { echo "⛔ Missing payload fixture: $src" >&2; exit 1; }
    sed "s/team_of_six/${TEST_REPO}/g" "$src" > "$TOS_INPUT"
    terminal_view "inbox.md  ← tests/shared/payloads/${name}" "$(cat "$TOS_INPUT")"
}

# ---------------------------------------------------------------------------
# expect_rejection <description> <command...>
# ---------------------------------------------------------------------------
# Inverts the usual contract: the command MUST fail. A safeguard that quietly
# permits what it is supposed to refuse is the most dangerous outcome in the
# system, so success here aborts the tutorial loudly.
expect_rejection() {
    local what="$1"; shift
    echo ""
    echo "${BOLD}${RED}[NEGATIVE CASE]${NC} ${BOLD}${what}${NC}"
    echo "${DIM}  \$ $*${NC}"
    echo ""
    if "$@"; then
        echo ""
        echo "${RED}${BOLD}✗ ALARM — the command SUCCEEDED.${NC}"
        echo "${RED}  A safeguard that should have refused did not. This is not a${NC}"
        echo "${RED}  tutorial failure; it is a defect in the engine. Halting.${NC}"
        exit 1
    fi
    echo ""
    echo "${GREEN}✓ Refused, as designed.${NC}"
    clear_inbox
}

expect_success() {
    local what="$1"; shift
    echo ""
    echo "${BOLD}${GREEN}[POSITIVE CASE]${NC} ${BOLD}${what}${NC}"
    echo "${DIM}  \$ $*${NC}"
    echo ""
    "$@"
}

# --- Cleanup trap ------------------------------------------------------------
_cleanup() {
    local code=$?
    echo ""
    if (( code != 0 )); then
        echo "${RED}⚠️  Tutorial aborted (exit $code).${NC}"
        echo "    Workspace preserved for inspection: $WORKDIR"
    fi
    echo "${DIM}To remove the test repository and sandbox afterwards, run:${NC}"
    echo "${DIM}    ./inf/post_test_cleanup.zsh${NC}"
}
trap _cleanup EXIT

# ==============================================================================
# INTRODUCTION
# ==============================================================================
present_chapter "$(cat <<'EOF'
# The Contextual Trinity — a walkthrough of the enforcement surface

LLMs fail in development because they operate in a vacuum: losing track of
file state, hallucinating structures, drifting from the actual repository.
TOS hard-codes a context window that cannot drift.

  1 Issue   (Required Context)  — the only source of truth for what is built
  1 PR      (Active Context)    — the only isolated space where code changes
  1 Feature (Cognitive Context) — the only logic the Agent processes

This tutorial does not just show the happy path. Every safeguard is
demonstrated twice:

  [POSITIVE CASE]  the correct usage, which succeeds
  [NEGATIVE CASE]  the incorrect usage, which the engine refuses

If a NEGATIVE case ever succeeds, the tutorial halts immediately and tells
you so. A guard that fails open is worse than no guard at all.

Payloads are loaded from tests/shared/payloads/ — the same fixtures the test
suite asserts against, so what you see here cannot drift from what is tested.

Background reading:  docs/00-llm-pitfalls.md
                     docs/01-theSocialContract.md

This creates a REAL GitHub repository and destroys nothing you own.
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
Read:  docs/05-workflow.md § Phase 0

SAFEGUARDS DEMONSTRATED
  · Typo Guard         — the folder you stand in must match the project name
  · Initialization     — only `create project` is legal in a bare directory

Both checks run in Stage 0 of the gateway, BEFORE the sudo escalation, so
they are performed by you against your own filesystem. The Ghost never reads
the Architect's working tree.
Read:  docs/06-security.md § The Ghost Never Reads the Architect's Filesystem
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Standing in a directory that does NOT match the project name..."
cd "$WORKDIR"
echo "${DIM}  pwd: $PWD${NC}"

expect_rejection "Typo Guard: folder name does not match the project name" \
    tos create project

expect_rejection "Uninitialized: only 'create project' is legal here" \
    tos write issue

show_role "$YELLOW" "ARCHITECT" "Now standing in a correctly named, empty folder..."
mkdir -p "$WORKDIR/$TEST_REPO"
cd "$WORKDIR/$TEST_REPO"
echo "${DIM}  pwd: $PWD${NC}"

write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TITLE=$TEST_REPO
BODY=A fast integer calculator in Zsh, built through the TOS tutorial.
===TOS_META_END==="

expect_success "Incubate the project" tos create project

show_role "$YELLOW" "ARCHITECT" "Cloning the Remote Truth into my own working copy..."
gh repo clone "${GH_LOGIN}/${TEST_REPO}" .

show_role "$YELLOW" "ARCHITECT" "Adding a shared utility for the Agent to discover later..."
echo 'log() { echo "[LOG] $1"; }' > utils.zsh
git add utils.zsh
git commit -m "chore: add shared logging utility"
git push origin main

show_role "$PURPLE" "GHOST" "Remote Truth established. Sandbox provisioned. Trinity 0 soft-lock held."
end_turn

# ==============================================================================
# CHAPTER 1 — THE AIR-GAP
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 1: The Air-Gap

Goal:  Inspect the control plane the Ghost operates through.
Role:  The Ghost (System Bridge)
Read:  docs/02-architecture.md § The Control Plane
       docs/06-security.md § The Control Plane Layout

The IPC ribbon is two files. The inbox is yours to write; the outbox is the
Ghost's. The locks directory is mode 0700 and Ghost-exclusive — you cannot
edit a lock or a manifest visa from your own account, only through the
gateway.
EOF
)"

show_role "$PURPLE" "GHOST" "IPC ribbon — note the ownership split:"
terminal_view "ls -l" "$(ls -l "$TOS_INPUT" "$TOS_CONTEXT")"

show_role "$PURPLE" "GHOST" "Control plane locks (Ghost-exclusive, mode 0700):"
terminal_view "ls -ld locks" "$(ls -ld "$TOS_MNT_ROOT/.ipc/locks")"

show_role "$YELLOW" "ARCHITECT" "Proving I cannot read the lock directory myself:"
if ls "$TOS_MNT_ROOT/.ipc/locks/" >/dev/null 2>&1; then
    echo "${DIM}  (readable — you are running as the Ghost user or as root)${NC}"
else
    echo "${GREEN}  ✓ Permission denied, as designed.${NC}"
fi
end_turn

# ==============================================================================
# CHAPTER 2 — SCOPING AND THE EVENT HORIZON
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 2: Scoping and the Event Horizon

Goal:  Break the feature set into atomic issues.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write issue
Read:  docs/03-trinity.md § The Write Policy
       docs/04-protocol.md § The Issue Block

SAFEGUARDS DEMONSTRATED
  · Lock hierarchy — Trinity 0 is a read-only sanctuary. Planning operations
    are permitted; code mutation is not. The tier is decided by which
    directory the action script lives in (soft/ or hard/), so the gateway
    needs no hardcoded list of privileged commands.
EOF
)"

show_role "$CYAN" "AGENT" "Proposing atomic tickets. Issue creation is a soft-lock operation."
load_payload "valid_issue.md"
expect_success "Create an issue under a Trinity 0 soft lock" tos write issue

show_role "$CYAN" "AGENT" "A second ticket, deferred to a future trinity."
write_inbox "===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Deferred to a future trinity.
===TOS_ISSUE_END==="
expect_success "Create a second issue" tos write issue

show_role "$YELLOW" "ARCHITECT" "Verifying Remote Truth..."
terminal_view "gh issue list" "$(gh issue list)"

show_role "$CYAN" "AGENT" "Now attempting to write CODE while still in the sanctuary."
echo "${DIM}  The inbox is left empty on purpose: this demonstrates the lock tier${NC}"
echo "${DIM}  alone, with no payload for the hallucination perimeter to reject first.${NC}"
clear_inbox

expect_rejection "Event Horizon: write code requires a hard lock (Trinity > 0)" \
    tos write code
end_turn

# ==============================================================================
# CHAPTER 3 — OPENING THE WORKSPACE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 3: Opening the Workspace

Goal:  Align the sandbox, create the Trinity, cross the Event Horizon.
Role:  The Ghost (System Bridge)
Cmds:  tos <project> sync trinity 0
       tos <project> create trinity 1
       tos <project> sync trinity 1
Read:  docs/03-trinity.md § The Atomic Handover
       docs/03-trinity.md § The Clean Room Snapshot

The Clean Room Snapshot is the heart of the system, so this chapter prints
it in full rather than excerpting it. Everything in it is derived from the
source of truth — GitHub and the git history. Nothing comes from a previous
conversation, and nothing can have drifted.
EOF
)"

show_role "$PURPLE" "GHOST" "Aligning the sandbox with main (absorbs the Architect's utils.zsh)..."
expect_success "Sync to Trinity 0" tos sync trinity 0

show_role "$PURPLE" "GHOST" "Creating the Trinity: branch + draft PR linked to issue #1."
expect_success "Create Trinity 1" tos create trinity 1

show_role "$PURPLE" "GHOST" "Atomic Handover into Trinity 1, then the full snapshot."
expect_success "Sync to Trinity 1" tos sync trinity 1

show_role "$CYAN" "AGENT" "That snapshot is my entire context. Not memory — verified state."
end_turn

# ==============================================================================
# CHAPTER 4 — SURGICAL CONTEXT INJECTION
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 4: Surgical Context Injection (Peek)

Goal:  Feed the Agent's context window precisely, one file at a time.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> sync peek <file>
Read:  docs/05-workflow.md § Phase 4

Peek APPENDS to the outbox. It does not reset the snapshot. Run
`sync trinity <N>` to get a clean one.
EOF
)"

expect_success "Inject utils.zsh into the Agent's context" tos sync peek utils.zsh

show_role "$CYAN" "AGENT" "I can now see log(). I will use it rather than inventing my own."
end_turn

# ==============================================================================
# CHAPTER 5 — THE INTENT LOCK
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 5: The Intent Lock (write plan)

Goal:  Declare the exact blast radius BEFORE any code is written.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write plan
Read:  docs/04-protocol.md § The Plan Block (The Intent Lock)
       governance/adr.md § The Locked Manifest

SAFEGUARDS DEMONSTRATED
  · No visa, no writes — write code is blocked entirely until an Intent Lock
    exists. The manifest visa is prospective: it authorises what the Agent
    MAY do, before it does anything.

The visa lives in the control plane at mode 0700. You cannot edit it from
your own account. The only way to change it is another `write plan`.
EOF
)"

show_role "$CYAN" "AGENT" "Attempting to write code before declaring intent."
load_payload "valid_file_single.md"

expect_rejection "No manifest visa: write code is blocked before write plan" \
    tos write code

show_role "$CYAN" "AGENT" "Declaring intent: two files, no more."
load_payload "valid_plan.md"
expect_success "Establish the Intent Lock" tos write plan

show_role "$PURPLE" "GHOST" "The visa now exists in the control plane:"
terminal_view "manifest visa" "$(sudo -n -u "${AI_USER:-team_of_six}" cat \
    "$TOS_MNT_ROOT/.ipc/locks/${TEST_REPO}_trinity_1.manifest" 2>/dev/null \
    || echo '(Ghost-exclusive — readable only through the gateway)')"
end_turn

# ==============================================================================
# CHAPTER 6 — THE RED PHASE AND THE VISA
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 6: The Red Phase — and what the visa refuses

Goal:  Write a failing test. Then try to write outside the approved scope.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write code
Read:  docs/04-protocol.md § The File Block
       docs/06-security.md § The Trust Model

SAFEGUARDS DEMONSTRATED
  · Manifest visa    — a file not on the approved list is a SEC-FAULT
  · Path traversal   — '..' and absolute paths are rejected outright
  · Missing path     — a FILE block with no target is malformed, not silent

Every rejection happens BEFORE a single byte reaches the sandbox.
EOF
)"

show_role "$CYAN" "AGENT" "Writing the failing test — test_calculator.zsh is on the visa."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Test suite using native Zsh arithmetic and the shared log() utility.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log \"Running tests...\"
[[ \"\$(add 5 5)\" == \"10\" ]] || exit 1
log \"PASS: add 5 5 = 10\"
===TOS_FILE_END==="
terminal_view "inbox.md" "$(cat "$TOS_INPUT")"

expect_success "Write a file that IS on the manifest visa" tos write code

show_role "$CYAN" "AGENT" "Now attempting a file that is NOT on the visa."
load_payload "file_outside_manifest.md"
expect_rejection "SEC-FAULT: rogue.zsh is not authorised by the visa" \
    tos write code

show_role "$CYAN" "AGENT" "Now attempting to escape the sandbox entirely."
load_payload "file_path_traversal.md"
expect_rejection "SEC-FAULT: path traversal outside the sandbox" \
    tos write code

show_role "$CYAN" "AGENT" "Now a malformed block with no target path."
load_payload "file_missing_path.md"
expect_rejection "Malformed FILE block: no target path declared" \
    tos write code

show_role "$YELLOW" "ARCHITECT" "Confirming the sandbox contains only the authorised file:"
git fetch origin
terminal_view "git diff --name-only origin/main...origin/tos-work-1" \
    "$(git diff --name-only origin/main...origin/tos-work-1)"
echo "${GREEN}  ✓ No rogue.zsh. No passwd. Only what the visa allowed.${NC}"
end_turn

# ==============================================================================
# CHAPTER 7 — ASYNC REVIEW & ROUTING
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 7: Review & Ghost Routing

Goal:  Architect intervenes with Wisdom; the Agent routes feedback by flag.
Role:  Shared (Architect tags → Agent routes)
Read:  docs/05-workflow.md § Phase 7
       llm_agents/code.md § 7. Async Review Flags

  [FIXME]     → fix now via write code
  [CHALLENGE] → defend or adjust the logic first
  [QUESTION]  → answer via write comment
  [TODO]      → defer via write issue

Note: the pushes below are YOURS, not the Ghost's. If your remote is SSH
with a passphrase you will be prompted — that is your own deliberate pause
before touching remote truth, and TOS does not interfere with it.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Checking out the Ghost's branch and injecting review tags..."
git checkout tos-work-1
git pull origin tos-work-1

gh issue comment 1 -b "[QUESTION] Should we support negative numbers?"
sed -i 's|log "Running tests..."|log "Running tests..." # [CHALLENGE] Why native Zsh math instead of bc?|' test_calculator.zsh
git commit -am "review: architect tags injected inline"
git push origin tos-work-1

show_role "$PURPLE" "GHOST" "Syncing the review back into the Agent's context..."
expect_success "Regenerate the snapshot with the review thread" tos sync trinity 1

show_role "$CYAN" "AGENT" "Routing: QUESTION and CHALLENGE both answer via write comment."
load_payload "valid_comment.md"
expect_success "Post the answer to the thread" tos write comment

show_role "$CYAN" "AGENT" "Deferring divide() to its own trinity rather than widening this one."
write_inbox "===TOS_ISSUE_START===
TITLE=Implement divide()
BODY=Deferred from the Trinity 1 review thread.
===TOS_ISSUE_END==="
expect_success "Defer the TODO to a new issue" tos write issue
end_turn

# ==============================================================================
# CHAPTER 8 — THE GREEN PHASE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 8: The Green Phase

Goal:  Minimum implementation to turn the test green.
Role:  Team of Six (Agent / Doer)
Cmd:   tos <project> write code
Read:  docs/05-workflow.md § Phase 8

The visa from Chapter 5 is still active. calculator.zsh is on it, so this
passes. Nothing else would.
EOF
)"

show_role "$PURPLE" "GHOST" "Re-syncing so the sandbox carries the Architect's review commit..."
expect_success "Sync before writing" tos sync trinity 1

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
terminal_view "inbox.md" "$(cat "$TOS_INPUT")"

expect_success "Write the implementation" tos write code
end_turn

# ==============================================================================
# CHAPTER 9 — THE ENFORCEMENT SURFACE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 9: The Enforcement Surface

Goal:  Demonstrate the remaining guards back to back.
Role:  The Gateway
Read:  docs/06-security.md § The Trust Model
       governance/adr.md § Exact-Once Execution

SAFEGUARDS DEMONSTRATED
  · Hallucination perimeter (project)  — payload targets the wrong repository
  · Hallucination perimeter (trinity)  — payload targets a stale trinity
  · Exact-once execution               — the inbox is consumed, not reused

These are the last line of defence against an Agent operating on a stale or
incorrect mental model of its own working context. The LLM is treated as
hostile input: every declaration is cross-referenced against ground truth
before anything executes.
EOF
)"

show_role "$CYAN" "AGENT" "Declaring the wrong project — a classic context-drift failure."
load_payload "meta_wrong_project.md"
expect_rejection "Hallucination: payload targets a different project" \
    tos write code

show_role "$CYAN" "AGENT" "Declaring a trinity that is not the active one."
load_payload "meta_wrong_trinity.md"
expect_rejection "Hallucination: payload targets trinity 99" \
    tos write code

show_role "$PURPLE" "GHOST" "Exact-once execution: the inbox after a successful write."
write_inbox "===TOS_ISSUE_START===
TITLE=Exactly-once demonstration
BODY=This issue is created once. The payload is then gone.
===TOS_ISSUE_END==="
echo "${DIM}  inbox size before: $(wc -c < "$TOS_INPUT") bytes${NC}"
expect_success "Consume the payload" tos write issue
echo ""
echo "${DIM}  inbox size after:  $(wc -c < "$TOS_INPUT") bytes${NC}"
echo "${GREEN}  ✓ Truncated to zero before any network call — a retry cannot${NC}"
echo "${GREEN}    double-create. The Architect must deliberately resubmit.${NC}"

expect_rejection "Resubmitting: there is nothing left to execute" \
    tos write issue
end_turn

# ==============================================================================
# CHAPTER 10 — REFACTOR & RETROSPECTIVE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 10: Refactor & Retrospective

Goal:  Clean up, then encode the session's learnings into the repository.
Role:  Team of Six (Agent / Doer)
Cmds:  tos <project> write plan   (widen the visa)
       tos <project> write code
Read:  docs/05-workflow.md § Phase 9
       docs/08-agentic-unleash.md § High-Fidelity Pair Programming

Widening scope requires a NEW write plan. The visa is not negotiable, and
re-issuing it REPLACES the previous one rather than adding to it.
EOF
)"

show_role "$CYAN" "AGENT" "Documentation is outside my current visa. Re-declaring intent."
write_inbox "===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh README.md docs/learnings.md
===TOS_PLAN_END==="
expect_success "Widen the Intent Lock" tos write plan

show_role "$CYAN" "AGENT" "Refactoring and writing the retrospective."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Refactor: document add() and record session learnings
BODY=Adds docstrings, documents usage, and encodes two domain rules discovered during this trinity.
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

expect_success "Commit the refactor and the retrospective" tos write code
end_turn

# ==============================================================================
# CHAPTER 11 — TRINITY CLOSURE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 11: The Closure

Goal:  Prove the Agent knows exactly what it did, then merge.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> write trinity
Read:  docs/04-protocol.md § The Trinity Block (Closure MANIFEST)

SAFEGUARDS DEMONSTRATED
  · Closure MANIFEST — must match `git diff --name-only origin/main...HEAD`
    EXACTLY. A file forgotten, or one claimed but not changed, aborts the
    merge as a context hallucination.

This is retrospective, where the Intent Lock was prospective. One authorises
what the Agent may do; this one proves it knows what it did.

The Agent is FORBIDDEN from guessing the MANIFEST from memory. The Architect
supplies the verified list.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Pulling the Ghost's work and running the tests locally..."
git fetch origin
git pull --ff-only origin tos-work-1
if zsh ./test_calculator.zsh; then
    echo "${GREEN}✅ Local tests passed.${NC}"
else
    echo "${RED}❌ Local tests failed — halting before merge.${NC}"
    exit 1
fi

show_role "$PURPLE" "GHOST" "Re-syncing so the sandbox diff matches the Architect's..."
expect_success "Final sync before closure" tos sync trinity 1

show_role "$YELLOW" "ARCHITECT" "Computing the verified MANIFEST — never from the Agent's memory."
MANIFEST_FILES="$(git diff --name-only origin/main...HEAD | tr '\n' ' ' | sed 's/ *$//')"
terminal_view "git diff --name-only origin/main...HEAD" "$MANIFEST_FILES"

show_role "$CYAN" "AGENT" "First, deliberately omitting a file from the declaration."
INCOMPLETE="$(echo "$MANIFEST_FILES" | awk '{$NF=""; print}' | sed 's/ *$//')"
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=$INCOMPLETE
===TOS_TRINITY_END==="
terminal_view "inbox.md (incomplete on purpose)" "$(cat "$TOS_INPUT")"

expect_rejection "CONTEXT HALLUCINATION: manifest omits a changed file" \
    tos write trinity

show_role "$YELLOW" "ARCHITECT" "Now the complete, verified declaration."
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=$MANIFEST_FILES
===TOS_TRINITY_END==="

gh pr review tos-work-1 --comment -b "Tests pass locally. Documentation updated. Approved for merge."
expect_success "Finalize the Trinity" tos write trinity

show_role "$YELLOW" "ARCHITECT" "Cleaning up my local branch..."
git checkout main
git pull origin main
git branch -D tos-work-1 2>/dev/null || true

terminal_view "gh issue view 1" "$(gh issue view 1 | grep -i state || true)"
end_turn

# ==============================================================================
# CHAPTER 12 — TEARDOWN
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 12: Teardown and the Destructive Gate

Goal:  Remove the Ghost's sandbox. The remote survives untouched.
Role:  Principal Architect (Wisdom)
Cmd:   tos <project> close project
Read:  docs/06-security.md § The HITL Destructive Gate
       governance/adr.md § HITL Destructive Gate

SAFEGUARDS DEMONSTRATED
  · CONFIRM=TRUE — every close and delete operation aborts before evaluating
    any other logic unless the payload contains this exact string.

The Agent cannot produce CONFIRM=TRUE by drift: the string has no plausible
role in any non-destructive operation. It must be written deliberately.
EOF
)"

show_role "$CYAN" "AGENT" "Requesting teardown WITHOUT the confirmation string."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=0
TITLE=Close project
BODY=No confirmation string present.
===TOS_META_END==="
terminal_view "inbox.md (no CONFIRM)" "$(cat "$TOS_INPUT")"

expect_rejection "Destructive gate: CONFIRM=TRUE is absent" \
    tos close project

show_role "$YELLOW" "ARCHITECT" "Verifying the sandbox survived the refused command:"
if sudo -n -u "${AI_USER:-team_of_six}" test -d "$TOS_SANDBOX/$TEST_REPO" 2>/dev/null; then
    echo "${GREEN}  ✓ Sandbox intact. Nothing was destroyed.${NC}"
else
    echo "${DIM}  (sandbox state not directly readable from this account)${NC}"
fi

show_role "$YELLOW" "ARCHITECT" "Now with deliberate confirmation."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=0
TITLE=Close project
BODY=Tutorial complete. Removing the local sandbox.
CONFIRM=TRUE
===TOS_META_END==="

expect_success "Tear down the sandbox" tos close project

echo ""
echo "${GREEN}${BOLD}🏁 Tutorial complete.${NC}"
echo ""
echo "Safeguards demonstrated, each refusing as designed:"
echo "  · Typo Guard and initialization check      (Chapter 0)"
echo "  · Event Horizon / lock hierarchy           (Chapter 2)"
echo "  · Intent Lock — no visa, no writes         (Chapter 5)"
echo "  · Manifest visa, traversal, malformed block (Chapter 6)"
echo "  · Hallucination perimeter, exact-once       (Chapter 9)"
echo "  · Closure MANIFEST audit                    (Chapter 11)"
echo "  · HITL destructive gate                     (Chapter 12)"
echo ""
echo "Not demonstrated: lock exclusivity between two Architects. It requires a"
echo "second system user, and simulating it would have meant faking the very"
echo "thing under test. See docs/06-security.md § Multi-Tenant Operation."
echo ""
echo "Remote repository: ${BOLD}https://github.com/${GH_LOGIN}/${TEST_REPO}${NC}"
echo "Local working copy: ${BOLD}${WORKDIR}/${TEST_REPO}${NC}"
echo ""
echo "To purge both: ${BOLD}./inf/post_test_cleanup.zsh${NC}"
echo ""
