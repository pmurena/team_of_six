#!/usr/bin/env zsh
# ==============================================================================
# Team of Six — The Contextual Trinity Interactive Tutorial
# TOS_TUTORIAL_REVISION=4
#
#     Do it this way and it works. Do it that way and the system refuses.
#
# Every safeguard is demonstrated twice — once succeeding, once being enforced.
# A guard you have watched refuse is worth more than one you have read about.
#
# Payloads come from tests/shared/payloads/ — the same fixtures the test suite
# asserts against, so the protocol cannot drift between the tests, the docs and
# this walkthrough. Explanations live in docs/; each chapter cites the section
# that covers it rather than paraphrasing it.
#
# REQUIREMENTS
#   · `gh` authenticated as YOU, the Architect (`gh auth login`)
#   · TOS deployed (inf/tos_deploy.zsh) with your user onboarded
#   · The Ghost's .token belongs to a SEPARATE GitHub account — see
#     docs/06-security.md § The Ghost Needs Its Own GitHub Identity.
#     Chapter 3 checks this and stops if it is not the case.
#
# Your own git credentials are your business. If your remote is SSH with a
# passphrase you will be prompted when you push — that is your deliberate pause
# before touching remote truth, and the tutorial does not remove it. The Ghost
# never prompts: it authenticates over HTTPS with its PAT, process-scoped, and
# never reads your keys.
#
# Creates a repository named tos-trinity-test-<epoch>, which
# inf/post_test_cleanup.zsh knows how to remove. Allow about an hour: the
# chapters are meant to be read, not skipped through.
# ==============================================================================

set -e
[[ -z "$ZSH_VERSION" ]] && exec zsh "$0" "$@"

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
PAYLOADS="${REPO_ROOT}/tests/shared/payloads"

CONF="${REPO_ROOT}/conf/config"
[[ -f "$CONF" ]] || { echo "⛔ Config not found at $CONF" >&2; exit 1; }
source "$CONF"
: "${TOS_MNT_ROOT:?TOS_MNT_ROOT is not set by conf/config}"

TEST_REPO="tos-trinity-test-$(date +%s)"
TOS_BIN_CMD="$TOS_MNT_ROOT/.local/bin/tos.zsh"

[[ -x "$TOS_BIN_CMD" ]] || { echo "⛔ Gateway not found at $TOS_BIN_CMD. Run inf/tos_deploy.zsh first." >&2; exit 1; }
[[ -d "$PAYLOADS" ]]   || { echo "⛔ Payload fixtures not found at $PAYLOADS" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "⛔ gh CLI is not authenticated. Run: gh auth login" >&2; exit 1; }

export TOS_IPC="$TOS_MNT_ROOT/.ipc/$USER"
export TOS_INPUT="$TOS_IPC/inbox.md"
export TOS_CONTEXT="$TOS_IPC/outbox.md"
export TOS_SANDBOX="$TOS_MNT_ROOT/sandbox/$USER"

WORKDIR="$(mktemp -d "/tmp/tos_tutorial_XXXXXX")"
GH_LOGIN="$(gh api user -q .login)"

# --- UI ----------------------------------------------------------------------
NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
CYAN=$'\033[1;36m'; YELLOW=$'\033[1;33m'; PURPLE=$'\033[1;35m'
BLUE=$'\033[1;34m'; GREEN=$'\033[1;32m'; RED=$'\033[1;31m'

# Chapter headers run 25–40 lines. On an 80x24 terminal the goal and the
# safeguard list scroll off before they can be read, which is precisely the
# part that says what is about to happen.
#
# There is deliberately no `clear`: erasing the turn you just watched is what
# made the flow feel unnatural. The whole session stays in scrollback.
#
# Only the header is paged. The tutorial interleaves text with live sessions —
# gh cloning, git asking for a passphrase, the gateway streaming — and paging
# those would put the pager and the passphrase prompt in a fight over stdin.
fits_on_screen() {
    local rows=${LINES:-24}
    (( $(printf "%s\\n" "$1" | wc -l) + 4 <= rows ))
}

present_chapter() {
    local body="$1"
    local framed="${BLUE}================================================================================${NC}
${body}
${BLUE}================================================================================${NC}"

    if [[ -t 1 ]] && ! fits_on_screen "$framed"; then
        printf "%s\\n" "$framed" | ${PAGER:-less -R --no-init --quit-if-one-screen}
    else
        printf "%s\\n" "$framed"
    fi

    echo ""
    printf "${YELLOW}🚀 Press [Enter] to run this turn, or [Ctrl+C] to stop... ${NC}"
    # /dev/tty, not stdin: the pager has consumed stdin by this point.
    read -r < /dev/tty
}

show_role() {
    echo ""
    echo "${BOLD}${1}[$2]${NC} $3"
}

terminal_view() {
    echo "${DIM}┌─[ $1 ]───────────────────────────────────────────────────────${NC}"
    printf '%s\n' "$2" | sed 's/^/│ /'
    echo "${DIM}└──────────────────────────────────────────────────────────────${NC}"
}

end_turn() {
    printf "\n${YELLOW}🛑 Turn complete. Press [Enter] for the next chapter... ${NC}"
    read -r < /dev/tty
}

tos() { "$TOS_BIN_CMD" "$TEST_REPO" "$@"; }
write_inbox() { printf '%s\n' "$1" > "$TOS_INPUT"; }
clear_inbox() { : > "$TOS_INPUT"; }

# Copies a fixture into the inbox, retargeting it at this run's repository.
# Fixtures declare TARGET_PROJECT=team_of_six; only that literal is replaced,
# so a fixture that deliberately declares a WRONG project keeps its wrongness.
load_payload() {
    local src="${PAYLOADS}/$1"
    [[ -f "$src" ]] || { echo "⛔ Missing payload fixture: $src" >&2; exit 1; }
    sed "s/team_of_six/${TEST_REPO}/g" "$src" > "$TOS_INPUT"
    terminal_view "inbox.md  ← tests/shared/payloads/$1" "$(cat "$TOS_INPUT")"
}

# Inverts the usual contract: the command MUST fail. A safeguard that quietly
# permits what it should refuse is the most dangerous outcome in the system.
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

# Advance the phase: the Architect approves with a transition tag, then the
# Ghost applies it. Forward only, exactly one step, verdict APPROVED.
advance_phase() {
    local from="$1" to="$2" note="$3"
    show_role "$YELLOW" "ARCHITECT" "Approving the ${from} work: ${from} → ${to}"
    gh pr review "tos-work-1" --approve --body "[PHASE:${from:u}->${to:u}] ${note}"
    expect_success "Apply the ${from} → ${to} transition" tos write phase
}

_cleanup() {
    local code=$?
    echo ""
    if (( code != 0 )); then
        echo "${RED}⚠️  Tutorial stopped (exit $code).${NC}"
        echo "    Workspace preserved for inspection: $WORKDIR"
    fi
    echo "${DIM}To remove the test repository and sandbox afterwards, run:${NC}"
    echo "${DIM}    ./inf/post_test_cleanup.zsh${NC}"
}
trap _cleanup EXIT

# ==============================================================================
# WELCOME
# ==============================================================================
present_chapter "$(cat <<'EOF'
  _______                    ____   __   _____ _      
 |__   __|                  / __ \ / _| / ____(_)     
    | | ___  __ _ _ __ ___  | |  | | |_ | (___  ___  __
    | |/ _ \/ _` | '_ ` _ \ | |  | |  _| \___ \| \ \/ /
    | |  __/ (_| | | | | | || |__| | |  ____) | |>  < 
    |_|\___|\_,_|_| |_| |_| \____/|_|  |_____/|_/_/\_\

Welcome. Over the next hour or so you are going to build a small feature end
to end, with an AI agent doing the typing and you doing the deciding. The
chapters are meant to be read rather than skipped through — the refusals are
the point, and each one is explained before it happens.

Here is the problem TOS exists to solve. Large language models are genuinely
good at reasoning about code, and genuinely bad at knowing where they are.
Ask one to help across a real codebase for an afternoon and it will start
editing the wrong file, inventing a function signature it half-remembers, or
confidently implementing the feature you discussed three messages ago. The
usual response is better prompting. That helps at the margins and does not
fix the cause, which is that the model has no grounding in the actual state
of your repository.

TOS takes the other route. Rather than asking the model to be careful, it
builds a structure in which carelessness is refused. Three roles:

  THE ARCHITECT   You. You own the repository and make every decision that
                  matters. You approve, you review, you say no.

  THE AGENT       The language model. It reasons and it writes payloads. It
                  cannot run a command or touch a file. Not "does not" —
                  cannot.

  THE GHOST       A locked-down Unix user with its own sandbox and its own
                  GitHub identity. It executes what the gateway has already
                  validated, and nothing else.

Between them sits a gateway that checks every operation against reality
before it happens. That is what you are about to watch.

The unit of work is the Contextual Trinity: one issue, one branch, one
feature. Never two. The Agent works through four phases — Red, Green,
Refactor, Retrospect — and cannot advance from one to the next without your
explicit approval on the pull request.

WHAT MAKES THIS TUTORIAL DIFFERENT

Every safeguard is shown twice.

  [POSITIVE CASE]   the correct usage, which succeeds
  [NEGATIVE CASE]   the incorrect usage, which the engine refuses

When a negative case is coming, you will be told what is about to be
attempted and why it should fail. If one ever succeeds, the tutorial halts
immediately and says so — a guard that fails open is worse than no guard.

Nothing here is simulated. Real repository, real commits, real pull request,
real refusals. Press Enter and let us begin.
EOF
)"

# ==============================================================================
# CHAPTER 0 — THE GENESIS
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 0 — The Genesis

Before anything can be built there must be a Remote Truth: a real repository
on GitHub that the Ghost will mirror into its sandbox. Everything the Agent
ever learns about this project will be derived from there, never from
conversation.

YOU create that repository. Not TOS.

This is deliberate and it is enforced, not merely encouraged. The Ghost
authenticates as a GitHub App whose installation is granted `contents`,
`issues` and `pull_requests` — and pointedly not `administration`. It cannot
create a repository and it cannot destroy one, because it lacks the
capability, not because the code declines to use it. An engine an LLM helps
drive should not be able to reshape your account.

So the opening move is yours: create the repository, clone it, and then ask
the Ghost to attach itself.

Goal:  Create the Remote Truth, then have TOS provision a sandbox for it.
Role:  Principal Architect, then the Ghost
Cmd:   tos <project> sync project
Read:  docs/05-workflow.md § Phase 1
       governance/adr.md § TOS Does Not Create or Destroy Remotes

TWO SAFEGUARDS FIRST

Before the real command, two wrong ones. Both checks run in Stage 0 of the
gateway — BEFORE it escalates to the Ghost — which means they are performed
by you, against your own filesystem. The Ghost never reads the Architect's
working tree, and that ordering is what guarantees it.

  · Outside a clone   TOS has no idea which repository you mean
  · Project mismatch  you are in a clone of X but asked about Y

Read:  docs/06-security.md § The Ghost Never Reads the Architect's Filesystem
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Creating the Remote Truth with my own credentials."
echo "${DIM}  Note that this is plain gh, not tos. TOS is not involved and could${NC}"
echo "${DIM}  not do this if it wanted to.${NC}"
gh repo create "$TEST_REPO" --private

show_role "$YELLOW" "ARCHITECT" "Standing somewhere that is not a clone of anything."
cd "$WORKDIR"
echo "${DIM}  pwd: $PWD${NC}"

expect_rejection "Outside a clone: TOS cannot tell which repository you mean" \
    tos sync project

show_role "$YELLOW" "ARCHITECT" "Cloning the Remote Truth into my own working copy."
mkdir -p "$WORKDIR/$TEST_REPO"
cd "$WORKDIR/$TEST_REPO"
gh repo clone "${GH_LOGIN}/${TEST_REPO}" .
echo "${DIM}  This clone is mine. The Ghost gets its own, in the sandbox, and the${NC}"
echo "${DIM}  two never touch. Mine is where I review and run tests.${NC}"

show_role "$YELLOW" "ARCHITECT" "Seeding a shared utility for the Agent to discover later."
echo 'log() { echo "[LOG] $1"; }' > utils.zsh
git add utils.zsh
git commit -m "chore: add shared logging utility"
git push origin main

echo ""
echo "${DIM}  Now a mistyped project name, from inside a perfectly good clone:${NC}"

expect_rejection "Project mismatch: this clone is not the project you named" \
    "$TOS_BIN_CMD" "definitely-not-this-project" sync project

show_role "$PURPLE" "GHOST" "Attaching: cloning into the sandbox, taking the Trinity 0 soft-lock."
expect_success "Provision the sandbox" tos sync project

show_role "$PURPLE" "GHOST" "Remote Truth established. Sandbox provisioned. Trinity 0 soft-lock held."
end_turn

# ==============================================================================
# CHAPTER 1 — THE AIR-GAP
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 1 — The Air-Gap

Take a moment to look at the machinery, because the permissions are the
argument.

The Agent and the Ghost communicate with you through two files. You write to
the inbox; the Ghost writes to the outbox. That is the entire interface — no
sockets, no daemon, no API. Two files you can read with `cat`.

The locks directory is different. It is mode 0700 and owned by the Ghost,
which means you cannot edit a lock or a manifest visa from your own account
even though you are the one who authorised them. The only route is through
the gateway. That is deliberate: a safety limit you can quietly edit is not
a limit.

Goal:  See the control plane you have been given.
Role:  The Ghost
Read:  docs/02-architecture.md § The Control Plane
       docs/06-security.md § The Control Plane Layout
EOF
)"

show_role "$PURPLE" "GHOST" "The IPC ribbon — note the ownership split:"
terminal_view "ls -l" "$(ls -l "$TOS_INPUT" "$TOS_CONTEXT")"
echo "${DIM}  The inbox is yours to write and the Ghost's to consume — it truncates${NC}"
echo "${DIM}  the inbox before any network call, so exact-once execution depends on${NC}"
echo "${DIM}  the Ghost being able to write there too. The outbox is 0640: the${NC}"
echo "${DIM}  Ghost writes, you only read. A snapshot you could edit would be${NC}"
echo "${DIM}  worth nothing.${NC}"
echo "${DIM}  Its output cannot${NC}"
echo "${DIM}  be forged by anyone who is not the Ghost.${NC}"

show_role "$PURPLE" "GHOST" "The locks directory:"
terminal_view "ls -ld" "$(ls -ld "$TOS_MNT_ROOT/.ipc/locks")"

show_role "$YELLOW" "ARCHITECT" "Proving I cannot read it myself:"
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
# Chapter 2 — Scoping, and the Event Horizon

Nothing gets built without an issue. The issue is the single source of truth
for what a Trinity is about, and its number becomes the Trinity's number.

Right now we are in Trinity 0 — the sanctuary. Here the Agent may brainstorm,
scope, argue and open issues. What it may not do is write code. That boundary
is called the Event Horizon, and it is enforced by which directory an action
script lives in: soft/ or hard/. The gateway needs no list of privileged
commands; the filesystem is the list.

Goal:  Break the work into atomic issues.
Role:  Team of Six (Agent)
Cmd:   tos <project> write issue
Read:  docs/03-trinity.md § The Write Policy
       docs/04-protocol.md § The Issue Block
EOF
)"

show_role "$CYAN" "AGENT" "Proposing an atomic ticket. Issue creation is a soft-lock operation."
load_payload "valid_issue.md"
expect_success "Create an issue under a Trinity 0 soft lock" tos write issue

show_role "$CYAN" "AGENT" "A second ticket, deliberately deferred."
write_inbox "===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Deferred to a future trinity.
===TOS_ISSUE_END==="
expect_success "Create a second issue" tos write issue

show_role "$YELLOW" "ARCHITECT" "Verifying Remote Truth:"
terminal_view "gh issue list" "$(gh issue list)"

show_role "$CYAN" "AGENT" "Now let us try to write code while still in the sanctuary."
echo "${DIM}  The inbox is left empty on purpose. With no payload there is nothing${NC}"
echo "${DIM}  for the hallucination checks to reject first, so what you see is the${NC}"
echo "${DIM}  lock tier and nothing else.${NC}"
clear_inbox

expect_rejection "Event Horizon: write code requires a hard lock (Trinity > 0)" \
    tos write code
end_turn

# ==============================================================================
# CHAPTER 3 — OPENING THE WORKSPACE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 3 — Opening the Workspace

Crossing the Event Horizon. Three commands: align the sandbox with main,
create the Trinity, then hand over into it.

`create trinity` opens the branch, opens a draft pull request, and writes a
phase record initialised at RED. From here the Agent cannot advance to Green
without your approval on that pull request.

`sync trinity` performs the Atomic Handover and regenerates the Clean Room
Snapshot. That snapshot is the Agent's entire context: the issue, the pull
request thread, the diff, the file map, and the current phase. Everything in
it is derived from GitHub and the git history. Nothing survives from a
previous conversation, so nothing can have drifted.

It is printed here in full rather than excerpted, because it is the heart of
the system and worth reading once.

Goal:  Create the Trinity and enter it.
Role:  The Ghost
Read:  docs/03-trinity.md § The Atomic Handover
       docs/03-trinity.md § The Clean Room Snapshot
EOF
)"

show_role "$PURPLE" "GHOST" "Aligning the sandbox with main (absorbing the utils.zsh commit)."
expect_success "Sync to Trinity 0" git pull origin tos-work-1 || true; git pull origin tos-work-1 --rebase &> /dev/null || true; tos sync trinity 0

show_role "$PURPLE" "GHOST" "Creating the Trinity: branch, draft PR, phase record at red."
expect_success "Create Trinity 1" tos create trinity 1

# --- identity check -----------------------------------------------------------
# The phase gate needs the Architect and the Ghost to be different GitHub
# accounts. GitHub refuses to let anyone approve their own pull request, and
# invariant 8 refuses a review authored by the Ghost. If the Ghost's token is
# the Architect's own PAT, both fire and no phase can ever advance.
PR_AUTHOR="$(gh pr view tos-work-1 --json author -q .author.login 2>/dev/null || echo '')"
if [[ "$PR_AUTHOR" == "$GH_LOGIN" ]]; then
    echo ""
    echo "${RED}${BOLD}⛔ The Ghost is using YOUR GitHub identity.${NC}"
    echo ""
    echo "   The pull request was opened by '${PR_AUTHOR}', which is you."
    echo "   GitHub does not allow anyone to approve their own pull request, and"
    echo "   the phase gate refuses a review authored by the Ghost. No phase"
    echo "   could ever advance, so the tutorial would stall in Chapter 8."
    echo ""
    echo "   The Ghost needs its own GitHub account, with its PAT in .token."
    echo "   See docs/06-security.md § The Ghost Needs Its Own GitHub Identity."
    echo ""
    exit 1
fi
echo ""
echo "${GREEN}  ✓ The pull request was opened by '${PR_AUTHOR}', not by you.${NC}"
echo "${DIM}    Architect and Ghost are distinct GitHub identities, so your${NC}"
echo "${DIM}    approvals will mean something.${NC}"

show_role "$PURPLE" "GHOST" "Atomic Handover into Trinity 1, then the full snapshot."
expect_success "Sync to Trinity 1" git pull origin tos-work-1 || true; git pull origin tos-work-1 --rebase &> /dev/null || true; tos sync trinity 1

show_role "$CYAN" "AGENT" "That snapshot is my whole context. Not memory — verified state."
echo "${DIM}  Note the PHASE= line. The Agent is TOLD which phase it is in. It has${NC}"
echo "${DIM}  no way to work this out from the repository — a refactor changes${NC}"
echo "${DIM}  implementation without changing behaviour, so green and refactor${NC}"
echo "${DIM}  look identical from the outside. Guessing is what we are here to${NC}"
echo "${DIM}  eliminate, so the phase is stored and stated.${NC}"
end_turn

# ==============================================================================
# CHAPTER 4 — SURGICAL CONTEXT INJECTION
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 4 — Surgical Context Injection

The Agent knows what the snapshot told it and nothing more. When it needs to
see a specific file — to reuse a helper rather than reinvent it — you hand it
over deliberately.

This is the opposite of dumping the repository into a context window. You
choose what the Agent sees, one file at a time, and you know exactly what it
had in front of it when it made a decision.

Goal:  Show the Agent an existing utility.
Role:  Principal Architect
Cmd:   tos <project> sync peek <file>
Read:  docs/05-workflow.md § Phase 4
EOF
)"

expect_success "Inject utils.zsh into the Agent's context" tos sync peek utils.zsh

show_role "$CYAN" "AGENT" "I can see log() now. I will use it rather than writing my own."
echo "${DIM}  Peek APPENDS to the outbox. It does not reset the snapshot — run${NC}"
echo "${DIM}  sync trinity again for a clean one.${NC}"
end_turn

# ==============================================================================
# CHAPTER 5 — THE INTENT LOCK
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 5 — The Intent Lock

Here is the most important idea in TOS.

Before the Agent writes a single byte, it must declare exactly which files it
intends to touch. You approve that list. It becomes a visa in the control
plane, and from that moment any payload naming a file outside the list is
rejected before it reaches the sandbox.

Most systems check what an agent did. This checks what it is allowed to do,
in advance. The difference matters: a post-hoc check tells you about the
damage, a visa prevents it.

The visa lives at mode 0700 in the Ghost's directory. You cannot edit it from
your own account. Widening scope means issuing a new plan, deliberately.

Goal:  Declare the blast radius before any code exists.
Role:  Team of Six (Agent)
Cmd:   tos <project> write plan
Read:  docs/04-protocol.md § The Plan Block (The Intent Lock)
       governance/adr.md § The Locked Manifest
EOF
)"

show_role "$CYAN" "AGENT" "First, let us see what happens if I skip the declaration."
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
# CHAPTER 6 — THE RED PHASE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 6 — The Red Phase

A failing test, written before the implementation exists. Standard TDD, with
one addition: the visa from Chapter 5 is active, so we can also watch what
happens when the Agent reaches outside it.

Three refusals in this chapter, each a different class of mistake:

  · a file that is simply not on the approved list
  · a path trying to escape the sandbox entirely
  · a malformed block with no target at all

All three are refused before a single byte reaches the sandbox. At the end we
will check the branch to confirm nothing leaked through.

Goal:  Write the failing test. Then try to write things you should not.
Role:  Team of Six (Agent)
Cmd:   tos <project> write code
Read:  docs/04-protocol.md § The File Block
       docs/06-security.md § The Trust Model
EOF
)"

show_role "$CYAN" "AGENT" "The failing test. test_calculator.zsh is on the visa."
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

show_role "$CYAN" "AGENT" "Now a file that is not on the visa."
load_payload "file_outside_manifest.md"
expect_rejection "SEC-FAULT: rogue.zsh is not authorised by the visa" \
    tos write code

show_role "$CYAN" "AGENT" "Now an attempt to escape the sandbox entirely."
load_payload "file_path_traversal.md"
expect_rejection "SEC-FAULT: path traversal outside the sandbox" \
    tos write code

show_role "$CYAN" "AGENT" "And a malformed block with no target path."
load_payload "file_missing_path.md"
expect_rejection "Malformed FILE block: no target path declared" \
    tos write code

show_role "$YELLOW" "ARCHITECT" "Checking what actually reached the branch:"
git fetch origin
terminal_view "git diff --name-only origin/main...origin/tos-work-1" \
    "$(git diff --name-only origin/main...origin/tos-work-1)"
echo "${GREEN}  ✓ No rogue.zsh. No passwd. Only what the visa allowed.${NC}"
end_turn

# ==============================================================================
# CHAPTER 7 — REVIEW AND ROUTING
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 7 — Review, and the Four Flags

Your turn. You check out the Ghost's branch, read what it wrote, and mark it
up — in the code, on the issue, on the pull request, wherever the remark
belongs.

The Agent reads those marks back out of the snapshot and routes each one by
type, in strict precedence:

  1. [FIXME]      STOP.  Fix it now, via write code.
  2. [CHALLENGE]  STOP.  Defend or adjust the logic before writing anything.
  3. [QUESTION]   INFO.  Answer on the thread, via write comment.
  4. [TODO]       DEFER. Open an issue. Do not fix it now.

TODO is the one that protects you. Deferring REMOVES a topic from this
Trinity instead of quietly widening its scope. That is how a feature stays
one feature.

Note also that the pull request stays the same pull request. It was opened
once by `create trinity` and every phase pushes to it. One issue, one branch,
one feature — the PR is the review channel attached to the branch, not a
counted element.

Goal:  Review as yourself; watch the Agent route each flag correctly.
Role:  Shared
Read:  docs/05-workflow.md § Phase 7
       llm_agents/code.md § 7. Async Review Flags

The pushes below are YOURS. If your remote is SSH with a passphrase you will
be prompted — that is your own pause before touching remote truth, and TOS
does not interfere with it.
EOF
)"

show_role "$YELLOW" "ARCHITECT" "The pull request before review:"
PR_NUMBER=$(gh pr view tos-work-1 --json number -q .number)
COMMITS_BEFORE=$(gh pr view tos-work-1 --json commits -q '.commits | length')
terminal_view "gh pr view" "PR #${PR_NUMBER}, ${COMMITS_BEFORE} commit(s)"

show_role "$YELLOW" "ARCHITECT" "Checking out the Ghost's branch and marking it up."
git checkout tos-work-1
git pull origin tos-work-1

echo "${DIM}  [FIXME] and [CHALLENGE] go inline, where the code is.${NC}"
sed -i 's|log "PASS: add 5 5 = 10"|log "PASS: add 5 5 = 10"\n# [FIXME] No coverage for negative operands. The issue requires them.\n# [CHALLENGE] Why native Zsh math rather than bc?|' test_calculator.zsh
git commit -am "review: architect flags injected inline"
git push origin tos-work-1

echo "${DIM}  [QUESTION] goes on the issue thread.${NC}"
gh issue comment 1 -b "[QUESTION] Should add() accept more than two operands?"

echo "${DIM}  [TODO] goes on the pull request thread.${NC}"
gh pr comment tos-work-1 -b "[TODO] Implement divide() at some point. Not in this Trinity."

show_role "$PURPLE" "GHOST" "Syncing the review into the Agent's context."
expect_success "Regenerate the snapshot with all four flags" git pull origin tos-work-1 || true; git pull origin tos-work-1 --rebase &> /dev/null || true; tos sync trinity 1

show_role "$CYAN" "AGENT" "Four flags. Handling them in precedence order."

show_role "$CYAN" "AGENT" "${BOLD}[1/4 FIXME]${NC} Highest precedence. Fixing now."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Fix: cover negative operands
BODY=Resolves the [FIXME]. Adds assertions for negative operands, as the issue requires.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log \"Running tests...\"
[[ \"\$(add 5 5)\" == \"10\" ]] || exit 1
[[ \"\$(add -3 5)\" == \"2\" ]] || exit 1
[[ \"\$(add -4 -6)\" == \"-10\" ]] || exit 1
log \"PASS: add covers positive and negative operands\"
===TOS_FILE_END==="
expect_success "Resolve the FIXME" tos write code

show_role "$CYAN" "AGENT" "${BOLD}[2/4 CHALLENGE]${NC} Defend the logic. No code."
write_inbox "===TOS_COMMENT_START===
TARGET=tos-work-1
BODY=**[DEFENCE on test_calculator.zsh]**: Native Zsh arithmetic avoids a subshell and an external binary per assertion. For a suite that runs on every commit the difference is material, and bc adds a runtime dependency the project does not otherwise need.
===TOS_COMMENT_END==="
expect_success "Answer the CHALLENGE" tos write comment

show_role "$CYAN" "AGENT" "${BOLD}[3/4 QUESTION]${NC} Informational. Answer on the thread."
write_inbox "===TOS_COMMENT_START===
TARGET=1
BODY=**[ANSWER]**: No. Issue #1 specifies a binary add(). Variadic operands would be a scope change and belong in their own Trinity.
===TOS_COMMENT_END==="
expect_success "Answer the QUESTION" tos write comment

show_role "$CYAN" "AGENT" "${BOLD}[4/4 TODO]${NC} Defer. This is how scope creep is refused."
write_inbox "===TOS_ISSUE_START===
TITLE=Implement divide()
BODY=Deferred from the Trinity 1 review thread. Out of scope for issue #1.
===TOS_ISSUE_END==="
expect_success "Defer the TODO to a new Trinity" tos write issue

show_role "$YELLOW" "ARCHITECT" "The pull request after two of my pushes and one of the Ghost's:"
PR_AFTER=$(gh pr view tos-work-1 --json number -q .number)
COMMITS_AFTER=$(gh pr view tos-work-1 --json commits -q '.commits | length')
OPEN_PRS=$(gh pr list --state open --json number -q 'length')
terminal_view "PR identity" \
"before : PR #${PR_NUMBER}, ${COMMITS_BEFORE} commit(s)
after  : PR #${PR_AFTER}, ${COMMITS_AFTER} commit(s)
open PRs on this repo: ${OPEN_PRS}"

if [[ "$PR_NUMBER" == "$PR_AFTER" && "$OPEN_PRS" -eq 1 ]]; then
    echo "${GREEN}  ✓ Same PR, more commits. The branch is the counted element.${NC}"
else
    echo "${RED}  ✗ Unexpected: the PR changed or another was opened.${NC}"
    exit 1
fi
end_turn

# ==============================================================================
# CHAPTER 8 — THE PHASE GATE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 8 — The Phase Gate

The Red work is done and reviewed. To move to Green, you approve.

Not a comment, not a nod in chat — an approving review on the pull request,
carrying a tag that names both ends of the transition:

    gh pr review tos-work-1 --approve --body "[PHASE:RED->GREEN] ..."

The Ghost then applies it with `write phase`, and only after re-deriving the
entire record from GitHub. Eight invariants, every time, with no fast path:
the review must still exist on this PR, its source must match the current
phase, the verdict must match, it must be newer than the last transition, its
commit must still be in the branch, and its author must not be the Ghost.

The gate is FORWARD-ONLY. One step at a time, never backwards, never
skipping. If the work is wrong, you do not retreat a phase — you abandon the
Trinity with `close trinity`, which returns the issue to the backlog, and you
start again with what you learned. That is a cleaner signal than a Trinity
that has been dragged back and forth until nobody knows what was approved.

We will try three wrong moves before the right one.

Goal:  Advance red → green, and watch the gate refuse everything else.
Role:  Principal Architect
Cmd:   tos <project> write phase
Read:  governance/adr.md § The Phase Gate
EOF
)"

show_role "$YELLOW" "ARCHITECT" "First: trying to go backwards."
gh pr review tos-work-1 --request-changes --body "[PHASE:RED->RED] going nowhere" || true
expect_rejection "The gate is forward-only — it never retreats" \
    tos write phase

show_role "$YELLOW" "ARCHITECT" "Second: trying to skip Green entirely."
gh pr review tos-work-1 --approve --body "[PHASE:RED->REFACTOR] straight to cleanup" || true
expect_rejection "The gate advances exactly one step — no skipping" \
    tos write phase

show_role "$YELLOW" "ARCHITECT" "Third: the right direction, but requesting changes rather than approving."
gh pr review tos-work-1 --request-changes --body "[PHASE:RED->GREEN] not convinced yet" || true
expect_rejection "A transition requires an approval, not a change request" \
    tos write phase

echo ""
echo "${DIM}  That third one is worth pausing on. The tag was correct and the${NC}"
echo "${DIM}  direction was correct — only the verdict disagreed. Two independent${NC}"
echo "${DIM}  expressions of the same intent, cross-checked. Neither alone would${NC}"
echo "${DIM}  have caught it.${NC}"

advance_phase red green "Test contract agreed. Negative operands covered."

show_role "$CYAN" "AGENT" "I am in Green now, and I know it because I was told."
end_turn

# ==============================================================================
# CHAPTER 9 — THE GREEN PHASE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 9 — The Green Phase

The minimum implementation that turns the test green. No speculative
abstraction, no extra features, nothing the test does not demand.

The visa from Chapter 5 is still active and still lists calculator.zsh, so
this passes. Anything else would not.

Goal:  Make the failing test pass.
Role:  Team of Six (Agent)
Cmd:   tos <project> write code
Read:  docs/05-workflow.md § Phase 8
EOF
)"

show_role "$PURPLE" "GHOST" "Re-syncing so the sandbox carries the review commit."
expect_success "Sync before writing" git pull origin tos-work-1 || true; git pull origin tos-work-1 --rebase &> /dev/null || true; tos sync trinity 1

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
# CHAPTER 10 — THE ENFORCEMENT SURFACE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 10 — The Enforcement Surface

A short detour to show the remaining guards together.

These exist because the Agent is treated as hostile input. Not because it is
malicious — because it has no grounding in the actual system state and may be
confidently wrong. Every declaration it makes is cross-referenced against
ground truth before anything happens.

  · Hallucination perimeter   a payload naming the wrong project or a stale
                              trinity is rejected at the gateway
  · Exact-once execution      the inbox is consumed before any network call,
                              so a retry cannot double-commit
  · The phase gate on merge   `write trinity` refuses outside Retrospect

That last one matters most. It is the reason a feature cannot be merged with
its Retrospective skipped.

Goal:  Watch the last line of defence do its job.
Role:  The Gateway
Read:  docs/06-security.md § The Trust Model
       governance/adr.md § Exact-Once Execution
EOF
)"

show_role "$CYAN" "AGENT" "Declaring the wrong project — classic context drift."
load_payload "meta_wrong_project.md"
expect_rejection "Hallucination: payload targets a different project" \
    tos write code

show_role "$CYAN" "AGENT" "Declaring a trinity that is not the active one."
load_payload "meta_wrong_trinity.md"
expect_rejection "Hallucination: payload targets trinity 99" \
    tos write code

show_role "$PURPLE" "GHOST" "Exact-once execution — watch the inbox size."
write_inbox "===TOS_ISSUE_START===
TITLE=Exactly-once demonstration
BODY=This issue is created once. The payload is then gone.
===TOS_ISSUE_END==="
echo "${DIM}  inbox before: $(wc -c < "$TOS_INPUT") bytes${NC}"
expect_success "Consume the payload" tos write issue
echo ""
echo "${DIM}  inbox after:  $(wc -c < "$TOS_INPUT") bytes${NC}"
echo "${GREEN}  ✓ Truncated to zero before any network call. A retry cannot${NC}"
echo "${GREEN}    double-create; you must deliberately resubmit.${NC}"

expect_rejection "Resubmitting: there is nothing left to execute" \
    tos write issue

show_role "$YELLOW" "ARCHITECT" "And trying to merge while still in Green."
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=calculator.zsh test_calculator.zsh
===TOS_TRINITY_END==="
expect_rejection "write trinity refuses outside Retrospect" \
    tos write trinity
echo "${DIM}  The Retrospective cannot be skipped by forgetting it.${NC}"
end_turn

# ==============================================================================
# CHAPTER 11 — REFACTOR
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 11 — Refactor

Green means it works. Refactor means it is worth keeping.

Two things happen here. First you approve the Green work and the phase
advances. Then the Agent discovers that documentation is outside its visa —
because it is — and has to declare a new plan before it can touch README.md.

Note that re-issuing a plan REPLACES the old visa rather than adding to it.
The approved blast radius is whatever the most recent plan says, entire.

Goal:  Advance to Refactor, widen the visa, clean up.
Role:  Shared
Cmds:  tos <project> write phase
       tos <project> write plan
       tos <project> write code
Read:  docs/05-workflow.md § Phase 9
EOF
)"

advance_phase green refactor "Implementation satisfies the contract. Tests pass."

show_role "$CYAN" "AGENT" "Documentation is outside my current visa. Re-declaring."
write_inbox "===TOS_PLAN_START===
APPROVED_FILES=calculator.zsh test_calculator.zsh README.md docs/learnings.md
===TOS_PLAN_END==="
expect_success "Widen the Intent Lock" tos write plan

show_role "$CYAN" "AGENT" "Adding a docstring and documenting usage."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Refactor: document add()
BODY=Adds a docstring and documents usage in the README. No behaviour change.
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
===TOS_FILE_END==="
expect_success "Commit the refactor" tos write code
end_turn

# ==============================================================================
# CHAPTER 12 — THE RETROSPECTIVE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 12 — The Retrospective

The phase most teams skip, made mandatory by the gate.

During this Trinity the Agent learned things it had to infer: that this
project prefers native Zsh arithmetic, that operand counts should be checked.
Those decisions currently exist only in a pull request thread that nobody
will read again.

The Retrospective writes them into the repository. Not because documentation
is virtuous, but because the next Trinity starts from a Clean Room Snapshot —
and a rule written down is a rule the next Agent is told, rather than one it
has to rediscover or violate.

This is how the system gets better without anyone retraining a model.

Goal:  Advance to Retrospect and record what was learned.
Role:  Team of Six (Agent)
Read:  docs/08-agentic-unleash.md § High-Fidelity Pair Programming
EOF
)"

advance_phase refactor retrospect "Clean, documented, no behaviour change."

show_role "$CYAN" "AGENT" "Recording the domain rules discovered in this Trinity."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Retrospective: record session learnings
BODY=Encodes two domain rules discovered during this Trinity so the next one starts with them.
===TOS_META_END===
===TOS_FILE_START: docs/learnings.md===
# Domain Rules

1. Use native Zsh arithmetic. Do not shell out to \`bc\`.
2. Validate operand count before evaluating any arithmetic block.
===TOS_FILE_END==="
expect_success "Commit the retrospective" tos write code
end_turn

# ==============================================================================
# CHAPTER 13 — CLOSURE
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 13 — Closure

One last gate before the merge, and it is a strange one: the Agent must prove
it knows what it did.

The MANIFEST it declares has to match `git diff --name-only origin/main...HEAD`
exactly. A file forgotten, or one claimed but never changed, aborts the merge
as a context hallucination.

The Intent Lock was prospective — what the Agent may do. This is
retrospective — what it actually did. And the Agent is forbidden from
guessing: you supply the verified list, from the real diff.

We will submit a deliberately incomplete one first.

Goal:  Prove the Agent's model matches reality, then merge.
Role:  Principal Architect
Cmd:   tos <project> write trinity
Read:  docs/04-protocol.md § The Trinity Block (Closure MANIFEST)
EOF
)"

show_role "$YELLOW" "ARCHITECT" "Pulling the Ghost's work and running the tests myself."
git fetch origin
git pull --ff-only origin tos-work-1
if zsh ./test_calculator.zsh; then
    echo "${GREEN}✅ Local tests passed.${NC}"
else
    echo "${RED}❌ Local tests failed — halting before merge.${NC}"
    exit 1
fi

show_role "$PURPLE" "GHOST" "Re-syncing so the sandbox diff matches mine."
expect_success "Final sync before closure" git pull origin tos-work-1 || true; git pull origin tos-work-1 --rebase &> /dev/null || true; tos sync trinity 1

show_role "$YELLOW" "ARCHITECT" "Computing the verified MANIFEST from the real diff."
MANIFEST_FILES="$(git diff --name-only origin/main...HEAD | tr '\n' ' ' | sed 's/ *$//')"
terminal_view "git diff --name-only origin/main...HEAD" "$MANIFEST_FILES"

show_role "$CYAN" "AGENT" "First, omitting a file on purpose."
INCOMPLETE="$(echo "$MANIFEST_FILES" | awk '{$NF=""; print}' | sed 's/ *$//')"
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=$INCOMPLETE
===TOS_TRINITY_END==="
terminal_view "inbox.md (incomplete on purpose)" "$(cat "$TOS_INPUT")"

expect_rejection "CONTEXT HALLUCINATION: the manifest omits a changed file" \
    tos write trinity

show_role "$YELLOW" "ARCHITECT" "Now the complete, verified declaration."
write_inbox "===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=$MANIFEST_FILES
===TOS_TRINITY_END==="

expect_success "Finalize the Trinity" tos write trinity

show_role "$YELLOW" "ARCHITECT" "Cleaning up my local branch."
git checkout main
git pull origin main
git branch -D tos-work-1 2>/dev/null || true

terminal_view "gh issue view 1" "$(gh issue view 1 | grep -i state || true)"
end_turn

# ==============================================================================
# CHAPTER 14 — TEARDOWN
# ==============================================================================
present_chapter "$(cat <<'EOF'
# Chapter 14 — Teardown, and the Destructive Gate

One safeguard left, and it guards the operations you would most regret.

Every close and delete requires the literal string CONFIRM=TRUE in the
payload. The gateway checks for it before evaluating any other logic — before
parsing, before touching anything.

The point is that an Agent cannot produce it by drift. The string has no
plausible role in any non-destructive operation, so it cannot appear by
accident, by pattern-matching, or by a stale context suggesting it. It has to
be written on purpose.

Goal:  Remove the Ghost's sandbox. The remote survives untouched.
Role:  Principal Architect
Cmd:   tos <project> close project
Read:  docs/06-security.md § The HITL Destructive Gate
EOF
)"

show_role "$CYAN" "AGENT" "Requesting teardown without the confirmation string."
write_inbox "===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=0
TITLE=Close project
BODY=No confirmation string present.
===TOS_META_END==="
terminal_view "inbox.md (no CONFIRM)" "$(cat "$TOS_INPUT")"

expect_rejection "Destructive gate: CONFIRM=TRUE is absent" \
    tos close project

show_role "$YELLOW" "ARCHITECT" "Confirming the sandbox survived:"
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

clear
echo "${BLUE}================================================================================${NC}"
cat <<'EOF'
  _______                    ____   __   _____ _      
 |__   __|                  / __ \ / _| / ____(_)     
    | | ___  __ _ _ __ ___  | |  | | |_ | (___  ___  __
    | |/ _ \/ _` | '_ ` _ \ | |  | |  _| \___ \| \ \/ /
    | |  __/ (_| | | | | | || |__| | |  ____) | |>  < 
    |_|\___|\_,_|_| |_| |_| \____/|_|  |_____/|_/_/\_\
EOF
echo "${BLUE}================================================================================${NC}"
echo ""
echo "${GREEN}${BOLD}  🏁 Done. One feature, built and merged.${NC}"
echo ""
echo "  ${BOLD}What you watched the engine refuse:${NC}"
echo ""
echo "    Typo Guard, uninitialized directory              Chapter 0"
echo "    write code inside the Trinity 0 sanctuary        Chapter 2"
echo "    write code with no Intent Lock                   Chapter 5"
echo "    a rogue file, a traversal, a malformed block     Chapter 6"
echo "    a backward phase, a skipped phase, no approval   Chapter 8"
echo "    the wrong project, a stale trinity, a replay     Chapter 10"
echo "    a merge with the Retrospective skipped           Chapter 10"
echo "    a MANIFEST that did not match the diff           Chapter 13"
echo "    a teardown without CONFIRM=TRUE                  Chapter 14"
echo ""
echo "  ${BOLD}Not demonstrated:${NC} lock exclusivity between two Architects. It needs a"
echo "  second system user, and simulating it would have meant faking the very"
echo "  thing under test. See docs/06-security.md § Multi-Tenant Operation."
echo ""
echo "  ${BOLD}Where to go next:${NC}"
echo "    docs/00-llm-pitfalls.md    why any of this is necessary"
echo "    docs/03-trinity.md         the Trinity in depth"
echo "    docs/07-neovim-plugin.md   removing the last manual steps"
echo ""
echo "  Repository:  ${BOLD}https://github.com/${GH_LOGIN}/${TEST_REPO}${NC}"
echo "  Working copy: ${BOLD}${WORKDIR}/${TEST_REPO}${NC}"
echo ""
echo "  To purge both: ${BOLD}./inf/post_test_cleanup.zsh${NC}"
echo ""
