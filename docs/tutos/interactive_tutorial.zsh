#!/bin/zsh
# ==============================================================================
# Team of Six - The Contextual Trinity Interactive Tutorial & Integration Test
# ==============================================================================

set -e

if [ -z "$ZSH_VERSION" ]; then
    exec zsh "$0" "$@"
fi

# --- Configuration & Validation ---
source "$(cd "$(dirname "$0")/../conf" && pwd)/config"
TEST_REPO="tos-trinity-test-$(date +%s)"
TOS_BIN_CMD="$TOS_MNT_ROOT/.local/bin/tos.zsh"

# Tutorial runs as the Architect ($USER), so we map IPC paths directly.
export TOS_IPC="$TOS_MNT_ROOT/.ipc/$USER"
export TOS_INPUT="$TOS_IPC/inbox.md"
export TOS_CONTEXT="$TOS_IPC/outbox.md"
export TOS_SANDBOX="$TOS_MNT_ROOT/sandbox/$USER"

# --- UI Engine ---
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
BLUE='\033[1;34m'
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

function end_turn() {
    echo -ne "\n${YELLOW}🛑 Execution complete. Press [Enter] to proceed to the next chapter... ${NC}"
    read -r
}

# ==============================================================================
# INTRODUCTION
# ==============================================================================
INTRO=$(cat << 'EOF'
  _______                    ____   __   _____ _      
 |__   __|                  / __ \ / _| / ____(_)     
    | | ___  __ _ _ __ ___  | |  | | |_ | (___  ___  __
    | |/ _ \/ _` | '_ ` _ \ | |  | |  _| \___ \| \ \/ /
    | |  __/ (_| | | | | | || |__| | |  ____) | |>  < 
    |_|\___|\_,_|_| |_| |_| \____/|_|  |_____/|_/_/\_\

# The Philosophy of the Contextual Trinity

In standard AI development, LLMs fail because they operate in a vacuum, losing 
track of file state or hallucinating structures. We fix this by hard-coding a 
context window that cannot drift: **The Contextual Trinity (1:1:1).**

1.  **1 Issue (The Required Context):** The ONLY source of truth for what is built.
2.  **1 PR (The Active Context):** The ONLY isolated space where code changes.
3.  **1 Feature (The Cognitive Context):** The ONLY logic the Agent processes.

The Engine enforces this through a global project:trinity lock and payload-level
hallucination control — the Ghost must declare TARGET_PROJECT and TARGET_TRINITY
in every mutation payload, and the gateway rejects any mismatch.
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
git add . && git commit -m "Initial commit" -q
git branch -M main

show_role "$BLUE" "REMOTE" "Pushing to GitHub..."
gh repo create "$TEST_REPO" --private --source=. --remote=origin --push >/dev/null

terminal_view "tree -a" "$(tree -a -I .git)"
show_role "$PURPLE" "GHOST" "The Remote Truth is established. I am ready to mirror."
end_turn

# ==============================================================================
# CHAPTER 1: PROVISIONING THE SANDBOX
# ==============================================================================
CH1=$(cat << 'EOF'
# Chapter 1: Provisioning the Sandbox (The Air-Gap)

Goal: Clone the Remote Truth into the Ghost's secure, locked environment.
Role: The Ghost (System Bridge)
New path: sandbox/$USER/<project>  — no tos_home nesting.
EOF
)
present_chapter "$CH1"

show_role "$PURPLE" "GHOST" "Executing: tos sync start"
"$TOS_BIN_CMD" "$TEST_REPO" sync start

show_role "$PURPLE" "GHOST" "Sandbox established. Checking global IPC ribbon state..."
terminal_view "ls -l $TOS_IPC" "$(ls -l "$TOS_INPUT" "$TOS_CONTEXT")"
show_role "$PURPLE" "GHOST" "Inbox and Outbox are clean. Trinity 0 Soft-Lock acquired. The ribbon is ready."
end_turn

# ==============================================================================
# CHAPTER 2: SCOPING THE TRINITY
# ==============================================================================
CH2=$(cat << 'EOF'
# Chapter 2: Scoping (The Trinity Mandate)

Goal: Break features into atomic issues to prevent LLM cognitive collapse.
Role: Team_of_Six (Agent / Doer)
Command: tos write issue
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

show_role "$PURPLE" "GHOST" "Executing: tos write issue"
"$TOS_BIN_CMD" "$TEST_REPO" write issue

show_role "$YELLOW" "ARCHITECT" "Verifying Remote Truth via GitHub CLI..."
terminal_view "gh issue list" "$(gh issue list)"
end_turn

# ==============================================================================
# CHAPTER 3: OPENING THE WORKSPACE (TRINITY SYNC)
# ==============================================================================
CH3=$(cat << 'EOF'
# Chapter 3: Opening the Workspace

Goal: Acquire the trinity lock and generate the full context map.
Role: The Ghost (System Bridge)
Command: tos sync trinity <ID>
EOF
)
present_chapter "$CH3"

show_role "$PURPLE" "GHOST" "Executing: tos sync trinity 1"
"$TOS_BIN_CMD" "$TEST_REPO" sync trinity 1

show_role "$PURPLE" "GHOST" "Context and lock acquired. Checking Signature Map..."
terminal_view "tail -n 15 outbox.md" "$(tail -n 15 "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 4: SURGICAL CONTEXT INJECTION (PEEK)
# ==============================================================================
CH4=$(cat << 'EOF'
# Chapter 4: Surgical Context Injection (Peek)

Goal: Feed the Agent's context window precisely with existing utilities.
Role: Principal Architect (Wisdom)
Command: tos sync peek <file>
EOF
)
present_chapter "$CH4"

show_role "$YELLOW" "ARCHITECT" "Executing: tos sync peek utils.zsh"
"$TOS_BIN_CMD" "$TEST_REPO" sync peek utils.zsh

show_role "$CYAN" "AGENT" "My context has been updated. I can now 'see' the log() function."
terminal_view "cat "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 5: THE RED PHASE
# ==============================================================================
CH5=$(cat << 'EOF'
# Chapter 5: The Red Phase

Goal: Enforce TDD using the 5-3-2 Test Strategy (5 Unit, 3 Int, 2 E2E).
Role: Team_of_Six (Agent / Doer)
Note: Payload now includes TARGET_PROJECT + TARGET_TRINITY for hallucination control.
EOF
)
present_chapter "$CH5"

show_role "$CYAN" "AGENT" "Writing the failing test. Payload declares TARGET_PROJECT and TARGET_TRINITY."
PAYLOAD_RED=$(cat << EOF
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Initial test suite using native zsh and utils.zsh.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log "Running tests..."
[[ "\$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_RED" > "$TOS_INPUT"

show_role "$PURPLE" "GHOST" "Executing: tos write code (with hallucination control check)"
"$TOS_BIN_CMD" "$TEST_REPO" write code

show_role "$YELLOW" "ARCHITECT" "Fetching Ghost's commits and verifying the diff..."
git fetch origin -q
terminal_view "git diff origin/main...origin/tos-work-1" "$(git diff origin/main...origin/tos-work-1 --color=always)"
end_turn

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

show_role "$YELLOW" "ARCHITECT" "Checking out Ghost PR branch and injecting review tags..."
git checkout tos-work-1 -q

gh issue comment 1 -b "[QUESTION] Should we support negative numbers?" >/dev/null
sed -i 's/exit 1/exit 1 # [FIXME] logic missing/' test_calculator.zsh
sed -i 's/log "Running tests..."/log "Running tests..." # [CHALLENGE] Why use native Zsh math instead of bc?/' test_calculator.zsh
echo "# [TODO] Implement divide() later." >> README.md

git commit -am "Architect review: tags injected inline" -q && git push origin tos-work-1 -q

show_role "$PURPLE" "GHOST" "Syncing tags back to Agent context..."
"$TOS_BIN_CMD" "$TEST_REPO" sync trinity 1 >/dev/null

show_role "$CYAN" "AGENT" "Tags detected. Outputting COMMENT payloads for QUESTION and CHALLENGE."
PAYLOAD_COMMENTS=$(cat << 'EOF'
===TOS_COMMENT_START===
TARGET=1
BODY=**[ANSWER]**: Yes, negative numbers are fully supported by standard shell arithmetic.
===TOS_COMMENT_END===
===TOS_COMMENT_START===
TARGET=tos-work-1
BODY=**[FEEDBACK on test_calculator.zsh]**: Native Zsh math `$((...))` avoids the heavy subshell overhead of invoking an external binary like `bc`. It's significantly faster for unit tests.
===TOS_COMMENT_END===
EOF
)
echo "$PAYLOAD_COMMENTS" > "$TOS_INPUT"
"$TOS_BIN_CMD" "$TEST_REPO" write comment

show_role "$YELLOW" "ARCHITECT" "Acknowledging the Agent's answer..."
gh issue comment 1 -b "Perfect, that makes sense. Let's proceed with the fix." >/dev/null

show_role "$PURPLE" "GHOST" "Syncing human acknowledgment into the outbox context window..."
"$TOS_BIN_CMD" "$TEST_REPO" sync trinity 1 >/dev/null
terminal_view "Ghost Outbox (Thread Sync)" "$(tail -n 12 "$TOS_CONTEXT")"

show_role "$CYAN" "AGENT" "Outputting the ISSUE payload for the deferred [TODO] task."
PAYLOAD_ISSUE=$(cat << 'EOF'
===TOS_ISSUE_START===
TITLE=Implement divide()
BODY=Deferred from PR #1 feedback.
===TOS_ISSUE_END===
EOF
)
echo "$PAYLOAD_ISSUE" > "$TOS_INPUT"
"$TOS_BIN_CMD" "$TEST_REPO" write issue
end_turn

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
PAYLOAD_GREEN=$(cat << EOF
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Green: implement add()
BODY=Resolved [FIXME] and added implementation. Fixes #1.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo \$(( \$1 + \$2 )); }
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_GREEN" > "$TOS_INPUT"
"$TOS_BIN_CMD" "$TEST_REPO" write code

show_role "$YELLOW" "ARCHITECT" "The diff is clean. Implementation matches the Wisdom."
end_turn

# ==============================================================================
# CHAPTER 8: REFACTOR & DOCS
# ==============================================================================
CH8=$(cat << 'EOF'
# Chapter 8: Refactor Phase

Goal: Clean up implementation and self-document before merging.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH8"

show_role "$CYAN" "AGENT" "Refactoring and adding docstrings to calculator.zsh, updating README.md."
PAYLOAD_REFACTOR=$(cat << EOF
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Docs: add docstrings to add() and update README
BODY=Refactored syntax and documented standard usage constraints in code and README.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
# Adds two integers using native Zsh math
add() { echo \$(( \$1 + \$2 )); }
===TOS_FILE_END===
===TOS_FILE_START: README.md===
# TOS Tutorial

## Calculator Module
The \`add(a, b)\` function natively supports adding two integers, including negative numbers.

# [TODO] Implement divide() later.
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_REFACTOR" > "$TOS_INPUT"
"$TOS_BIN_CMD" "$TEST_REPO" write code

show_role "$YELLOW" "ARCHITECT" "Reviewing the Ghost's post-commit IPC journal to verify code..."
terminal_view "Ghost Outbox Journal" "$(tail -n 25 "$TOS_CONTEXT")"
end_turn

# ==============================================================================
# CHAPTER 9: RETROSPECTIVE
# ==============================================================================
CH9=$(cat << 'EOF'
# Chapter 9: The Retrospective

Goal: The Agent updates its own system prompts based on session learnings.
Role: Team_of_Six (Agent / Doer)
EOF
)
present_chapter "$CH9"

show_role "$CYAN" "AGENT" "Proposing rules based on Architect's manual math injection..."
PAYLOAD_RETRO=$(cat << EOF
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Retro: Enforce parameter validation
BODY=Update agent rules to always check param length before Zsh math evaluation.
===TOS_META_END===
===TOS_FILE_START: doc/some_learning.md===
Rule 1: Use native Zsh math.
Rule 2: Check integer count before math blocks.
===TOS_FILE_END===
EOF
)
echo "$PAYLOAD_RETRO" > "$TOS_INPUT"
"$TOS_BIN_CMD" "$TEST_REPO" write code

show_role "$YELLOW" "ARCHITECT" "Agent constraints evolved and committed."
end_turn

# ==============================================================================
# CHAPTER 10: MERGE & TEARDOWN
# ==============================================================================
CH10=$(cat << 'EOF'
# Chapter 10: The Closure

Goal: Final verification, formal PR approval, local branch sync, and merge.
Role: Principal Architect (Wisdom)
EOF
)
present_chapter "$CH10"

show_role "$YELLOW" "ARCHITECT" "Pulling Ghost work and running final local tests..."
git pull origin tos-work-1 -q
zsh ./test_calculator.zsh && echo -e "${GREEN}✅ Local tests passed.${NC}"

show_role "$YELLOW" "ARCHITECT" "Preserving the IPC transcript into README before merge..."
echo -e "\n## Ghost Session Transcript\n\n<details><summary>Click to expand</summary>\n\n\`\`\`markdown" >> README.md
cat "$TOS_CONTEXT" >> README.md
echo -e "\n\`\`\`\n</details>" >> README.md
git add README.md
git commit -m "chore: preserve ghost session transcript in README" -q
git push origin tos-work-1 -q

show_role "$YELLOW" "ARCHITECT" "Formally Reviewing the Pull Request..."
gh pr review tos-work-1 --comment -b "Excellent work. Transcript preserved. Looks good to merge."

show_role "$CYAN" "AGENT" "Declaring TRINITY manifest for merge validation..."
PAYLOAD_TRINITY=$(cat << EOF
===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=calculator.zsh test_calculator.zsh README.md doc/some_learning.md=
===TOS_TRINITY_END===
EOF
)
echo "$PAYLOAD_TRINITY" > "$TOS_INPUT"

show_role "$YELLOW" "ARCHITECT" "Merging PR and syncing local branches..."

# 1. ADD THIS CHECK: Fail fast if trinity.zsh aborts
if ! "$TOS_BIN_CMD" "$TEST_REPO" write trinity; then
    echo -e "\n🚨 Tutorial Aborted: 'write trinity' failed. The workspace has been preserved for inspection."
    exit 1
fi

# 2. KEEP THIS: Clean up local branch after a SUCCESSFUL merge
show_role "$YELLOW" "ARCHITECT" "Cleaning up Architect local workspace..."
git checkout main -q
git branch -D tos-work-1 -q 2>/dev/null || true

# 3. DELETE THIS: Removed the redundant gh issue close 1 command

# 4. KEEP THIS: Just view the status to prove trinity.zsh closed it
terminal_view "Issue #1 Status" "$(gh issue view 1 | grep -i state)"

