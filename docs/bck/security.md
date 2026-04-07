# Security Model & The Sudo Perimeter

Team of Six relies on a strict execution air-gap to ensure the LLM cannot harm the host system.

## The Gateway Firewall
* The master gateway script (`bin/tos`) is owned by `root` but allows read/execute access to the AI Group (chmod 550).
* To run the engine, the human user must execute `sudo -n -u "$AI_USER" "$TOS_BIN/tos"`.
* Sudoers configuration explicitly allows the AI Group to run the `tos` binary as the AI User without a password.

## Module Lockout
* Internal execution modules (located in `bin/work` and `bin/write`) are strictly owned by the AI User and AI Group.
* These directories are set to `chmod 500`, completely locking out the human architect from running them directly. They must be routed through the master gateway.

## Inter-Process Communication (IPC)
* Data flows between the human and the Ghost via an IPC shared "ribbon" located at `tos_home/<user>/.ipc`.
* The AI User sandbox itself is strictly locked (chmod 700) and cannot be modified by the human user directly.
