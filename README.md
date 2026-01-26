# Team of Six (V56)

## 👑 Identity: The System Ghost
The **Team of Six** ($AI_USER) is a persistent DevOps agent that operates alongside the Architect ($REAL_USER).

## 🛡️ Operational Security
* **Tri-Repo Topology:** Projects are colocated with `llm_agents` and `team_of_six`.
* **The Sandbox Protocol:** The Ghost operates in pure sandboxes ($AI_USER folders).
* **The Interface:** The Architect has Read-Only access to these sandboxes for verification.
* **Review Flow:** All code changes flow via **Pull Requests (PRs)** from the Sandbox to the Architect's Repo Clone.

## ⚡ Commands

### `new` (Project Creation)
Initializes a new Team of Six project with V56 scaffolding.

```bash
team_of_six new <project_name>
```

**Constraint (Tri-Repo Topology):**
This command **MUST** be run in the "Zone Root" (the parent directory containing the `team_of_six` and `llm_agents` repositories).
* ✅ Valid: `~/code/team_of_six`, `~/code/llm_agents` -> Run in `~/code`
* ⛔ Invalid: `~/code/random_folder` (Missing siblings)

### `wrapper` (Execution)
Runs the Ghost Engine to process `tos_input.sh`.

```bash
cd <project_name>
team_of_six wrapper
```

### `publish` (Governance)
Pushes code to the origin and creates a Pull Request.

```bash
cd <project_name>
team_of_six publish -m "feat: description"
```

## 🏗️ Architecture
* **Repo:** `~/.team_of_six` (Config), Project Dirs (Data)
* **Execution:** `team_of_six wrapper`
