# Security Model: The Sudo Perimeter

Team of Six operates on a strict execution air-gap to ensure the LLM cannot harm the host system.

### The Air-Gap
* **The AI User:** All code execution happens as a dedicated `team_of_six` OS user with no shell access for the human architect.
* **Locked Sandbox:** The sandbox directory is set to `chmod 700`, owned by the AI user. The human cannot enter it directly.

### IPC Ribbon
Communication flows exclusively through a shared "ribbon" (`inbox.md` and `outbox.md`) in a multi-tenant IPC directory. The engine's master gateway escalates privileges via a hardened `sudoers` configuration to process these files.
