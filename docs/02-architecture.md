← [01-theSocialContract.md](01-theSocialContract.md) | Next: [03-trinity.md](03-trinity.md) →

---

# 02 — Architecture

This document describes how TOS is structured: the major components, the boundaries between them, and why each design decision was made. By the end you should have a clear mental model of how a command travels from the Architect's terminal through the system to GitHub, and what happens at each step.

---

## The Three Roles

Every operation in TOS involves three conceptual actors. Understanding their separation is prerequisite to understanding the architecture.

**The Architect** is the human developer. The Architect owns the repository, initiates commands, reviews output, approves Intent Locks, and makes all final decisions. The Architect operates in their normal user account on the development machine. They do not have direct access to the Ghost's sandbox or the control plane.

**The Ghost** is the AI agent — specifically, the `team_of_six` system user under which all privileged operations execute. When you run `tos myproject write code`, your command is escalated via `sudo` to run as the Ghost. The Ghost has access to the sandbox, the IPC ribbon, and the GitHub token. The Ghost never interacts with the LLM directly — it executes validated payloads that the LLM produced. The LLM is explicitly untrusted; its output is treated as hostile input until the gateway validates it.

**The Gateway** is `bin/tos.zsh`. It is the single entry point for every TOS operation. Nothing in the system executes without passing through the gateway first. The gateway enforces access control, validates context, checks Intent Locks, enforces destructive gates, and dispatches to the appropriate module. Neither the Architect nor the Ghost can bypass it.

This separation creates a hard trust boundary: the Architect interacts with the Gateway, the Gateway decides what the Ghost is allowed to do, and the Ghost executes within those constraints.

---

## The Control Plane

The control plane lives at `${TOS_MNT_ROOT}/` — a dedicated mount point distinct from any individual Architect's home directory. It is shared infrastructure structured to support multiple Architects working simultaneously.

```
${TOS_MNT_ROOT}/
├── .ipc/
│   ├── locks/                    # Lock files AND .manifest visas (mode 0700, Ghost-exclusive)
│   │   ├── <project>_trinity_<N>.lock
│   │   └── <project>_trinity_<N>.manifest
│   └── <architect>/              # Per-Architect IPC ribbon (mode 3770, setgid)
│       ├── inbox.md              # Architect writes payloads here directly
│       └── outbox.md             # Ghost writes here; Architect reads only
├── .local/
│   ├── bin/                      # Deployed TOS binaries (mode 0750)
│   └── conf/
│       ├── config                # Global configuration
│       └── .token                # GitHub token (mode 0400, Ghost-only)
└── sandbox/
    └── <architect>/
        └── <project>/            # Isolated Git clone (mode 0700, Ghost-exclusive)
```

The `locks/` directory is the heartbeat of the system. Every active working context corresponds to a lock file here. Critically, this is also where the **Locked Manifest** lives: `<project>_trinity_<N>.manifest` is a physical visa file listing the exact set of files the Agent is authorised to mutate in the current Trinity. Because this directory is mode `0700` and owned exclusively by the Ghost, the Architect cannot edit or bypass the visa from their own account — the only way to create or change it is through the formal `write plan` gateway command.

---

## The Five-Phase Module Taxonomy

TOS commands follow the structure `tos <project> <module> <action>`. The lifecycle is divided into five phases, each with its own module:

**`create`** — Inception. Generating the foundational remote truth on GitHub. Actions: `project`, `trinity`, `issue`.

**`sync`** — Alignment. Workspace lifecycle management. Getting into a working context, checking out branches, generating the Clean Room Snapshot. Actions: `start`, `trinity`, `peek`.

**`write`** — Mutation. Operations that change state. Actions: `plan` (Intent Lock), `code` (file mutation and commit), `comment` (GitHub thread), `trinity` (MANIFEST-verified closure).

**`close`** — Finality. Graceful teardown. Squash-merging PRs, closing issues, removing local sandbox state without destroying remote history. Actions: `project`, `trinity`.

**`delete`** — Purge. Nuclear operations requiring explicit CONFIRM and out-of-band MFA. Scrubbing issue history, wiping repositories. Actions: `project`, `trinity`.

Each module lives under `bin/modules/<module>/` with `soft/` and `hard/` subdirectories. The script's physical location is the sole authority on what lock tier is required. The gateway discovers actions dynamically from the filesystem — adding a new action requires only creating a script file; no gateway changes are needed.

---

## The Gateway in Detail

When you type `tos myproject write code`, the following sequence occurs:

**Stage 1 — Security Perimeter.** The gateway checks whether you are the `team_of_six` system user. If not, it verifies group membership and escalates via `sudo -n -u team_of_six`. If escalation fails, you see "The Threshold is sealed." On success, it sets `TOS_CONTROLLER_LOCKED=true` — every module script checks this variable as its first line and refuses to execute without it, making direct invocation impossible.

**Stage 2 — Configuration & Token Injection.** Sources the global config. Loads `GH_TOKEN` from the `0400` token file. Registers an `EXIT/INT/TERM` trap that scrubs both token variables and cleans all temporary directories — the token is never left in the environment after the gateway exits, regardless of exit path.

**Stage 3 — Argument Parsing & Caller Location Verification.** Parses `<project> <module> <action>`. Verifies that `git remote get-url origin` matches the declared project name. A mismatch causes immediate rejection. This enforces that `tos` is always called from within the correct project directory root.

**Stage 4 — Active Trinity Resolution.** Derives `TOS_ACTIVE_TRINITY` by grepping lock files in the control plane for `SUDO_USER:HARD_LOCK`. Nothing is read from the sandbox. Zero proprietary pollution.

**Stage 5 — Filesystem-Driven Dispatch & Lock Enforcement.** Discovers the target script from `modules/<module>/soft/` or `modules/<module>/hard/`. If the script is in `hard/` and `TOS_ACTIVE_TRINITY == 0`, the command is rejected. For `write code`, an additional check cross-references every declared file path against the active `.manifest` visa in the control plane. Any file not listed in the visa causes a `SEC-FAULT` rejection before a single byte is written to the sandbox.

**Stage 6 — Inbox Truncation.** Immediately after parsing the payload, the inbox is truncated to zero bytes. This is the **Inbox Truncation Invariant** (ADR: Exact-Once Execution). If any subsequent operation fails, the payload is deliberately gone. The Architect must resubmit. This prevents duplicate commits, duplicate issue creation, and duplicate API calls on retry.

**Stage 7 — Execution.** The target script is executed, with all output piped through `tee` to the Architect's outbox. Every command's complete output is always recoverable from the outbox.

---

## The IPC Boundary

The IPC boundary is the most important architectural feature of TOS for understanding how the LLM integrates into the system. The LLM never calls TOS commands directly. It produces structured plaintext payloads in a defined block format, which the Architect (or the Neovim plugin) writes to the inbox. The Ghost reads the inbox and executes the declared operations.

This indirection serves several purposes. Every LLM output is inspectable before it executes — the payload sits in the inbox as a file the Architect can read, modify, or delete. It forces the LLM to be explicit: a payload that does not declare a target file cannot create a file; a payload targeting a file outside its approved `.manifest` visa is blocked. And it creates an audit trail — every payload's output is written to the outbox by the gateway's tee pipe.

Any `close` or `delete` operation adds a further layer: the gateway checks the `TOS_META` block for the exact string `CONFIRM=TRUE` before evaluating any further logic. Absence of this string causes an immediate, loud abort. This is the **HITL Destructive Gate**.

The payload protocol is described in detail in [04-protocol.md](04-protocol.md).

---

## Why Shell Scripts

TOS is implemented in Zsh shell scripts rather than a compiled language or higher-level runtime. Shell scripts are universally available without dependency installation, compose naturally with Git and the GitHub CLI, are trivially auditable, and have zero startup overhead. Every TOS command is a series of filesystem operations, Git commands, and GitHub API calls — the natural domain of shell.

The one acknowledged exception is `export_parsers.zsh`, which currently uses `python3` for JSON merging. This is flagged as legacy technical debt in `inf/tos_deploy.zsh` and is slated for replacement with a native implementation, restoring full ADR compliance.

---

← [01-theSocialContract.md](01-theSocialContract.md) | Next: [03-trinity.md](03-trinity.md) →
