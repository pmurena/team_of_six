#!/bin/zsh
# ==============================================================================
# Team of Six - Interactive End-to-End Tutorial & Integration Test (V76)
# Purpose: A living, executable storyboard testing EVERY framework feature.
# Dependencies: zsh, git, gh
# ==============================================================================

set -e

# --- 2. ZSH FORCE (The Handover) ---
if [ -z "$ZSH_VERSION" ]; then
    exec zsh "$0" "$@"
fi

# --- Configuration & Validation ---
TEST_REPO="tos-calc-test-$(date +%s)"
TOS_MNT="/mnt/team_of_six"
INBOX="$TOS_MNT/tos_home/$USER/.ipc/inbox.md"
OUTBOX="$TOS_MNT/tos_home/$USER/.ipc/outbox.md"
TOS_BIN="$TOS_MNT/.local/bin/tos"

# --- Advanced UX Colors & Formatting ---
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Foreground
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
PROMPT_COLOR='\033[1;33m'

# Backgrounds for extreme visibility
BG_PURPLE='\033[45;97m' # Architect
BG_CYAN='\033[46;30m'   # Ghost
BG_YELLOW='\033[43;30m' # Inbox
BG_BLUE='\033[44;97m'   # Outbox / Git

command -v gh >/dev/null 2>&1 || { echo "🚨 ERROR: 'gh' CLI required."; exit 1; }
[[ ! -x "$TOS_BIN" ]] && { echo "🚨 ERROR: tos engine not found at $TOS_BIN"; exit 1; }

# --- Helper: The Page & UI Engine ---
function present_chapter() {
    clear
    local chapter_text="$1"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "$chapter_text"
    echo -e "${CYAN}==============================================================================${NC}\n"
    echo -ne "${PROMPT_COLOR}🚀 Press [Enter] to execute this step, or [Ctrl+C] to abort... ${NC}"
    read -r
}

# The "Shine as Fire" highlighting functions
function show_architect_action() { echo -e "\n${BOLD}${BG_PURPLE} 🧑‍💻 ARCHITECT (Human) ${NC} ${PURPLE}$1${NC}"; }
function show_ghost_action()     { echo -e "\n${BOLD}${BG_CYAN} 👻 GHOST ENGINE (tos) ${NC} ${CYAN}$1${NC}"; }
function show_git_diff()         { echo -e "\n${BOLD}${BG_BLUE} 🔍 REPOSITORY DIFF ${NC}\n"; git diff --color=always; }

function show_ipc_inbox() { 
    echo -e "\n${BOLD}${BG_YELLOW} 📤 IPC INBOX (Writing Payload) ${NC} ${YELLOW}Routing text to $INBOX...${NC}"
}

function show_ipc_outbox() { 
    echo -e "\n${BOLD}${BG_BLUE} 📥 IPC OUTBOX (Reading Context) ${NC} ${BLUE}$1${NC}"
}

function show_payload() { 
    echo -e "${DIM}┌───────────────────────────────────────────────────────────────────────"
    echo "$1" | sed 's/^/│  /'
    echo -e "└───────────────────────────────────────────────────────────────────────${NC}"
}

function pause_for_reading() { echo -ne "\n${PROMPT_COLOR}📖 Press [Enter] to continue... ${NC}"; read -r; }

# ==============================================================================
# CHAPTER 0: THE GENESIS
# ==============================================================================
CH0=$(cat << 'EOF'
# Chapter 0: The Genesis

We are establishing the remote truth. We will create the repo, add a README, 
a utility file (for context injection later), and the Ghost's brain file 
so we can test Stage 6 (Retro/Evolution).
EOF
)
present_chapter "$CH0"

show_architect_action "Creating local repository and base files..."
mkdir "$TEST_REPO" && cd "$TEST_REPO"
git init >/dev/null

echo "# TOS Interactive Tutorial" > README.md
echo "log() { echo \"[LOG] \$1\"; }" > utils.zsh
mkdir llm_agents
echo "Rule 1: Be helpful." > llm_agents/team_of_six.md

git add . && git commit -m "Initial commit" >/dev/null
show_architect_action "Pushing repo to GitHub ($TEST_REPO)..."
gh repo create "$TEST_REPO" --private --source=. --remote=origin --push
echo -e "${GREEN}✅ Repository initialized and pushed to GitHub.${NC}"
pause_for_reading

# ==============================================================================
# CHAPTER 1: PROVISIONING THE SANDBOX (tos work start)
# ==============================================================================
CH1=$(cat << 'EOF'
# Chapter 1: Provisioning the Sandbox

We clone the remote truth into the Ghost's secure, air-gapped environment.
`tos <repo> work start`
EOF
)
present_chapter "$CH1"

show_ghost_action "Executing: tos $TEST_REPO work start"
"$TOS_BIN" "$TEST_REPO" work start
pause_for_reading

# ==============================================================================
# CHAPTER 2: STAGE 1 - SCOPING (tos work new)
# ==============================================================================
CH2=$(cat << 'EOF'
# Chapter 2: Scoping the Work (Stage 1)

The Ghost generates batched issue blocks to establish the 1:1:1 Triangle.
`tos <repo> work new`
EOF
)
present_chapter "$CH2"
PAYLOAD=$(cat << 'EOF'
===TOS_ISSUE_START===
TITLE=Implement add() function
BODY=Implement add() returning sum of two ints. Needs test_calculator.zsh.
===TOS_ISSUE_END===
===TOS_ISSUE_START===
TITLE=Implement subtract() function
BODY=Implement subtract() returning difference.
===TOS_ISSUE_END===
EOF
)

show_ipc_inbox
show_payload "$PAYLOAD"
echo "$PAYLOAD" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO work new"
"$TOS_BIN" "$TEST_REPO" work new
pause_for_reading

# ==============================================================================
# CHAPTER 3: OPENING THE WORKSPACE (tos work 1)
# ==============================================================================
CH3=$(cat << 'EOF'
# Chapter 3: Opening the Workspace

We route the Ghost to focus exclusively on Issue #1.
`tos <repo> work 1`
EOF
)
present_chapter "$CH3"

show_ghost_action "Executing: tos $TEST_REPO work 1"
"$TOS_BIN" "$TEST_REPO" work 1
pause_for_reading

# ==============================================================================
# CHAPTER 4: CONTEXT INJECTION (tos work peek)
# ==============================================================================
CH4=$(cat << 'EOF'
# Chapter 4: Surgical Context Injection (Peek)

Before the Ghost writes the test, it needs to see how `utils.zsh` works.
The Architect injects it directly into the Outbox context.
`tos <repo> work peek utils.zsh`
EOF
)
present_chapter "$CH4"

show_architect_action "Executing: tos $TEST_REPO work peek utils.zsh"
"$TOS_BIN" "$TEST_REPO" work peek utils.zsh

show_ipc_outbox "Outbox securely updated with utils.zsh file contents."
pause_for_reading

# ==============================================================================
# CHAPTER 5: STAGE 2 - RED PHASE (tos write code)
# ==============================================================================
CH5=$(cat << 'EOF'
# Chapter 5: The Red Phase (TDD)

The Ghost publishes the functionally failing test based on the context.
`tos <repo> write code`
EOF
)
present_chapter "$CH5"
PAYLOAD=$(cat << 'EOF'
===TOS_META_START===
TITLE=Red: failing test for add function
BODY=Adds test_calculator.zsh using native zsh logic and utils.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
log "Running tests..."
if [[ "$(add 2 3 2>/dev/null)" != "5" ]]; then exit 1; fi
===TOS_FILE_END===
EOF
)

show_ipc_inbox
show_payload "$PAYLOAD"
echo "$PAYLOAD" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO write code"
"$TOS_BIN" "$TEST_REPO" write code
pause_for_reading

# ==============================================================================
# CHAPTER 6: DISTRIBUTED ASYNC REVIEW
# ==============================================================================
CH6=$(cat << 'EOF'
# Chapter 6: The Architect's Async Review

The Architect reviews the code on GitHub and leaves three tags:
1. `[QUESTION]` on the Issue thread.
2. `[FIXME]` inline in the code.
3. `[TODO]` inline in the code (Scope Creep).
EOF
)
present_chapter "$CH6"

show_architect_action "Simulating manual PR review and Git edits..."
gh issue comment 1 -b "[QUESTION] Should we support floats?" >/dev/null
gh pr checkout tos-work-1 >/dev/null 2>&1

cat << 'EOF' > test_calculator.zsh
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh 2>/dev/null || true
# [TODO] Add a divide() function later.
# [FIXME] Add a test case for negative numbers.
log "Running tests..."
if [[ "$(add 2 3 2>/dev/null)" != "5" ]]; then exit 1; fi
EOF

git add test_calculator.zsh && git commit -m "Architect: Review tags" >/dev/null
git push origin tos-work-1 >/dev/null 2>&1

show_git_diff
pause_for_reading

# ==============================================================================
# CHAPTER 7: STAGE 3 - GHOST REVIEW & ROUTING
# ==============================================================================
CH7=$(cat << 'EOF'
# Chapter 7: Ghost Async Processing (Comments & Deferrals)

The Ghost syncs the workspace, sees the tags, and outputs TWO batch payloads:
1. `tos write comment` to answer the [QUESTION].
2. `tos work new` to defer the [TODO] into a new Issue (#3).
EOF
)
present_chapter "$CH7"

show_ghost_action "Syncing Workspace Context (tos $TEST_REPO work 1)"
"$TOS_BIN" "$TEST_REPO" work 1 >/dev/null

PAYLOAD_COMMENT=$(cat << 'EOF'
===TOS_COMMENT_START===
TARGET=1
BODY=**[QUESTION]:** Sticking to integers for now.
===TOS_COMMENT_END===
EOF
)
show_ipc_inbox
show_payload "$PAYLOAD_COMMENT"
echo "$PAYLOAD_COMMENT" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO write comment"
"$TOS_BIN" "$TEST_REPO" write comment

PAYLOAD_TODO=$(cat << 'EOF'
===TOS_ISSUE_START===
TITLE=Implement divide() function
BODY=Deferred from PR #1 review. Implement division.
===TOS_ISSUE_END===
EOF
)
show_ipc_inbox
show_payload "$PAYLOAD_TODO"
echo "$PAYLOAD_TODO" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO work new"
"$TOS_BIN" "$TEST_REPO" work new
pause_for_reading

# ==============================================================================
# CHAPTER 8: STAGE 4 - THE GREEN PHASE
# ==============================================================================
CH8=$(cat << 'EOF'
# Chapter 8: The Code Fix & Green Phase

The Ghost resolves the [FIXME] and implements the actual code in one push.
`tos <repo> write code`
EOF
)
present_chapter "$CH8"
PAYLOAD_CODE=$(cat << 'EOF'
===TOS_META_START===
TITLE=Green: fix tests and implement add()
BODY=Added negative test case and implemented logic. Fixes #1
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./utils.zsh
source ./calculator.zsh
if [[ "$(add -1 -4)" != "-5" ]]; then exit 1; fi
===TOS_FILE_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(($1 + $2)); }
===TOS_FILE_END===
EOF
)
show_ipc_inbox
show_payload "$PAYLOAD_CODE"
echo "$PAYLOAD_CODE" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO write code"
"$TOS_BIN" "$TEST_REPO" write code
pause_for_reading

# ==============================================================================
# CHAPTER 9: STAGES 5 & 6 - DOCS AND RETRO
# ==============================================================================
CH9=$(cat << 'EOF'
# Chapter 9: Refactor, Docs, and Agent Evolution

The Architect asks the Ghost to wrap up before merge.
The Ghost updates the README (Stage 5) and modifies its OWN prompt constraints (Stage 6).
EOF
)
present_chapter "$CH9"
PAYLOAD_DOCS=$(cat << 'EOF'
===TOS_META_START===
TITLE=Chore: Docs and Retro
BODY=Updated README and Agent constraints.
===TOS_META_END===
===TOS_FILE_START: README.md===
# TOS Interactive Tutorial
* `add(a, b)`: Returns the sum.
===TOS_FILE_END===
===TOS_FILE_START: llm_agents/team_of_six.md===
Rule 1: Be helpful.
Rule 2: Always use $(()) for native Zsh math.
===TOS_FILE_END===
EOF
)
show_ipc_inbox
show_payload "$PAYLOAD_DOCS"
echo "$PAYLOAD_DOCS" > "$INBOX"

show_ghost_action "Executing: tos $TEST_REPO write code"
"$TOS_BIN" "$TEST_REPO" write code
pause_for_reading

# ==============================================================================
# CHAPTER 10: MERGE & TEARDOWN
# ==============================================================================
clear
CH10=$(cat << 'EOF'
# Chapter 10: Architect Merge & Epilogue

We pull the Ghost's work, verify the local tests, and merge the branch!
EOF
)
echo -e "${CYAN}==============================================================================${NC}"
echo -e "$CH10"
echo -e "${CYAN}==============================================================================${NC}\n"

show_architect_action "Pulling remote branch and running tests..."
git pull origin tos-work-1 >/dev/null 2>&1
show_git_diff

echo -e "\n${BOLD}${BG_PURPLE} ⚙️ RUNNING TESTS ${NC}"
zsh ./test_calculator.zsh && echo -e "${GREEN}✅ Local tests passed.${NC}"

show_architect_action "Merging PR via GitHub CLI..."
gh pr merge tos-work-1 --merge --delete-branch >/dev/null

# --- The Transcript Generation ---
TRANSCRIPT=$(cat << 'EOF'
## 📜 Team of Six Tutorial Transcript

1. **Provisioning:** Created the air-gapped sandbox (`tos work start`).
2. **Scoping (Stage 1):** Parsed batched issues (`tos work new`) ensuring the 1:1:1 Triangle.
3. **Workspace:** Routed the Ghost to a single context branch (`tos work 1`).
4. **Peek:** Architect surgically injected `utils.zsh` into the Outbox context.
5. **Red Phase (Stage 2):** Wrote functionally failing tests (`tos write code`).
6. **Async Review:** Architect tagged code with `[QUESTION]`, `[FIXME]`, and `[TODO]`.
7. **Ghost Routing:** Ghost answered via `tos write comment` and deferred the `[TODO]` via `tos work new` to Issue #3.
8. **Green Phase (Stages 3 & 4):** Ghost fixed tests and implemented logic (`tos write code`).
9. **Docs & Retro (Stages 5 & 6):** Ghost updated `README.md` and mutated its own `llm_agents` constraints.
10. **Closure:** PR securely merged and branch deleted.
EOF
)

echo -ne "\n${PROMPT_COLOR}🗑️  Do you want to delete the test repository ($TEST_REPO) now? [y/N] ${NC}"
read -r DELETE_CHOICE

if [[ "$DELETE_CHOICE" =~ ^[Yy]$ ]]; then
    show_architect_action "Cleaning up environment..."
    gh repo delete "$TEST_REPO" --yes >/dev/null 2>&1
    cd .. && rm -rf "$TEST_REPO"
    echo -e "${GREEN}✅ Teardown complete. Environment is clean.${NC}"
else
    echo -e "\n📝 Injecting full transcript into README.md..."
    echo -e "\n$TRANSCRIPT" >> README.md
    git add README.md
    git commit -m "docs: attach tutorial transcript" >/dev/null
    git push origin main >/dev/null 2>&1
    echo -e "📁 ${BLUE}Repository kept for inspection.${NC} You can view the log locally at ./$TEST_REPO"
fi
