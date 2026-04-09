← [01-llm-pitfalls.md](01-llm-pitfalls.md) | Next: [03-trinity.md](03-trinity.md) →

---

# 02 — Architecture

This document describes how TOS is structured: the major components, the boundaries between them, and why each design decision was made. By the end you should have a clear mental model of how a command travels from the Architect's terminal through the system to GitHub, and what happens at each step.

---

## The Three Roles

Every operation in TOS involves three conceptual actors. Understanding their separation is prerequisite to understanding the architecture.

**The Architect** is the human developer. The Architect owns the repository, initiates commands, reviews output, and makes all final decisions. The Architect operates in their normal user account on the development machine. They do not have direct access to the Ghost's sandbox or the control plane.

**The Ghost** is the AI agent — specifically, the `team_of_six` system user under which all privileged operations execute. When you run `tos myproject write code`, your command is escalated via `sudo` to run as the Ghost. The Ghost has access to the sandbox, the IPC ribbon, and the GitHub token. The Ghost never interacts with the LLM directly — it executes validated payloads that the LLM produced.

**The Gateway** is the `bin/tos` script. It is the single entry point for every TOS operation. Nothing in the system executes without passing through the gateway first. The gateway enforces access control, validates context, enforces lock policies, and dispatches to the appropriate module. Neither the Architect nor the Ghost can bypass it.

This separation is not merely organisational. It creates a hard trust boundary: the Architect interacts with the Gateway, the Gateway decides what the Ghost is allowed to do, and the Ghost executes within those constraints. The LLM's output never executes directly — it is always mediated by the Ghost executing a validated payload.

---

## The Control Plane

The control plane lives at `/mnt/team_of_six/` — a dedicated mount point that is distinct from any individual Architect's home directory or project workspace. This separation is intentional: the control plane is shared infrastructure, owned by the `team_of_six` system user, and structured to support multiple Architects working on multiple projects simultaneously.

```
/mnt/team_of_six/
├── .ipc/
│   ├── locks/            # Persistent lock files for all active sessions
│   ├── <architect>/      # Per-Architect IPC ribbon
│   │   ├── inbox.md      # Payloads written here by the Architect/LLM
│   │   └── outbox.md     # Context and output written here by the Ghost
├── .local/
│   ├── bin/              # The deployed TOS binaries
│   └── conf/             # Configuration and the GitHub token
└── sandbox/
    └── <architect>/      # Per-Architect project sandboxes
        └── <project>/    # Isolated Git clone of the repository
```

The `locks/` directory is the heartbeat of the system. Every active working context corresponds to a lock file here. The gateway reads these files on every invocation to determine what is allowed.

The `sandbox/` directory contains the Ghost's working copies of repositories. These are plain Git clones, but they are owned by the Ghost and isolated from the Architect's own checkouts. The Ghost makes commits, pushes branches, and reads file state from the sandbox. It never touches the Architect's working tree.

---

## The Module System

TOS commands are structured as `tos <project> <module> <action>`. The three modules are:

**`sync`** — workspace lifecycle management. Getting into a working context, transitioning between trinities, provisioning sandboxes, and merging completed work. These commands manage the relationship between the Ghost's local state and the remote repository.

**`write`** — mutation operations. Creating GitHub issues, committing code changes, posting comments. These commands change the state of the repository or its associated GitHub resources.

**`system`** — meta-operations. Exporting parser configurations, administrative tasks. These commands operate on the TOS infrastructure itself rather than on a project.

Each module has its own directory under `bin/` with a `tos` router script that dispatches to individual action scripts. The main gateway dispatches to the module router; the module router dispatches to the action. This two-level dispatch keeps each file small and focused, and makes it straightforward to add new actions to an existing module without touching anything outside that module's directory.

The `utils/` directory sits outside the module system. It contains scripts that are called directly by other scripts — never by users, never by the gateway. The lock management scripts live here, as does the payload parser and the error trap. Utils have no routers because they have no user-facing interface.

---

## The Gateway in Detail

When you type `tos myproject write code`, the following sequence occurs:

**Stage 1 — The Bouncer.** The gateway checks whether you are running as the `team_of_six` system user. If you are not (which is the normal case — you are running as your own user), it checks that you are a member of the `team_of_six` group. If you are not in the group, you are rejected immediately with an access denied message. If you are in the group, it escalates the command via `sudo -n -u team_of_six` — that is, it re-executes the entire command as the Ghost, without a password prompt, relying on the sudoers configuration installed during deployment. If the sudo escalation fails for any reason, you see "The Threshold is sealed."

**Stage 2 — The Ghost.** Now executing as `team_of_six`, the gateway verifies that `SUDO_USER` is defined (confirming this was a legitimate escalation rather than a direct login), sources the error trap, and parses the project name and module from the arguments.

**Stage 3 — The Workspace Safety Audit.** Before any command executes, the gateway scans every project directory in this Architect's sandbox and verifies that a lock file exists for that project owned by this Architect personally. If any project is found without a personal lock, the gateway exits immediately with an error. This check exists because a project in the sandbox without a lock indicates either a system error or manual manipulation — both of which represent a context integrity risk. The remedy message tells the Architect exactly what to run to restore a clean state.

**Stage 4 — Write Policy Enforcement.** If the module is `write`, the gateway applies additional checks. It determines the active lock type (soft or hard) and applies the write policy: a soft-lock (Trinity 0) permits task creation and comments but blocks code commits. A hard-lock permits everything. It then reads the payload from the inbox and extracts any `TARGET_PROJECT` and `TARGET_TRINITY` declarations, validating them against the actual system state. Finally it calls `verify.zsh` to confirm this Architect personally owns the active lock.

**Stage 5 — Dispatch.** The command is dispatched to the appropriate module router, with all output piped through `tee` to the outbox. This means the Ghost's output is always written to the IPC ribbon, where the Architect can read it and where it will be included in the next Clean Room Snapshot.

---

## The IPC Boundary

The IPC boundary is the most important architectural feature of TOS for understanding how the LLM integrates into the system. The LLM never calls TOS commands directly. It produces structured plaintext payloads in a defined block format, which the Architect (or the Neovim plugin) writes to the inbox file. The Ghost reads the inbox and executes the declared operations.

This indirection is not accidental overhead. It serves several purposes:

First, it makes every LLM output inspectable before it executes. The payload sits in the inbox as a file. The Architect can read it, modify it, or delete it. Nothing happens until `tos` is called.

Second, it forces the LLM to be explicit about its intent. A payload that does not declare a target file cannot create a file. A payload that does not declare a target trinity will be assigned the active lock's trinity. The LLM cannot act implicitly — it must state what it intends to do in a machine-parseable format.

Third, it creates an audit trail. Every payload that passed through the inbox is preserved in the outbox (since the Gateway tees all output there). The history of what the Ghost did and why is always recoverable.

The payload protocol is described in detail in [04-protocol.md](04-protocol.md).

---

## Why Shell Scripts

TOS is implemented in Zsh shell scripts rather than a compiled language or a higher-level runtime. This is a deliberate choice with trade-offs in both directions.

The benefits: shell scripts are universally available on any Unix-like system without dependency installation, they compose naturally with Git and the GitHub CLI (`gh`), they are trivially auditable by a developer who wants to understand exactly what a command does, and they have zero startup overhead. Every TOS command is a series of filesystem operations, Git commands, and GitHub API calls — the natural domain of shell.

The costs are the ones you would expect: limited error handling, no type system, the race condition in the lock acquisition that is acknowledged but not mechanically fixed, and the lack of a schema validator for the payload format (identified as a future improvement — a language-specific LSP-driven validator would close this gap properly).

---

← [01-llm-pitfalls.md](01-llm-pitfalls.md) | Next: [03-trinity.md](03-trinity.md) →
