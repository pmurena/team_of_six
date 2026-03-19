# 💎 Team of Six (V63 XDG Native Edition)

## 👑 Identity & Values
The **Team of Six** is a State-Persistent DevOps team operating as a "System Ghost".
* **The Architect (User):** Defines *what* to build.
* **The Ghost (AI):** Determines *how* to build it and generates the execution scripts.
* **The Bridge:** You act as the physical interface, feeding the AI's scripts into the local, air-gapped engine.

## 🏗️ Architecture (V63)
* **XDG Native:** Configuration and state are managed via `$XDG_CONFIG_HOME`, `$XDG_RUNTIME_DIR`, and `$XDG_STATE_HOME`.
* **Ghost Ownership:** The `AI_USER` strictly owns the Sandbox workspace.
* **Sandboxed Code Execution:** The `team_of_six wrapper` executes the AI's bash scripts inside the `$TOS_SANDBOX`. Scripts execute at the sandbox root and must navigate into specific projects manually.
* **The Outbox Mutex:** Actual code modifications are made directly in the `$TOS_SANDBOX`. However, all *GitOps publication instructions* must be staged as payloads in `$TOS_OUTBOX`. The AI cannot accept new tasks if there are unpublished publication payloads pending.
* **Dynamic GitOps Router:** The publisher dynamically scans `$TOS_OUTBOX` payloads to execute commits, open PRs, update PRs, or manage Issues based on the presence of `branch` and `ref` files. 

> **Important:** The publisher uses `git add .` to process codebase modifications. Due to this, only one code-modifying payload (a payload with a `branch` file) can be staged and processed per project at a time.

## ⚡ Usage

**1. Scaffold a New Project:**
```zsh
team_of_six new <project_name>
```

**2. Execute AI Logic (The Wrapper):**
```zsh
team_of_six wrapper
```
*(Fails if unpublished payloads are detected in `$TOS_OUTBOX`).*

**3. Publish & Sync to GitHub (The Governor):**
```zsh
team_of_six publish
```
*(Scans `$TOS_OUTBOX/<project>/<payload_id>/` for `title` and `body` files. Missing files will trigger a Gov. failure. Automatically updates GitHub PRs and Issues).*

**4. Unified Loop (Default):**
```zsh
team_of_six
```
*(Executes `wrapper` and then immediately attempts to `publish`).*
