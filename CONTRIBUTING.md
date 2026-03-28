# Contributing to Team of Six

Thank you for your interest in improving Team of Six! 

This project operates on a very specific set of architectural constraints designed to enforce security and execution predictability. Before contributing, please understand the core architecture:

## The Ghost Architecture
1. **Zsh Engine:** The core logic is written in pure Zsh. We rely on Zsh's robust `ZERR` traps (`error_trap.sh`) and globbing (`nullglob`) to prevent execution failures. Avoid rewriting core modules in other languages.
2. **Air-Gapped Sandbox:** The `tos` engine strictly enforces execution as the `team_of_six` user. Any script additions must respect the boundary between the Architect (`$USER`) and the Ghost (`team_of_six`).
3. **The IPC Pipe:** All communication happens via volatile files in `/run/team_of_six/`. Do not introduce sockets or daemons.
4. **The Outbox Mutex:** The `tos_publish.sh` governor enforces a linear GitOps state. Do not bypass the `.tos_outbox/` staging payload requirements.

## Development Workflow
If you are adding new `tos` commands or modifying existing logic:
1. Fork the repository.
2. Test your changes locally in the `/opt/team_of_six` installation path.
3. Ensure no hardcoded paths violate the `$TOS_MNT_ROOT` or `$TOS_SANDBOX` dynamic variables.
4. Submit a Pull Request outlining the changes and ensuring they maintain the "Zero-Context Switch" philosophy for the Architect.
