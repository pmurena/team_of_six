# Team of Six (TOS) — The Contextual Trinity

**Team of Six** is a declarative, air-gapped DevOps framework designed to solve the inherent unreliability of LLM agents ("The Ghost") in coding environments.

Unlike standard agentic frameworks that struggle with context drift and hallucination, TOS enforces a strict tripartite cognitive boundary known as **The Contextual Trinity**. By mapping an LLM's reasoning to deterministic version control primitives, we transform a probabilistic model into a reliable engineering operator.

## The Core Philosophy: The Contextual Trinity
To prevent cognitive overload, we anchor the agent's focus to three specific pillars:
1.  **One Issue (The Intent):** The bounded scope of *why* a change is made.
2.  **One PR (The Change):** The isolated context of *what* is being modified.
3.  **One Branch (The Baseline):** The deterministic reality of the current codebase.

## Documentation Index
* [01. LLM Pitfalls Addressed](docs/01-llm-pitfalls.md)
* [02. Mitigation Architecture](docs/02-mitigation-architecture.md)
* [03. The Contextual Trinity](docs/03-contextual-trinity.md)
* [04. The Plaintext Protocol](docs/04-plaintext-protocol.md)
* [05. Neovim Plugin Integration](docs/05-neovim-plugin.md)
* [06. The Agentic Unleash](docs/06-agentic-unleash.md)
* [07. Security & Sudo Perimeter](docs/07-security.md)
* [08. Workflow & How-To Guide](docs/08-workflow.md)

## 🚀 Quick Start
1. **Deploy Infrastructure:** `sudo ./inf/tos_deploy.sh`.
2. **Provision a Project:** `tos <project_name> work start`.
3. **Open an Issue Context:** `tos <project_name> work <ISSUE_ID>`.
