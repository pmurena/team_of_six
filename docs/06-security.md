← [05-workflow.md](05-workflow.md) | Next: [07-neovim-plugin.md](07-neovim-plugin.md) →

---

# 06 — Security and Deployment

This document covers the trust model underlying TOS, the mechanisms that enforce it, the recovery doctrines that govern failure, and the steps required to deploy a working TOS installation.

---

## The Trust Model

TOS operates on a principle of layered, explicit trust. No component trusts any other component unconditionally.

**The Architect is trusted to initiate commands** but not to execute them directly. The Architect triggers the Gateway. The Gateway decides whether to honour the request.

**The Gateway is trusted to enforce policy** but not to originate operations. The Gateway validates, dispatches, and audits. It enforces lock tiers, manifest visas, hallucination checks, the Inbox Truncation Invariant, and destructive gates.

**The Ghost is trusted to execute validated operations** but not to receive unmediated input from the LLM. The Ghost executes payloads that have passed every gateway check.

**The LLM is not trusted.** Its output is treated as hostile input. Every payload is checked against ground truth, active locks, and manifest visas before any change occurs. This is not a statement about the LLM's capability — it is an acknowledgement that the LLM has no grounding in the actual system state and may produce output that is confidently wrong.

---

## The Sudo Gateway

The privilege separation between Architect and Ghost is enforced by `sudo`. The `tos` binary runs as the Architect's user. When it determines the user is not `team_of_six`, it re-executes itself via:

```zsh
sudo -n -u team_of_six "$TOS_BIN/tos.zsh" "$@"
```

The `-n` flag means non-interactive — if the sudo call requires a password, it fails immediately. TOS operations never require manual password entry. The permission is granted unconditionally to `team_of_six` group members via the sudoers entry installed by `inf/tos_add_user.zsh`:

```
%team_of_six ALL=(team_of_six) NOPASSWD: /mnt/team_of_six/.local/bin/tos.zsh
```

This grants group members the ability to run exactly one binary — the TOS gateway — as the Ghost. Nothing else. An Architect cannot use this permission to run arbitrary commands.

The gateway sets `TOS_CONTROLLER_LOCKED=true` after successful escalation. Every module script checks this variable as its first line and exits immediately if it is not set. Direct invocation of any module script, bypassing the gateway, is therefore inert.

---

## The Control Plane Layout

```
/mnt/team_of_six/                   owned: root:team_of_six        mode: 0750
├── .ipc/
│   ├── locks/                      owned: team_of_six:team_of_six  mode: 0700
│   │   ├── <project>_trinity_<N>.lock
│   │   └── <project>_trinity_<N>.manifest   # Intent Lock visa
│   └── <architect>/                owned: team_of_six:team_of_six  mode: 3770
│       ├── inbox.md                owned: <architect>:team_of_six  mode: 0660
│       └── outbox.md               owned: team_of_six:team_of_six  mode: 0660
├── .local/
│   ├── bin/                        owned: team_of_six:team_of_six  mode: 0750
│   └── conf/
│       ├── config                  owned: team_of_six:team_of_six  mode: 0640
│       └── .token                  owned: team_of_six:team_of_six  mode: 0400
└── sandbox/
    └── <architect>/                owned: team_of_six:team_of_six  mode: 0700
```

Several design decisions are visible in these permissions:

The **inbox** is owned by the Architect, allowing them to write payloads directly without escalation. The Ghost can read it because both share the `team_of_six` group.

The **outbox** is owned by the Ghost. The Architect can read it but cannot write to it directly. This prevents forged outbox content.

The **locks directory** is mode `0700` — Ghost-exclusive. This is where the `.manifest` visa lives. The Architect cannot edit or delete the visa from their own account without going through the formal `write plan` gateway command. The blast radius approved by the Architect via `write plan` is mechanically immutable from the Architect's perspective until the next `write plan` or Trinity finalization.

The **sandbox** is mode `0700`, not even group-readable. The Architect cannot directly read or write the Ghost's working files. All interaction goes through the gateway.

The **`.token` file** is mode `0400` — Ghost-only. The GitHub token is loaded into the environment by the gateway and scrubbed via a registered `EXIT/INT/TERM` trap before the gateway exits. It is never written to any log, outbox, or temporary file.

The **IPC ribbon directories** use setgid (`3770`) so that files created within them inherit the `team_of_six` group regardless of which user creates them.

---

## The HITL Destructive Gate (CONFIRM=TRUE)

The `close` and `delete` modules are placed behind a hard mechanical gate. The gateway checks the `TOS_META` payload for the exact string `CONFIRM=TRUE` before evaluating any further logic. Its absence causes an immediate abort with a loud security warning.

This catches the most dangerous class of LLM failure: a confused or stale Agent that hallucinates a destructive command. The Agent must explicitly write `CONFIRM=TRUE` in its payload — it cannot do this accidentally or by drift, because the string has no plausible role in any non-destructive operation.

---

## PAT MFA Isolation

The Ghost's `.token` file must **not** carry `delete_repo` OAuth scope. This is a deployment requirement enforced by documentation and validated by the deploy script.

When `tos <project> delete project` is called, the system hits a deliberate privilege boundary. The command triggers:

```zsh
gh auth refresh -s delete_repo
```

Because `tos` runs via `sudo -n` (non-interactive), this OAuth flow requires a human to open a browser and complete interactive authentication. An automated process — a runaway agent, a script, an accidentally chained command — cannot complete this step. This is out-of-band Multi-Factor Authentication for the nuclear operation.

The elevated scope is revoked immediately after use. The gateway's `EXIT` trap calls:

```zsh
gh auth refresh --remove-scopes delete_repo
```

This trap fires on every exit path — success, failure, and interrupt — so the token is never left in an elevated state, regardless of what happens after the escalation.

---

## The Out-of-Band Recovery Doctrine

TOS is designed with a strict **no automated self-healing** doctrine.

If the Atomic Handover encounters a `git push` rejection — a remote merge conflict, a force-push protection, a network failure — the system halts immediately. It logs the complete Git error to the outbox. It does not attempt to `git pull --rebase`, resolve the conflict, or retry the push.

Automated conflict resolution violates the physical isolation barrier: the Ghost would be making decisions about repository state that belong to the Architect. It also creates unauditable state changes — the Architect would see a clean outbox with no record of what the Ghost decided.

The recovery path is always explicit Architect action:

- Read the outbox to understand what failed and why.
- If the work is safe on the remote, run `sync trinity <N>` to re-align the sandbox to the remote state.
- If the Trinity needs to be abandoned cleanly, run `close trinity` to release the lock and return to Trinity 0.
- If the conflict must be resolved on GitHub's remote interface, do so, then re-run `sync trinity`.

The system's state is always recoverable. The Ghost never silently changes state.

---

## Multi-Tenant Operation

Multiple Architects can work simultaneously on the same machine and, within a project, on different trinities.

- Each Architect has their own IPC ribbon and sandbox.
- Lock files encode the owning Architect — multiple Architects can hold locks on the same project on different trinities simultaneously.
- A hard lock is exclusive per trinity: Architect A holding Trinity 3 blocks Architect B from acquiring Trinity 3 until A releases it.
- The `.manifest` visa is scoped to the lock: `<project>_trinity_<N>.manifest` belongs to whichever Architect holds the hard lock on Trinity N.

There is an acknowledged narrow race condition in `acquire.zsh` between the contention check and the lock write. This is not mechanically closed — `flock(2)` complexity is not warranted on a single-machine multi-user setup where the collision window is negligible and GitHub branch protection provides the ultimate serialisation.

---

## Deployment

**Step 1 — Run the deployment script as root:**

```zsh
sudo ./inf/tos_deploy.zsh
```

This script creates the `team_of_six` system user and group, provisions the control plane directory structure with correct permissions, copies TOS binaries via `rsync --delete`, prompts for the GitHub token, and automatically runs `inf/tos_add_user.zsh` for the deploying user.

**Step 2 — Install the GitHub token:**

```zsh
sudo -u team_of_six tee /mnt/team_of_six/.local/conf/.token <<< "your-token-here"
sudo chmod 0400 /mnt/team_of_six/.local/conf/.token
```

The token must have repository and issue permissions. It must **not** have `delete_repo` scope — that scope is acquired interactively only when needed and revoked immediately after.

**Step 3 — Add Architects:**

```zsh
sudo ./inf/tos_add_user.zsh <username>
```

This adds the user to the `team_of_six` group, provisions their IPC ribbon, creates their sandbox directory, and installs the sudoers entry validated via `visudo -c`. The user must log out and back in for group membership to take effect.

**Step 4 — Verify:**

```zsh
tos --help
```

If the gateway runs and shows the usage message, the installation is working.

---

## Post-Session Cleanup

After a tutorial or test session, run:

```zsh
sudo ./inf/post_test_cleanup.zsh
```

This acquires the `delete_repo` scope interactively, deletes test repositories from GitHub, removes local and sandbox directories, and offers to revoke the elevated scope on exit.

---

← [05-workflow.md](05-workflow.md) | Next: [07-neovim-plugin.md](07-neovim-plugin.md) →
