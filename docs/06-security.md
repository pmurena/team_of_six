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

## The Ghost Never Reads the Architect's Filesystem

This is the load-bearing invariant of the sandbox model, and it constrains
where checks may be placed, not merely what they do.

The gateway escalates to the Ghost in Stage 1. Every line after that point
executes as `team_of_six`. Any check that inspects the Architect's working
directory must therefore run **before** Stage 1 — in Stage 0 — or it becomes
the Ghost reading the Architect's tree.

Caller-location verification (project-name matching and the Typo Guard) lives
in Stage 0 for exactly this reason. It is the Architect's own filesystem, so
the Architect is the correct actor to inspect it.

The practical consequence is that the Architect's project directory needs no
particular permissions. A `0700` home, an encrypted home mount, or a
`mktemp -d` working directory are all fine — the Ghost never looks.

> **For contributors:** a module that calls `git`, `ls`, or `cat` on a path
> outside `${TOS_MNT_ROOT}` is a bug, however convenient. The value it wants
> is almost always available from `gh` or from the sandbox clone instead.

---

## Prerequisite: git must be able to authenticate

`gh auth login` authenticates the `gh` CLI. It does **not** authenticate
`git` — gh stores its token in `~/.config/gh/hosts.yml`, and plain `git`
only reaches it through a credential helper. Run:

```zsh
gh auth setup-git
```

Without this, the Architect's own clones, pulls, and pushes fall back to
interactive password prompts, which GitHub has rejected since 2021. The
Ghost is unaffected — it builds an authenticated URL from a token it mints
per invocation from its App key — so the failure appears only on the
Architect side and looks unrelated to TOS.

---

## The Sudo Gateway

The privilege separation between Architect and Ghost is enforced by `sudo`. The `tos` binary runs as the Architect's user. When it determines the user is not `team_of_six`, it re-executes itself via:

```zsh
sudo -n -u team_of_six "$TOS_BIN/tos.zsh" "$@"
```

The `-n` flag means non-interactive — if the sudo call requires a password, it fails immediately. TOS operations never require manual password entry. The permission is granted unconditionally to `team_of_six` group members via the sudoers entry installed by `inf/tos_add_user.zsh`:

```
%team_of_six ALL=(team_of_six) NOPASSWD: ${TOS_MNT_ROOT}/.local/bin/tos.zsh
```

This grants group members the ability to run exactly one binary — the TOS gateway — as the Ghost. Nothing else. An Architect cannot use this permission to run arbitrary commands.

The gateway sets `TOS_CONTROLLER_LOCKED=true` after successful escalation. Every module script checks this variable as its first line and exits immediately if it is not set. Direct invocation of any module script, bypassing the gateway, is therefore inert.

---

## The Control Plane Layout

```
${TOS_MNT_ROOT}/                   owned: root:team_of_six        mode: 0750
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
│       └── .ghost-app.pem           owned: team_of_six:team_of_six  mode: 0400
└── sandbox/
    └── <architect>/                owned: team_of_six:team_of_six  mode: 0700
```

Several design decisions are visible in these permissions:

The **inbox** is owned by the Architect, allowing them to write payloads directly without escalation. The Ghost can read it because both share the `team_of_six` group.

The **outbox** is owned by the Ghost. The Architect can read it but cannot write to it directly. This prevents forged outbox content.

The **locks directory** is mode `0700` — Ghost-exclusive. This is where the `.manifest` visa lives. The Architect cannot edit or delete the visa from their own account without going through the formal `write plan` gateway command. The blast radius approved by the Architect via `write plan` is mechanically immutable from the Architect's perspective until the next `write plan` or Trinity finalization.

The **sandbox** is mode `0700`, not even group-readable. The Architect cannot directly read or write the Ghost's working files. All interaction goes through the gateway.

The **`.ghost-app.pem`** is mode `0400` — Ghost-only. It is not itself a credential: it is an RSA key that signs a JWT, which mints an installation token valid for one hour. The gateway mints one per invocation and scrubs it via a registered `EXIT/INT/TERM` trap, along with the git credential helper that depends on it. Nothing durable is ever written to a log, an outbox, or a temporary file, and no invocation outlives its own token.

The **IPC ribbon directories** use setgid (`3770`) so that files created within them inherit the `team_of_six` group regardless of which user creates them.

---

## The HITL Destructive Gate (CONFIRM=TRUE)

The `close` and `delete` modules are placed behind a hard mechanical gate. The gateway checks the `TOS_META` payload for the exact string `CONFIRM=TRUE` before evaluating any further logic. Its absence causes an immediate abort with a loud security warning.

This catches the most dangerous class of LLM failure: a confused or stale Agent that hallucinates a destructive command. The Agent must explicitly write `CONFIRM=TRUE` in its payload — it cannot do this accidentally or by drift, because the string has no plausible role in any non-destructive operation.

---

## The Ghost Identity

The Ghost is a GitHub App, not a person and not the Architect.

**Why an App rather than a personal access token.** Three reasons, in
increasing order of importance.

A PAT is a long-lived bearer credential sitting on disk. An App private key is
not a credential at all: it signs a JWT which mints an installation token
valid for one hour. Nothing durable is stored, and the key cannot be replayed
against the API.

An App installation is scoped per repository and its permissions are
enumerated. The Ghost holds `contents`, `issues` and `pull_requests`, and is
deliberately **not** granted `administration`. It cannot create or delete a
repository because it lacks the capability, not because the code declines to.

And an App has its own identity — `<slug>[bot]`. That is what makes the phase
gate mean anything. GitHub refuses to let anyone approve their own pull
request, and the Ghost authors every Trinity PR. If the Ghost held the
Architect'"'"'s token, the Architect could never approve a phase transition, and
invariant 8 would reject it even if GitHub did not. **The Ghost is a
gatekeeper, not an authority. A gate it can satisfy on its own behalf is not
a gate.**

### Setting it up

1. Create a GitHub App. Repository permissions:

   ```
   Contents        Read and write     push, commit
   Issues          Read and write     create, comment, close
   Pull requests   Read and write     open, comment, review, merge
   Metadata        Read               (mandatory)
   Administration  NOT GRANTED        deliberate — see the ADR
   ```

2. Install it on your account or organisation, on the repositories TOS will
   manage.

3. Note the **App ID** (General settings), the **installation ID** (the numeric
   suffix of `https://github.com/settings/installations/<id>`) and the **app
   slug** (from the settings URL).

4. Place the private key in the control plane:

   ```zsh
   sudo -u team_of_six cp ~/Downloads/tosapp.private-key.pem \
        ${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem
   sudo chmod 0400 ${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem
   ```

5. Declare it in `conf/config`:

   ```zsh
   export TOS_APP_ID=123456
   export TOS_APP_INSTALL_ID=78901234
   export TOS_APP_PEM=/mnt/team_of_six/.local/conf/.ghost-app.pem
   export TOS_GHOST_LOGIN="tosapp[bot]"
   ```

`TOS_GHOST_LOGIN` is configured rather than discovered because an installation
token has no user behind it — `gh api user` returns 403. The phase gate needs
the login for invariant 8, so it is declared.

The gateway mints a token in Stage 2 on every invocation and scrubs it on exit
alongside the git credential helper. Expiry is therefore irrelevant: no
invocation outlives its token.

### Verifying

```zsh
gh api user -q .login          # you, the Architect
tos <project> sync project     # the Ghost speaks as <slug>[bot]
```

After `create trinity`, the pull request author should be the bot, not you.
The tutorial checks this in Chapter 3 and stops if it is not so.

---

## Credential Isolation and Management

TOS enforces a zero-persistence policy for Git authentication tokens. The Ghost
authenticates with a GitHub App installation token, and that token expires after
one hour — so any copy of it that outlives the process which minted it is both a
leakage vector and a time bomb.

This is not hypothetical. `sync project` once cloned with the token embedded in
the URL:

```
https://x-access-token:${GH_TOKEN}@github.com/owner/repo.git
```

git stored that URL as the sandbox'"'"'s origin. Every sandbox worked for an hour
and then failed permanently, with an authentication error that named no token
and suggested no cause.

### 1. Environment injection

The gateway mints a token in Stage 2 from the App private key, injects it as a
process-scoped git credential helper through `GIT_CONFIG_COUNT`,
`GIT_CONFIG_KEY_0` and `GIT_CONFIG_VALUE_0`, and scrubs all of it on
`EXIT`, `INT` and `TERM`.

Nothing is written to disk. The helper materialises the token only at the moment
git asks for credentials, so it never appears in `git config --list` either.

### 2. Config lockdown

Environment injection is only airtight if git cannot find a credential anywhere
else. Sandboxed git therefore runs with:

```
GIT_CONFIG_NOSYSTEM=1          # ignore /etc/gitconfig
GIT_CONFIG_GLOBAL=/dev/null    # ignore ~/.gitconfig for the Ghost user
credential.helper=             # clear inherited helpers before the injected one
```

The third matters as much as the first two. Git accumulates credential helpers
rather than replacing them, so an empty entry ahead of the injected one is what
clears any that were inherited — without it, a helper configured for the Ghost
user would be consulted first.

`GIT_CONFIG_NOSYSTEM` alone is insufficient: it closes `/etc/gitconfig` and
leaves `~/.gitconfig` open, which is exactly where a credential helper would be
written by anyone running `gh auth setup-git` as the Ghost.

### 3. Lifecycle: per invocation, not cached

**The gateway is a process per invocation.** `tos <project> sync trinity 1`
starts, mints, executes and exits. Nothing is resident between commands.

A token is therefore fresh at the start of every command and dead long before
the next one needs it. Expiry is not handled; it is structurally absent.

An in-memory cache with a proactive 50-minute refresh was specified and
rejected. There is nothing alive for fifty minutes to hold one, so caching
across invocations would mean writing the token somewhere — the precise thing
this policy forbids. The race it would mitigate requires a single command to run
for over an hour, and the latency it would save is one JWT signature plus one
HTTPS round trip on operations that are human-paced and serialised by the lock
model.

See governance/adr.md § Ephemeral Credential Lifecycle.

---## Capability, Not Restraint

An earlier version of TOS gave the Ghost a personal access token and
deliberately withheld the `delete_repo` scope from it. Destroying a repository
then required `gh auth refresh -s delete_repo`, an interactive browser flow
that `sudo -n` cannot complete — out-of-band MFA for the nuclear operation.

That mechanism is gone, and the principle it served is now enforced more
strongly rather than less.

The Ghost authenticates as a GitHub App whose installation is granted
`contents`, `issues` and `pull_requests`. It is **not** granted
`administration`. There is no scope to withhold because there is no scope to
escalate: the Ghost cannot create or destroy a repository, and no sequence of
commands, no misconfiguration and no defect in the engine can make it able to.

The distinction is worth stating plainly, because it is the difference between
the two designs:

| | withheld scope | absent capability |
|---|---|---|
| What stops the operation | a check that the scope is missing | the API has nothing to call |
| If the check is bypassed | the operation proceeds | the operation still fails |
| If the token leaks | the scope can be re-granted | the installation defines the ceiling |

A restraint is something you can be argued out of. A capability you do not
have is not.

`create project` and `delete project` were retired when this changed. They are
not disabled, or gated behind a confirmation, or restricted to certain users —
the code that called `gh repo create` and `gh repo delete` no longer exists,
and the identity that would have run it could not. Repository creation and
deletion are Architect operations, performed with the Architect's own
credentials. See governance/adr.md § TOS Does Not Create or Destroy Remotes.

The same reasoning runs through the rest of the security model. The sandbox is
`0700` rather than politely left alone. The manifest visa is checked before a
byte is written rather than audited afterwards. The Ghost cannot approve its
own phase transition because GitHub refuses to let any author approve their
own pull request, not because TOS asks it not to.
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
sudo cp <app-key>.pem ${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem
sudo chown team_of_six: ${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem
sudo chmod 0400 ${TOS_MNT_ROOT}/.local/conf/.ghost-app.pem
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
./inf/post_test_cleanup.zsh
```

This acquires the `delete_repo` scope interactively, deletes test repositories from GitHub, removes local and sandbox directories, and offers to revoke the elevated scope on exit.

---

← [05-workflow.md](05-workflow.md) | Next: [07-neovim-plugin.md](07-neovim-plugin.md) →
