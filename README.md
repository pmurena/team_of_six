# 👻 Team of Six (v70) - The Air-Gapped Agentic OS

**Team of Six** is a state-persistent, agentic DevOps framework designed for high-speed, terminal-native developers. 

Unlike standard coding copilots that blindly inject code into your editor, Team of Six operates as a "System Ghost" in an isolated sandbox. You (The Architect) define the intent in your IDE; the Ghost figures out the implementation, executes the bash commands, and manages the GitOps pipeline autonomously.

## 🧠 Model Requirements (The LLM)
Because the Ghost is completely blind to your local host and communicates *only* via generated Zsh execution scripts, **instruction-following capability is paramount**. 
* We strongly recommend using frontier models (like **Claude 3.5 Sonnet** or **GPT-4o**) for the Ghost persona.
* Weaker or smaller local models may fail to respect the strict "Mirror -> Execute" state machine, leading to malformed bash scripts or premature executions.

## ✨ Key Features
* **Zero Context-Switching:** Stay in your IDE. Communicate with the Ghost via an Inter-Process Communication (IPC) file in `/run/team_of_six/`.
* **Air-Gapped Security:** The Ghost runs under a restricted Linux user (`team_of_six`). It cannot modify your host environment or read your personal files.
* **Strict TDD & GitOps:** The system enforces a "Test-First" branching strategy. Actual code modifications are handled in the sandbox and pushed directly to GitHub Pull Requests.
* **Zsh & FHS Native:** Zero heavy runtimes (No Node.js, Python, or Docker required). Core routing is pure Zsh.

## 🛠️ Installation (Linux & macOS)
The installer configures the system user, permissions, and FHS directories (`/opt/team_of_six`, `/mnt/team_of_six`, `/run/team_of_six`).
```zsh
git clone [https://github.com/pmurena/team_of_six.git](https://github.com/pmurena/team_of_six.git)
cd team_of_six
sudo ./bin/tos_installer.sh
```

## 🚀 Quick Start
```zsh
# 1. Provision a new project in the sandbox
sudo -u team_of_six tos my_project new

# 2. Sync issue/branch context for the AI
sudo -u team_of_six tos my_project work main

# 3. Execute an AI-generated script
sudo -u team_of_six tos my_project wrapper

# 4. Publish AI changes to GitHub
sudo -u team_of_six tos my_project publish
```
*For the complete Issue-Driven lifecycle, see [docs/WORKFLOW.md](docs/WORKFLOW.md).*
