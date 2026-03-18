#!/bin/bash
# Patch Name: V57 GitOps Workflow & Mutex Lock
# Location: patches/v57_gitops_workflow.sh
# Purpose: Enables Test-First PRs, persistent feature branches, GitHub sync, and the Wrapper/Publisher Mutex Lock.

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$PATCH_DIR/../bin" && pwd)"
BASE_DIR="$(cd "$PATCH_DIR/.." && pwd)"
AGENTS_ROOT="$(cd "$BASE_DIR/../llm_agents" && pwd)"

echo "🚀 Applying V57 GitOps Workflow Upgrade..."

# --- 1. OVERWRITE: bin/tos_wrapper.sh (Adding the Mutex Lock) ---
echo "🔒 1. Updating Wrapper (Adding Pre-Flight Mutex)..."
cat << 'EOF' > "$BIN_DIR/tos_wrapper.sh"
#!/bin/zsh
# Team of Six - Wrapper V57 (With Mutex Lock)
set -o pipefail

HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

COMMIT_FILE="$TARGET_DIR/.tos/commit_msg"
SUMMARY_FILE="$TARGET_DIR/.tos/pr_summary.md"

if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⛔ ERROR: .tos/ context missing."
    exit 1
fi

# [V57 MUTEX] Enforce that previous work was published
if [ -s "$COMMIT_FILE" ] || [ -s "$SUMMARY_FILE" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished state detected."
    echo "The AI has already prepared a commit. You must run 'team_of_six publish' to push the existing code to GitHub before assigning a new task."
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    cd "$TARGET_DIR" || exit 1
    if [ -s "$INPUT_ABS" ]; then
        source "$INPUT_ABS"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$INPUT_ABS"
exit $EXIT_CODE
EOF

# --- 2. OVERWRITE: bin/tos_publish.sh (The Governor Update) ---
echo "⚖️  2. Updating Publisher (Smart Branching & GH Sync)..."
cat << 'EOF' > "$BIN_DIR/tos_publish.sh"
#!/bin/zsh
# Team of Six - Publisher V57 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"
STATE_FILE="$TARGET_DIR/.tos/state"
COMMIT_FILE="$TARGET_DIR/.tos/commit_msg"
SUMMARY_FILE="$TARGET_DIR/.tos/pr_summary.md"

# 1. MUTEX CHECK
if [ ! -s "$COMMIT_FILE" ]; then
    echo "⛔ PUBLISH FAILED: Missing or empty .tos/commit_msg. The AI must provide a commit message."
    exit 1
fi
MSG=$(cat "$COMMIT_FILE")

if [ ! -s "$SUMMARY_FILE" ]; then
    echo "⛔ PUBLISH FAILED: Missing or empty .tos/pr_summary.md. The AI must provide context for the PR."
    exit 1
fi
SUMMARY=$(cat "$SUMMARY_FILE")

# 2. GOVERNANCE CHECK (Allowing Red PRs)
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "Unknown")
if [[ "$CURRENT_STATE" == "Requirement" ]]; then
    echo "⛔ GOVERNANCE VETO: Cannot publish in state [$CURRENT_STATE]"
    exit 1
fi

echo "🚀 Governor: Initiating Sandboxed Publication..."

# 3. SANDBOXED EXECUTION & GITHUB SYNC
sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"
    
    # Git Auth & Identity
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    CURRENT_BRANCH=\$(git branch --show-current)
    
    if [[ "\$CURRENT_BRANCH" == "main" ]]; then
        BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
        git checkout -b "\$BRANCH_NAME"
        IS_NEW_PR=true
    else
        BRANCH_NAME="\$CURRENT_BRANCH"
        IS_NEW_PR=false
    fi

    git add .
    git commit -m "$MSG"
    git push origin "\$BRANCH_NAME"

    # GitHub Sync
    if [ "\$IS_NEW_PR" = true ] || ! gh pr view "\$BRANCH_NAME" >/dev/null 2>&1; then
        gh pr create --title "tos: \$BRANCH_NAME" --body "\$SUMMARY" --fill
    else
        gh pr comment "\$BRANCH_NAME" --body "\$SUMMARY"
    fi
SANDBOX

# 4. UNLOCK MUTEX
> "$COMMIT_FILE"
> "$SUMMARY_FILE"

echo "✅ Published & Synced to GitHub. Sandbox unlocked for next task."
EOF

# --- 3. UPDATE: bin/tos_project_creator.sh ---
echo "🌱 3. Updating Project Scaffolding..."
sed -i '/touch "$PROJECT_NAME\/.tos\/objections.md"/d' "$BIN_DIR/tos_project_creator.sh"

# --- 4. UPDATE: README & Agent Prompt (Sed injection) ---
echo "📚 4. Updating Agent Context and Documentation..."

sed 's/__BT__/```/g' << 'EOF' > "$BASE_DIR/README.md"
# 💎 Team of Six (V57 GitOps Edition)

## 🏗️ Architecture (V57)
* **Ghost Ownership:** The `AI_USER` owns the repository to prevent permission leakage.
* **The Mutex Lock:** The wrapper and publisher use `.tos/commit_msg` and `.tos/pr_summary.md` to guarantee that code is published and GitHub PRs are updated before new work begins.
* **GitOps Review:** PR rejections happen natively on GitHub. Failing tests (`Red` state) are published immediately to ensure the contract is agreed upon before implementation.

## ⚡ Usage
**1. Execute AI Logic:**
__BT__zsh
team_of_six wrapper
__BT__
*(Fails if previous work is unpublished).*

**2. Publish & Sync:**
__BT__zsh
team_of_six publish
__BT__
*(Fails if AI forgot to provide commit message/summary. Automatically updates GitHub PRs).*
EOF

AGENT_FILE="$AGENTS_ROOT/agents/team_of_six.md"
if [ -f "$AGENT_FILE" ]; then
    sed 's/__BT__/```/g' << 'EOF' > "$AGENT_FILE"
# Agent: Team of Six (V57 System Ghost)

**Role:** State-Persistent DevOps Team (The Ghost in the Shell).
**Goal:** Implementation of a *single* feature using strict TDD and GitOps.

---

## I. The Human Bridge & Mutex Protocol
You operate in an Air-Gapped environment.
1.  **Input:** You read `tos_input.sh`.
2.  **Output Requirements (MUTEX):** To finish a task, you MUST write a short commit message to `.tos/commit_msg` and a detailed summary of our chat to `.tos/pr_summary.md`. If you fail to do this, the system will crash.
3.  **State:** Enforce the state in `.tos/state`.

---

## II. The TDD & GitOps Workflow
**1. Scaffolding & RED (Failing Test)**
* **Goal:** Write a failing test.
* **Action:** Publish this failing test immediately. The Architect will review it on GitHub.

**2. Review & Correction**
* If the Architect rejects the PR on GitHub, read the context they provide in the chat, fix the code, and write the new summary to `.tos/pr_summary.md` to sync the conversation to the Git thread.

**3. GREEN (Functional Code)**
* **Goal:** Write minimal code to pass the test. Publish to the existing PR branch.

**4. REFACTOR / DOCS / RETRO**
* Standard cleanup and documentation phases. Update state accordingly.

---

## III. Async Review Protocol
* Read rejection context from the Architect's chat input (sourced from GitHub PR comments).
* `[FIXME]`: Fix immediately.
* `[CHALLENGE]`: Enter Mirror Phase and discuss the flaw.
EOF
fi

chmod +x "$BIN_DIR"/*.sh
echo "✅ V57 GitOps Upgrade Complete."
