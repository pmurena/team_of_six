# Team of Six (TOS) — The Ghost in the Machine

**Team of Six** is a declarative, air-gapped DevOps framework designed to let LLM agents (The "Ghost") interact with a repository without having direct shell access.

It uses a "Typewriter" architecture where the agent outputs synthetic tags, and a local engine parses those tags to perform Git operations, file manipulation, and GitHub Issue management.

## 🏛 Architecture
TOS operates on a strict separation of powers:
* **The Principal Architect (User):** Operates within NeoVim, reviewing and triggering the Ghost's payloads.
* **The Ghost (LLM Agent):** Operates via instructions provided in `llm_agents/team_of_six.md`. It has no local execution capabilities.
* **The Engine (tos):** A suite of Zsh scripts that run under a dedicated AI user via `sudo` to execute the Ghost's "typed" intentions.

## 📂 Project Structure
* `bin/`: The core execution engine and routing gateway.
    * `work/`: Context provisioning, sandbox cloning, and issue management.
    * `write/`: Parsing LLM output into commits, PRs, and comments.
* `conf/`: System-wide configuration and environment variables.
* `inf/`: Infrastructure-as-Code scripts for deploying the sandbox and adding users.
* `llm_agents/`: The "System Prompt" and behavioral logic for the AI.
* `plugins/`: NeoVim integration and IPC bridge.

## 🚀 Quick Start
1. **Deploy the Infrastructure & Auto-Provision User:**

    ```bash
    sudo ./inf/tos_deploy.sh
    ```
   
   This scaffolds the architecture, creates the AI user/group, applies strict permission topologies, and automatically configures the `sudoers` perimeter for the human user running the script.

2. **Supply the GitHub Token (The Airlock Key):**
   
   The Ghost requires a GitHub Personal Access Token (Classic) with `repo` and `read:org` scopes to clone and manage issues. You must place this in the engine's secure config folder.

    ```bash
    sudo sh -c 'echo "YOUR_GITHUB_TOKEN" > /mnt/team_of_six/.local/conf/.token'
    sudo chown team_of_six:team_of_six /mnt/team_of_six/.local/conf/.token
    sudo chmod 400 /mnt/team_of_six/.local/conf/.token
    ```

3. **Provision a Project:**

    ```bash
    tos <project_name> work start
    ```
   
   This clones the target repository into a locked sandbox and queries active issues.
