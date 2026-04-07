# NeoVim IPC Bridge

The user interacts with the Team of Six framework primarily through NeoVim.

## Prerequisites
* **gp.nvim**: The `:TosWork` bridge command relies heavily on the `gp.nvim` plugin to autonomously launch the Ghost Chat interface via `GpChatNew` and `GpAgent`. This plugin must be installed and properly configured in your Neovim environment for the bridge to function.

## Commands
* `:TosWork`: Queries GitHub for active PRs or Issues. Triggers NeoVim's native UI selection to pick a target. Once selected, it executes the `tos work` engine to sync the repository and fetch the outbox context.

## Keymaps
* `<leader>l`: Leader prefix for the LLM Toolbox.
* `<leader>lw`: Triggers the `:TosWork` Ghost Work Sync.
* `<leader>lc`: Opens a new Ghost Chat via the `GpAgent` plugin.
* `<leader>lr` (Visual Mode): Copies the current selection into the IPC buffer (`tos_inbox.sh`) and triggers the engine via a botright terminal split.
