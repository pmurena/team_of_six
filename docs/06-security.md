← [05-workflow.md](05-workflow.md) | Next: [07-neovim-plugin.md](07-neovim-plugin.md) →

---

# 06 — Security and Deployment

This document covers the trust model underlying TOS, the mechanisms that enforce it, and the steps required to deploy a working TOS installation. It also documents the multi-tenant design for teams where multiple Architects share the same machine.

---

## The Trust Model

TOS operates on a principle of layered, explicit trust. No component trusts any other component unconditionally. The layers are:

**The Architect is trusted to initiate commands** but not to execute them directly. When an Architect runs `tos`, they are requesting that the Gateway perform an operation on their behalf. The Gateway decides whether to honour that request.

**The Gateway is trusted to enforce policy** but not to originate operations. The Gateway validates, dispatches, and audits. It does not produce payloads or make decisions about what should be done — only whether a requested operation is permitted.

**The Ghost is trusted to execute validated operations** but not to receive unmediated input from the LLM. The Ghost executes payloads that have passed gateway validation. It never receives raw LLM output directly.

**The LLM is not trusted.** Its output is treated as untrusted input to be validated before execution. This is not a statement about the capability of the LLM — it is an acknowledgement that the LLM has no grounding in the actual system state and may produce output that is confidently wrong. Every payload is checked against ground truth before it causes any change.

---

## The Sudo Gateway

The mechanism that enforces the separation between Architect and Ghost is `sudo`. The `tos` binary runs as the Architect's user. When it reaches Stage 1 of the gateway and determines that the user is not `team_of_six`, it re-executes itself via:

```zsh
sudo -n -u team_of_six "$TOS_BIN/tos" "$@"
```

The `-n` flag means non-interactive: if the sudo call requires a password, it fails immediately rather than prompting. This is intentional. TOS operations should never require manual password entry — the permission is granted unconditionally to members of the `team_of_six` group via the sudoers configuration, or not at all.

The sudoers entry, installed by `inf/tos_add_user.sh`, takes the form:

```
%team_of_six ALL=(team_of_six) NOPASSWD: /mnt/team_of_six/.local/bin/tos
```

This grants members of the `team_of_six` group the ability to run exactly one binary — the TOS gateway — as the `team_of_six` user, without a password. Nothing else. An Architect cannot use this sudo permission to run arbitrary commands as the Ghost.

The gateway itself then checks `SUDO_USER` — the environment variable `sudo` sets to the original user's name — to determine who initiated the escalation. Every subsequent permission check (lock ownership, hallucination validation) uses `SUDO_USER` rather than the current effective user. This means the Ghost always knows which Architect made the request, even though it is running as `team_of_six`.

---

## The Control Plane Layout

The control plane at `/mnt/team_of_six/` is structured for multi-tenant operation. Key ownership and permission boundaries:

```
/mnt/team_of_six/                   owned: team_of_six:team_of_six  mode: 0750
├── .ipc/
│   ├── locks/                      owned: team_of_six:team_of_six  mode: 0770
│   └── <architect>/                owned: team_of_six:team_of_six  mode: 3770
│       ├── inbox.md                owned: <architect>:team_of_six  mode: 0660
│       └── outbox.md              owned: team_of_six:team_of_six  mode: 0660
├── .local/
│   ├── bin/                        owned: team_of_six:team_of_six  mode: 0750
│   └── conf/
│       ├── config                  owned: team_of_six:team_of_six  mode: 0640
│       └── .token                  owned: team_of_six:team_of_six  mode: 0400
└── sandbox/
    └── <architect>/                owned: team_of_six:team_of_six  mode: 0700
```

Several design decisions are visible in these permissions:

The **inbox** is owned by the Architect (not the Ghost), allowing the Architect to write payloads to it directly without escalation. The Ghost can read it because both are in the `team_of_six` group and the file is group-readable.

The **outbox** is owned by the Ghost. The Architect can read it (group-readable) but cannot write to it directly. This prevents an Architect from forging outbox content.

The **sandbox** is owned by the Ghost and mode 0700 — not even group-readable. The Architect cannot directly read or write the Ghost's working files. All interaction goes through the gateway.

The **`.token` file** is mode 0400, readable only by the Ghost. The GitHub token is never accessible to any Architect directly. It is injected into the environment by the gateway at execution time and unset before the gateway exits.

The **IPC ribbon directories** use setgid (mode 3770) so that files created within them inherit the `team_of_six` group regardless of which user creates them.

---

## Multi-Tenant Operation

Multiple Architects can work simultaneously on the same machine and, within a project, on different trinities. The lock system is designed to support this:

- Each Architect has their own IPC ribbon (`inbox.md`, `outbox.md`) under their named directory in `.ipc/`
- Each Architect has their own sandbox under `sandbox/<architect>/`
- Lock files in `.ipc/locks/` encode the owning Architect in their content, allowing multiple Architects to hold locks on the same project (on different trinities)
- A hard lock is exclusive per trinity: if Architect A holds the hard lock on Trinity 3, Architect B cannot acquire it until A releases it

There is no mechanism preventing two Architects from working on the same trinity simultaneously if they are in different sandboxes and the hard-lock contention check is not triggered (due to the acknowledged race condition). In practice, the GitHub branch itself provides the ultimate serialisation — conflicting pushes to the same branch will fail, and the second Architect will need to rebase.

---

## Deployment

**Step 1: Run the deployment script as root**

```zsh
sudo ./inf/tos_deploy.sh
```

This script:
- Creates the `team_of_six` system user (no login shell, no home directory)
- Creates the `team_of_six` group
- Creates the control plane directory structure at `/mnt/team_of_six/`
- Copies the TOS binaries to `.local/bin/` with correct ownership and permissions
- Verifies that all required dependencies are installed (`zsh`, `git`, `gh`, `rsync`, etc.)

**Step 2: Install the GitHub token**

```zsh
sudo -u team_of_six tee /mnt/team_of_six/.local/conf/.token <<< "your-token-here"
sudo chmod 0400 /mnt/team_of_six/.local/conf/.token
```

Verify the token works:

```zsh
sudo -u team_of_six gh auth status --token "$(sudo cat /mnt/team_of_six/.local/conf/.token)"
```

**Step 3: Add Architects**

For each developer who will use TOS:

```zsh
sudo ./inf/tos_add_user.sh <username>
```

This adds the user to the `team_of_six` group, provisions their IPC ribbon under `.ipc/<username>/`, creates their sandbox directory under `sandbox/<username>/`, and installs the sudoers entry.

The user must log out and back in for the group membership to take effect.

**Step 4: Verify**

As each Architect, verify the installation:

```zsh
tos --help
```

If the gateway runs and shows the usage message, the installation is working.

---

## After Development: Cleanup

After a tutorial run or test session, the Ghost's sandbox may contain test repositories that should be removed. The `inf/post_test_cleanup.sh` script handles this:

```zsh
sudo ./inf/post_test_cleanup.sh
```

This removes test sandbox directories and deletes any lock files left by the session. It does not remove Architect provisioning or the token — those are persistent.

---

← [05-workflow.md](05-workflow.md) | Next: [07-neovim-plugin.md](07-neovim-plugin.md) →
