# NeoVim IPC Bridge

The user interacts with the Team of Six framework primarily through NeoVim.

## Commands
* `:TosWork`: Queries GitHub for active PRs or Issues. Triggers NeoVim's native UI selection to pick a target. Once selected, it executes the `tos work` engine to sync the repository and fetch the outbox context.

## Keymaps
* `<leader>l`: Leader prefix for the LLM Toolbox.
* `<leader>lw`: Triggers the `:TosWork` Ghost Work Sync.
* `<leader>lc`: Opens a new Ghost Chat via the `GpAgent` plugin.
* `<leader>lr` (Visual Mode): Copies the current selection into the IPC buffer (`tos_inbox.sh`) and triggers the engine via a botright terminal split.
