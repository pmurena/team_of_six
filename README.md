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
```zsh
./bin/tos_installer.sh
```

## ⚡ Usage
**Standard Execution:**
```zsh
team_of_six wrapper
```

**Publication:**
```zsh
team_of_six publish -m "commit message"
```
