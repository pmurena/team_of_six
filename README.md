# Team of Six

> *A secure, multi-tenant execution engine for AI-assisted software development.*

---

## The Problem This Solves

Large Language Models are remarkably capable at reasoning about code. They can explain architecture, suggest refactors, write tests, and implement features — often faster and more fluently than a human working alone. But anyone who has tried to use an LLM as a genuine development partner rather than a one-shot query tool has run into the same wall: the LLM drifts. It loses track of what file it was editing. It invents function signatures that don't exist. It confidently implements the wrong feature because three messages ago the conversation shifted and the model carried forward a stale assumption. The larger the codebase, the worse this gets.

The standard response to this is better prompting — more detailed instructions, more examples, more explicit reminders of what the model is supposed to be doing. This helps at the margins but does not fix the underlying problem, which is structural. The LLM has no grounding in the actual state of your repository. It is reasoning about code in the abstract, and the gap between its internal model and reality widens with every turn of the conversation.

Team of Six (TOS) takes a different approach. Rather than asking the LLM to be more careful, it builds an infrastructure layer that makes carelessness structurally impossible. The LLM cannot write code to the wrong branch because the system will not execute a payload that declares the wrong context. It cannot lose track of what it is working on because every workspace transition regenerates the full context from the source of truth. It cannot hallucinate file state because it never has direct filesystem access — every mutation passes through a validated protocol boundary.

TOS is not a chat interface. It is not a prompt library. It is an execution engine: a set of shell scripts, a locking protocol, a plaintext IPC format, and a gateway that enforces rules the LLM cannot override.

---

## Who This Is For

TOS is built for developers who want to work *with* an LLM as a genuine collaborator on a real codebase — not for generating isolated snippets, but for driving a full development lifecycle from issue scoping through code review to merge. It assumes you are comfortable with the command line, familiar with Git and GitHub, and willing to invest in understanding a new workflow in exchange for a qualitatively different level of AI reliability.

The learning curve is real. TOS introduces concepts — the Trinity, the IPC ribbon, the lock hierarchy — that have no direct equivalent in standard development practice. This documentation is written to explain each of those concepts from first principles, in the order you will need them.

---

## How to Read This Documentation

The documents are designed to be read in sequence. Each one builds on the last. If you skip ahead, you will encounter references to concepts that have not been introduced yet.

| Document | What It Covers |
|----------|---------------|
| [01-llm-pitfalls.md](docs/01-llm-pitfalls.md) | The specific failure modes of modern LLMs in development contexts, and why prompt engineering alone cannot fix them |
| [02-architecture.md](docs/02-architecture.md) | How TOS is structured: the gateway, the module system, the IPC boundary, and how the pieces fit together |
| [03-trinity.md](docs/03-trinity.md) | The Contextual Trinity — the 1:1:1 mandate, the lock hierarchy, and how workspace phases are enforced |
| [04-protocol.md](docs/04-protocol.md) | The plaintext IPC protocol: payload block formats, the inbox/outbox model, and validation |
| [05-workflow.md](docs/05-workflow.md) | The complete development lifecycle: from provisioning a sandbox to merging a pull request |
| [06-security.md](docs/06-security.md) | The trust model, the sudo gateway, multi-tenant isolation, and the control plane layout |
| [07-neovim-plugin.md](docs/07-neovim-plugin.md) | IDE integration: how the Neovim plugin closes the last manual step in the workflow |
| [08-agentic-unleash.md](docs/08-agentic-unleash.md) | Advanced usage: running autonomous agents within TOS constraints |

---

## Quick Orientation

TOS is organized around three roles that may be played by a human, an LLM, or both depending on your workflow:

- **The Architect** — the human developer. Owns the repository, reviews work, makes final decisions.
- **The Ghost** — the AI agent. Operates inside a locked, isolated sandbox. Produces payloads. Never touches the repository directly.
- **The Gateway** — the enforcement layer. Validates every operation before it executes. Neither the Architect nor the Ghost can bypass it.

The fundamental unit of work is the **Trinity**: one GitHub issue, one branch, one feature. The system enforces this at the lock level. The Ghost cannot be in two trinities at once, and it cannot write code outside of an active hard-lock context.

---

## Installation

See [06-security.md](docs/06-security.md) for full deployment instructions including the `inf/tos_deploy.sh` script, user provisioning, and sudoers configuration.

---

## Repository Layout

```
team_of_six/
├── bin/
│   ├── tos               # The Global Gateway
│   ├── sync/             # Workspace lifecycle commands
│   ├── write/            # Mutation commands (issues, code, comments)
│   ├── system/           # Meta-operations
│   └── utils/
│       ├── lock/         # Atomic lock management scripts
│       ├── error_trap.sh
│       └── parse_blocks.sh
├── conf/
│   └── config            # Global configuration (paths, users, groups)
├── docs/                 # This documentation
├── inf/                  # Deployment and provisioning scripts
├── llm_agents/           # Agent rule files (committed to repo, evolved by Ghost)
├── plugins/
│   └── neovim/           # Neovim integration plugin
└── test/
    └── interactive_tutorial.zsh
```
