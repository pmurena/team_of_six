#!/bin/zsh
# ==============================================================================
# Team of Six - The Contextual Trinity Interactive Tutorial & Integration Test
# ==============================================================================

set -e

# --- 1. ZSH FORCE (The Handover) ---
if [ -z "$ZSH_VERSION" ]; then
    exec zsh "$0" "$@"
fi

# --- 2. Configuration & Validation ---
source "$(cd "$(dirname "$0")/../conf" && pwd)/config"
TEST_REPO="tos-trinity-test-$(date +%s)"
TOS_BIN="$TOS_MNT_ROOT/.local/bin/tos"

# --- 3. UI Engine (No background colors for maximum readability) ---
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[1;36m'   # Team_of_Six (Agent)
YELLOW='\033[1;33m' # Principal Architect (Human)
PURPLE='\033[1;35m' # The Ghost (System)
BLUE='\033[1;34m'   # Git / Remote Truth
GREEN='\033[1;32m'

function present_chapter() {
    clear
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "$1"
    echo -e "${BLUE}================================================================================${NC}\n"
    echo -ne "${YELLOW}🚀 Press [Enter] to initiate this turn, or [Ctrl+C] to abort... ${NC}"
    read -r
}

function show_role() {
    local color=$1; local role=$2; local text=$3
    echo -e "\n${BOLD}${color}[$role]${NC} $text"
}

function terminal_view() {
    echo -e "${DIM}┌─[ $1 ]───────────────────────────────────────────────────────────────────${NC}"
    echo "$2" | sed 's/^/│ /'
    echo -e "${DIM}└──────────────────────────────────────────────────────────────────────────${NC}"
}

# ==============================================================================
# INTRODUCTION: THE PHILOSOPHY OF THE CONTEXTUAL TRINITY
# ==============================================================================
INTRO=$(cat << 'EOF'
# The Philosophy of the Contextual Trinity

In standard AI development, LLMs fail because they operate in a vacuum, losing 
track of file state or hallucinating structures. We fix this by hard-coding a 
context window that cannot drift: **The Contextual Trinity (1:1:1).**

1.  **1 Issue (The Required Context):** The ONLY source of truth for what is built.
2.  **1 PR (The Active Context):** The ONLY isolated space where code changes.
3.  **1 Feature (The Cognitive Context):** The ONLY logic the Agent processes.

We believe this works because it transforms the LLM from an autonomous wanderer 
into a "Typewriter" bound by the Architect's wisdom and the Ghost's bridge.
EOF
)
present_chapter "$INTRO"

# ==============================================================================
# CHAPTER 0: THE GENESIS
# ==============================================================================
CH0=$(cat << 'EOF'
# Chapter 0: The Genesis (Establishing Remote Truth)

Goal: Create the "Remote Truth" that the Ghost will mirror.
Role: Principal Architect (Wisdom)
EOF
)
present_chapter "$CH0"

show_role "$YELLOW" "ARCHITECT" "Initializing repository and core framework files..."
mkdir -p "$TEST_REPO" && cd "$TEST_REPO"
git init -q
echo "# TOS Tutorial" > README.md
echo "log() { echo \"[LOG] \$1\"; }" > utils.zsh
mkdir llm_agents && echo "Rule 1: Use native Zsh math." > llm_agents/team_of_six.md
git add . && git commit -m "Initial commit" -q

show_role "$BLUE" "REMOTE" "Pushing to GitHub..."
gh repo create "$TEST_REPO" --private --source=. --remote=origin --push >/dev/null

terminal_view "tree -a" "$(tree -a -I .git)"
show_role "$PURPLE" "GHOST" "The Remote Truth is established. I am ready to mirror."

# ==============================================================================
# CHAPTER 1: PROVISIONING THE SANDBOX
# ==============================================================================
CH1=$(cat << 'EOF'
# Chapter 1: Provisioning the Sandbox (The Air-Gap)

Goal: Clone the Remote Truth into the Ghost's secure, locked environment.
Role: The Ghost (System Bridge)
EOF
)
present_chapter "$CH1"

show_role "$PURPLE" "GHOST" "Executing: tos work start"
"$TOS_BIN" "$TEST_REPO" work start

show_role "$PURPLE" "GHOST" "Sandbox established. Checking IPC Ribbon state..."
terminal_view "ls -l $TOS_IPC" "$(ls -l "$TOS_INPUT" "$TOS_CONTEXT")"
show_role "$PURPLE" "GHOST" "Inbox and Outbox are clean. The ribbon is ready."

# ==============================================================================
# CHAPTER 2: STAGE 1 — SCOPING THE TRINITY
# ==============================================================================
CH2=$(cat << 'EOF'
# Chapter 2: Scoping (The Trinity Mandate)

Goal: Break features into atomic issues to prevent LLM cognitive collapse.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH2"

show_role "$CYAN" "AGENT" "I am scoping the project. I will propose two distinct tickets."
PAYLOAD=$(cat << 'EOF'
===TOS_ISSUE_START===
TITLE=Implement add() function
BODY=Implement math logic in calculator.zsh.
===TOS_ISSUE_END===
===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Deferred to next trinity turn.
===TOS_ISSUE_END===
EOF
)
echo "$PAYLOAD" > "$TOS_INPUT"

show_role "$YELLOW" "ARCHITECT" "Reviewing scoping payload in Inbox..."
terminal_view "cat inbox.md" "$PAYLOAD"

show_role "$PURPLE" "GHOST" "Executing: tos work new"
"$TOS_BIN" "$TEST_REPO" work new >/dev/null

show_role "$YELLOW" "ARCHITECT" "Verifying Remote Truth via GitHub CLI..."
terminal_view "gh issue list" "$(gh issue list)"

# ==============================================================================
# CHAPTER 3: OPENING THE WORKSPACE (SIGNATURE MAP)
# ==============================================================================
CH3=$(cat << 'EOF'
# Chapter 3: Opening the Workspace

Goal: Anchor the Agent to a single branch and provide a "Truth Map."
Role: The Ghost (System Bridge)
EOF
)
present_chapter "$CH3"

show_role "$PURPLE" "GHOST" "Executing: tos work 1"
"$TOS_BIN" "$TEST_REPO" work 1 >/dev/null

show_role "$PURPLE" "GHOST" "Context generated. Providing CTags-based Signature Map..."
terminal_view "tail -n 15 outbox.md" "$(tail -n 15 "$TOS_CONTEXT")"

# ==============================================================================
# CHAPTER 4: SURGICAL CONTEXT INJECTION (PEEK)
# ==============================================================================
CH4=$(cat << 'EOF'
# Chapter 4: Surgical Context Injection (Peek)

Goal: Feed the Agent's context window precisely with existing utilities.
Role: Principal Architect (Wisdom)
EOF
)
present_chapter "$CH4"

show_role "$YELLOW" "ARCHITECT" "Executing: tos work peek utils.zsh"
"$TOS_BIN" "$TEST_REPO" work peek utils.zsh >/dev/null

show_role "$CYAN" "AGENT" "My context has been updated. I can now 'see' the log() function."
terminal_view "grep -A 5 'PEEK' outbox.md" "$(grep -A 5 "## SURGICAL CONTEXT INJECTION (PEEK)" "$TOS_CONTEXT")"

# ==============================================================================
# CHAPTER 5: STAGE 2 — THE RED PHASE (5-3-2 STRATEGY)
# ==============================================================================
CH5=$(cat << 'EOF'
# Chapter 5: The Red Phase

Goal: Enforce TDD using the 5-3-2 Test Strategy (5 Unit, 3 Int, 2 E2E).
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH5"

show_role "$CYAN" "AGENT" "Writing the failing test turn. I am following the 5-3-2 strategy."
PAYLOAD_RED=$(cat << 'EOF'
===TOS_META_START===
TITLE=Red: failing test for add()
BODY=Initial test suite using native zsh and utils.zsh.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log "Running tests..."
[[ "$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_RED" > "$TOS_INPUT"

show_role "$PURPLE" "GHOST" "Executing: tos write code"
"$TOS_BIN" "$TEST_REPO" write code >/dev/null

show_role "$YELLOW" "ARCHITECT" "Reviewing the Agent's PR diff..."
terminal_view "git diff origin/main...HEAD" "$(git diff origin/main...HEAD --color=always)"

# ==============================================================================
# CHAPTER 6: ASYNC REVIEW & ROUTING
# ==============================================================================
CH6=$(cat << 'EOF'
# Chapter 6: Review & Ghost Routing

Goal: Architect intervenes with Wisdom; Agent routes feedback via Trinity.
Role: Shared (Architect Tags -> Agent Routes)
EOF
)
present_chapter "$CH6"

show_role "$YELLOW" "ARCHITECT" "Checking out Ghost PR branch and injecting tags..."
git fetch origin -q
git checkout tos-work-1 -q
gh issue comment 1 -b "[QUESTION] Support negative numbers?" >/dev/null
sed -i 's/add 5 5/add 5 5 # [FIXME] logic missing/' test_calculator.zsh
echo "# [TODO] Implement divide() later." >> README.md
git commit -am "Architect review" -q && git push origin tos-work-1 -q

show_role "$PURPLE" "GHOST" "Syncing tags back to Agent context..."
"$TOS_BIN" "$TEST_REPO" work 1 >/dev/null

show_role "$CYAN" "AGENT" "Tags detected. I will output a COMMENT payload first to answer the question."
PAYLOAD_COMMENT=$(cat << 'EOF'
===TOS_COMMENT_START===
TARGET=1
BODY=**[QUESTION]**: Negative numbers are supported by native shell math.
===TOS_COMMENT_END===
EOF
)
echo "$PAYLOAD_COMMENT" > "$TOS_INPUT"
"$TOS_BIN" "$TEST_REPO" write comment >/dev/null

show_role "$YELLOW" "ARCHITECT" "Notice the Engine wiped the Inbox after executing the comment. This prevents double-posting!"
show_role "$CYAN" "AGENT" "Now outputting the ISSUE payload for the deferred task."
PAYLOAD_ISSUE=$(cat << 'EOF'
===TOS_ISSUE_START===
TITLE=Implement divide()
BODY=Deferred from PR #1 feedback.
===TOS_ISSUE_END===
EOF
)
echo "$PAYLOAD_ISSUE" > "$TOS_INPUT"
"$TOS_BIN" "$TEST_REPO" work new >/dev/null

show_role "$YELLOW" "ARCHITECT" "Verified. Comment posted and Issue #3 created safely in two stages."

# ==============================================================================
# CHAPTER 7: THE GREEN PHASE
# ==============================================================================
CH7=$(cat << 'EOF'
# Chapter 7: The Green Phase (Completion)

Goal: Reach functional implementation and pass tests.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH7"

show_role "$CYAN" "AGENT" "Implementing calculator.zsh logic to fix the failing test."
PAYLOAD_GREEN=$(cat << 'EOF'
===TOS_META_START===
TITLE=Green: implement add()
BODY=Resolved [FIXME] and added implementation. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_GREEN" > "$TOS_INPUT"
"$TOS_BIN" "$TEST_REPO" write code >/dev/null

show_role "$YELLOW" "ARCHITECT" "The diff is clean. The implementation matches the 'Wisdom'."

# ==============================================================================
# CHAPTER 8: STAGE 5 — REFACTOR & DOCS
# ==============================================================================
CH8=$(cat << 'EOF'
# Chapter 8: Refactor Phase

Goal: Clean up implementation and self-document before merging.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH8"

show_role "$CYAN" "AGENT" "Refactoring and adding docstrings to calculator.zsh."
PAYLOAD_REFACTOR=$(cat << 'EOF'
===TOS_META_START===
TITLE=Docs: add docstrings to add()
BODY=Refactored syntax and documented standard usage constraints.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
# Adds two integers using native Zsh math
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_REFACTOR" > "$TOS_INPUT"
"$TOS_BIN" "$TEST_REPO" write code >/dev/null

show_role "$YELLOW" "ARCHITECT" "Reviewing updated code..."
terminal_view "cat calculator.zsh" "$(cat calculator.zsh)"

# ==============================================================================
# CHAPTER 9: STAGE 6 — RETROSPECTIVE
# ==============================================================================
CH9=$(cat << 'EOF'
# Chapter 9: The Retrospective

Goal: The Agent updates its own system prompts based on session learnings.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH9"

show_role "$CYAN" "AGENT" "Proposing rules based on Architect's manual math injection..."
PAYLOAD_RETRO=$(cat << 'EOF'
===TOS_META_START===
TITLE=Retro: Enforce parameter validation
BODY=Update agent rules to always check param length before Zsh math evaluation.
===TOS_META_END===
===TOS_FILE_START: llm_agents/team_of_six.md===
Rule 1: Use native Zsh math.
Rule 2: Check integer count before math blocks.
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_RETRO" > "$TOS_INPUT"
"$TOS_BIN" "$TEST_REPO" write code >/dev/null
show_role "$YELLOW" "ARCHITECT" "Agent constraints evolved and committed."

# ==============================================================================
# CHAPTER 10: MERGE & TEARDOWN
# ==============================================================================
CH10=$(cat << 'EOF'
# Chapter 10: The Closure

Goal: Final verification, merge, and transcript preservation.
Role: Principal Architect (Wisdom)
EOF
)
present_chapter "$CH10"

show_role "$YELLOW" "ARCHITECT" "Pulling Ghost work and running final local tests..."
git pull origin tos-work-1 -q
zsh ./test_calculator.zsh && echo -e "${GREEN}✅ Local tests passed.${NC}"

show_role "$YELLOW" "ARCHITECT" "Merging PR and cleaning the sandbox."
gh pr merge -m -d >/dev/null
sudo rm -rf "$TOS_SANDBOX/$TEST_REPO" # Cleaning Ghost's chamber

show_role "$PURPLE" "GHOST" "Session closed. The Trinity is complete."
terminal_view "ls -R" "$(ls -R)"
