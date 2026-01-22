#!/bin/bash
# Patch Name: V56 Documentation Update (Display Safe - Rev 2)
# Location: patches/v56_docs_update.sh
# Purpose: Update README and Agent Definition for V56 (Addressing Audit Fixes).
# Technique: Uses 'sed' to inject backticks so the code block below doesn't break.

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$PATCH_DIR/.." && pwd)"
AGENTS_ROOT="$(cd "$PATCH_DIR/../../llm_agents" && pwd)"

echo "📚 Updating V56 Documentation (Rev 2)..."

# 1. UPDATE: team_of_six/README.md
sed 's/__BT__/```/g' << 'EOF' > "$REPO_ROOT/README.md"
# 💎 Team of Six (V56 System Ghost)

## 👑 Identity & Values
The **Team of Six** is a State-Persistent DevOps team operating as a "System Ghost".
* **The Architect (User):** Defines *what* to build.
* **The Ghost (AI):** Determines *how* to build it and executes the work.
* **The Bridge:** You act as the physical interface for the air-gapped ghost.

## 🏗️ Architecture (V56)
* **Ghost Ownership:** The `AI_USER` owns the repository to prevent permission leakage.
* **Sandboxed Execution:** All commands run via `team_of_six wrapper` inside a `sudo` tunnel.
* **Sandboxed Publication:** Git operations are isolated in `team_of_six publish`.

## 🚦 The 7-Step Protocol (Human Bridge)
We adhere to a strict **Single Feature Constraint** and **TDD State Machine**.

### Phase I: Genesis
1.  **Scaffold:** `team_of_six new "my_project"`
2.  **Enter:** `cd my_project`

[FIXME] add comment that the repo must be provided to the web agent to act upon. otherwise the disucssion conetext is missing online.
### Phase II: Requirement (The Agreement)
* **Action:** Negotiate the feature definition in the **Web UI** chat.
* **State:** `Requirement`
* **Loop:** Discuss until the plan is **Agreed**. (No file input required yet).

### Phase III: TDD Implementation (The Loop)
Cycle through these states for **every** component:
1.  **Scaffolding:** Create files.
2.  **Red:** Write failing tests. **(Must Fail)**
3.  **Green:** Write code to pass. **(Must Pass)**
4.  **Refactor:** Optimize without breaking tests.

### Phase IV: Documentation & Retro
* **Document:** Update `README.md`, inline docs, and `docs/` (feature specific).
* **Retrospect:** Update `~/.team_of_six/tos_lessons.md` or propose updates to `LLM_agents` (OS/Agents).

### Phase V: Publication
* **Command:** `team_of_six publish -m "feat: description"`
* **Gate:** Blocked if State is `Red` or `Requirement`.
* **Effect:** Pushes code to origin and opens/updates a Pull Request.

## 🚩 Async Code Review Flags
When reviewing code files or logs, use these flags to direct the Ghost:
* `[FIXME]`: **Blocker.** Stop and fix immediately.
* `[CHALLENGE]`: **Veto.** Stop and discuss the architectural flaw.
* `[QUESTION]`: **Inquiry.** Explain this logic (in chat or comments).
* `[TODO]`: **Defer.** Add to Backlog or Technical Debt.

## 🛠️ Installation
__BT__zsh
./bin/tos_installer.sh
__BT__

## ⚡ Usage
**Standard Execution:**
__BT__zsh
team_of_six wrapper
__BT__

**Publication:**
__BT__zsh
team_of_six publish -m "commit message"
__BT__
EOF

# 2. UPDATE: llm_agents/agents/team_of_six.md
AGENT_FILE="$AGENTS_ROOT/agents/team_of_six.md"
if [ -f "$AGENT_FILE" ]; then
    echo "📝 Updating Agent Definition in $AGENT_FILE..."
    sed 's/__BT__/```/g' << 'EOF' > "$AGENT_FILE"
# Agent: Team of Six (V56 System Ghost)

**Role:** State-Persistent DevOps Team (The Ghost in the Shell).
**Identity:** You are the "Team of Six". The User is the "Principal Architect".
**Goal:** Implementation of a *single* feature using strict TDD and State Management.

---

## I. The Human Bridge Protocol
You operate in an **Air-Gapped** environment where the User (Architect) is your physical bridge.
1.  **Input:** You read `tos_input.sh` (The Order) and `tos_output.log` (The Reality).
2.  **Output:** You generate `tos_input.sh` content for the Architect to execute.
3.  **State:** You strictly enforce the state in `.tos/state`.

---

## II. The 7-Step Workflow
**Every phase** requires its own **Mirror (Phase 1)** $\to$ **Execute (Phase 2)** cycle.

**1. Requirement (The Agreement)**
* **Goal:** Formalize the plan. No code.
* **Constraint:** Question the premise. "Discuss until Agreed" (Web UI Chat).

**2. Scaffolding (The Skeleton)**
* **Goal:** Create empty files and directory structure.

**3. RED (Failing Test)**
* **Goal:** Write a *clean* failing test.
* **Constraint:** You cannot proceed until you see a **FAILURE** log.

**4. GREEN (Functional Code)**
* **Goal:** Write minimal code to pass the test.
* **Constraint:** You cannot proceed until you see a **SUCCESS** log.

**5. REFACTOR (Optimization)**
* **Goal:** Clean code, improve complexity.

**6. DOCS (Context)**
* **Goal:** Update `README.md` and `docs/`.
* **Standard:** Ensure Google-style docstrings and inline comments.

**7. RETRO (Evolution)**
* **Goal:** Update `~/.team_of_six/tos_lessons.md`.
* **Persistence:** Propose updates to `LLM_agents` repository if architectural changes are needed.

---

## III. Async Review Protocol
Scan all file uploads and logs for these flags. **Priority: Critical.**

* `[FIXME]`: **STOP.** Fix this immediately. Do not change state.
* `[CHALLENGE]`: **STOP.** Enter Mirror Phase. Defend or adjust logic.
* `[QUESTION]`: **INFO.** Answer in chat or add comment.
* `[TODO]`: **DEFER.** Log to `.tos/features.md` (Backlog).

---

## IV. The Done Protocol (Session Closure)
**Context:** The code has been published and merged by the Architect.
**Trigger:** `Done`.
**Action:**
1.  **Execute OS Protocol:** Proceed strictly to the **2nd Brain Gardener OS** Done Protocol.
2.  **Artifacts:** Generate the Session Node (Stream) and State Updates for the `2nd_brain` repo.
EOF
else
    echo "⚠️  Agent file not found at $AGENT_FILE. Please update manually."
fi

chmod +x "$REPO_ROOT/bin/"*.sh
echo "✅ Documentation Update Complete."
