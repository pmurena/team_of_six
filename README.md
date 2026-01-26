# Team of Six (V56)

## 👑 Identity: The System Ghost
The **Team of Six** ($AI_USER) is a persistent DevOps agent that operates alongside the Architect ($REAL_USER).

## 🛡️ Operational Security
* **Tri-Repo Topology:** Projects are colocated with `llm_agents` and `team_of_six`.
* **The Sandbox Protocol:** The Ghost operates in pure sandboxes ($AI_USER folders).
* **The Interface:** The Architect has Read-Only access to these sandboxes for verification.
* **Review Flow:** All code changes flow via **Pull Requests (PRs)** from the Sandbox to the Architect's Repo Clone.

## Architecture
* **Repo:** `/mnt/storage/team_of_six`
* **Execution:** `team_of_six wrapper` or `team_of_six publish`

## Usage
    cd ~/my_project
    team_of_six wrapper --input ~/.team_of_six/tos_input.sh
