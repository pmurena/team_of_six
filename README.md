# Team of Six

> *A secure, multi-tenant execution engine for AI-assisted software development.*

---

## The Problem This Solves

Large Language Models are remarkably capable at reasoning about code. They can explain architecture, suggest refactors, write tests, and implement features — often faster and more fluently than a human working alone. But anyone who has tried to use an LLM as a genuine development partner rather than a one-shot query tool has run into the same wall: the LLM drifts. It loses track of what file it was editing. It invents function signatures that do not exist. It confidently implements the wrong feature because three messages ago the conversation shifted and the model carried forward a stale assumption. The larger the codebase, the worse this gets.

The standard response to this is better prompting — more detailed instructions, more examples, more explicit reminders of what the model is supposed to be doing. This helps at the margins but does not fix the underlying problem, which is structural. The LLM has no grounding in the actual state of your repository. It is reasoning about code in the abstract, and the gap between its internal model and reality widens with every turn of the conversation.

Team of Six (TOS) takes a different approach. Rather than asking the LLM to be more careful, it builds an infrastructure layer that makes carelessness structurally impossible. The LLM cannot write code to the wrong branch because the system will not execute a payload that declares the wrong context. It cannot write rogue files because it must secure an explicit **Intent Lock (Manifest Visa)** approved by the Architect *before* write access is granted. It cannot lose track of what it is working on because every workspace transition regenerates the full context from the authoritative source of truth — the Git repository itself.

TOS is not a chat interface. It is not a prompt library. It is an execution engine: a set of shell scripts, a locking protocol, a plaintext IPC format, and a gateway that enforces rules the LLM cannot override.

---

## The Foundational Principle

**The code is the truth.** Documentation describes intent and rationale. The Agent derives all domain rules from the actual codebase delivered by the Clean Room Snapshot — not from prose summaries of it. When documentation and code conflict, the code wins. The Retrospective phase exists to close that gap by updating documentation to reflect what was actually built.

This principle is not advisory. It is encoded in the Agent rulefile (`llm_agents/code.md`) and enforced by the workflow.

---

## Who This Is For

TOS is built for developers who want to work *with* an LLM as a genuine collaborator on a real codebase — not for generating isolated snippets, but for driving a full development lifecycle from issue scoping through code review to merge. It assumes you are comfortable with the command line, familiar with Git and GitHub, and willing to invest in understanding a new workflow in exchange for a qualitatively different level of AI reliability.

The learning curve is real. TOS introduces concepts — the Trinity, the IPC ribbon, the Intent Lock, the five-phase lifecycle — that have no direct equivalent in standard development practice. This documentation is written to explain each of those concepts from first principles, in the order you will need them.

---

## How to Read This Documentation

The documents are designed to be read in sequence. Each one builds on the last.

| Document | What It Covers |
|----------|----------------|
| [00-llm-pitfalls.md](docs/00-llm-pitfalls.md) | The specific failure modes of modern LLMs in development contexts, and why prompt engineering alone cannot fix them |
| [01-theSocialContract.md](docs/01-theSocialContract.md) | The trimodal team — Architect, Agent, Ghost — their roles, trust levels, and the "1 becomes 6" premise |
| [02-architecture.md](docs/02-architecture.md) | How TOS is structured: the gateway, the five-phase module system, the IPC boundary, and how the pieces fit together |
| [03-trinity.md](docs/03-trinity.md) | The Contextual Trinity — the 1:1:1 mandate, the lock hierarchy, and how workspace phases are enforced |
| [04-protocol.md](docs/04-protocol.md) | The plaintext IPC protocol: all payload block formats, the Intent Lock, and the `CONFIRM=TRUE` destructive gate |
| [05-workflow.md](docs/05-workflow.md) | The complete development lifecycle across all five phases: create, sync, write, close, delete |
| [06-security.md](docs/06-security.md) | The trust model, PAT MFA isolation, the Out-of-Band Recovery Doctrine, and the control plane layout |
| [07-neovim-plugin.md](docs/07-neovim-plugin.md) | IDE integration: how the Neovim plugin eliminates the last manual steps in the workflow |
| [08-agentic-unleash.md](docs/08-agentic-unleash.md) | Advanced usage: autonomous debugging loops, multi-file refactoring, and the self-improving agent |

---

## Quick Orientation

TOS is organised around three roles:

- **The Architect** — the human developer. Owns the repository, reviews all work, approves Intent Locks, and makes every final decision. The system is only as reliable as the Architect is skeptical.
- **The Ghost** — the AI agent. Operates inside a locked, isolated sandbox. Produces structured plaintext payloads. Never touches the repository directly. Explicitly untrusted.
- **The Gateway** — the enforcement layer. Validates every operation before it executes. Enforces lock tiers, manifest visas, hallucination checks, and destructive gates. Cannot be bypassed by either role.

The fundamental unit of work is the **Trinity**: one GitHub issue, one branch, one feature. The Ghost cannot be in two trinities at once, and it cannot write code outside of an active hard-lock context that has an approved Manifest Visa.

---

## Installation

See [06-security.md](docs/06-security.md) for full deployment instructions, including the `inf/tos_deploy.zsh` script, user provisioning, and sudoers configuration.

---

## Repository Layout

```
team_of_six/
├── bin/
│   ├── tos.zsh               # The Global Gateway
│   └── modules/
│       ├── create/           # Inception phase (project, trinity, issue)
│       ├── sync/             # Alignment phase (start, trinity, peek)
│       ├── write/            # Mutation phase (plan, code, comment, trinity)
│       ├── close/            # Finality phase (project, trinity)
│       └── delete/           # Purge phase (project, trinity)
├── bin/utils/
│   ├── lock/                 # Atomic lock management (acquire, release, verify, status)
│   ├── error_trap.zsh
│   ├── export_parsers.zsh
│   └── parse_blocks.zsh
├── conf/
│   └── config                # Global configuration (paths, users, groups)
├── docs/                     # This documentation
├── governance/
│   └── adr.md                # Architectural Decision Records
├── inf/                      # Deployment and provisioning scripts
├── llm_agents/
│   └── code.md               # Agent rulefile — committed, versioned, evolved by Retrospective
├── plugins/
│   └── neovim/               # Neovim integration plugin
└── test/
    └── interactive_tutorial.zsh
```
