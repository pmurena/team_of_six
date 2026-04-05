# NeoVim Plugin Integration

The developer interacts with the framework through a NeoVim IPC bridge, turning the editor into the primary control surface.

### Core Commands
* **`:TosWork`**: Queries GitHub for active Issues/PRs and syncs the target context to the `outbox.md`.
* **`<leader>lc`**: Opens a new Ghost Chat interface via `gp.nvim`.
* **`<leader>lr` (Visual Mode)**: Copies a selection to the `inbox.md` and triggers the engine execution in a terminal split.

### Workflow Synergy
The plugin naturally implements the **Baseline** of the Contextual Trinity by fetching current branch states and PR comments directly into the LLM's chat buffer.
