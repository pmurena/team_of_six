← [06-security.md](06-security.md) | Next: [08-agentic-unleash.md](08-agentic-unleash.md) →

---

# 07 — Neovim Plugin

The Neovim plugin (`plugins/neovim/tos_bridge.lua`) is the integration layer between your editor and the TOS execution engine. Without it, the workflow requires manually copying payload blocks from the LLM chat window into the inbox file and then running `tos` from the terminal — functional, but friction-heavy. With it, the entire cycle of receiving LLM output, delivering it to the Ghost, and reading the response happens from within Neovim, without leaving the editor.

This document explains what the plugin does, how it does it, and how to configure it.

---

## The Last Manual Step

To understand why the plugin matters, consider what the workflow looks like without it. You ask the LLM a question in your chat client. The LLM responds with a payload — several blocks of text in the TOS format. You select those blocks, copy them, switch to a terminal, open the inbox file, paste, save, and run `tos`. The Ghost executes and writes to the outbox. You open the outbox file, read the output, and paste the relevant parts back into your chat client as context for the next message.

This is four manual transfers of text between three different interfaces. Each transfer is an opportunity to miss a block, paste the wrong thing, or forget to include context. The plugin eliminates all four transfers.

---

## Architecture of the Plugin

The plugin is built around three core ideas:

**Smart Yanking** — instead of requiring you to manually select payload blocks, the plugin scans the current buffer (your LLM chat buffer) for TOS-formatted blocks matching the command you want to run. For `write code`, it extracts all `TOS_META` and `TOS_FILE` blocks. For `write tasks`, it extracts all `TOS_ISSUE` blocks. For `write comment`, it extracts all `TOS_COMMENT` blocks. The extracted content is written directly to the inbox. You never manually select or copy anything.

**Async Execution** — when a TOS command is triggered from a keymap, the plugin runs it asynchronously via `vim.system`. Neovim remains responsive while the Ghost works. The output appears in a terminal split when the command completes.

**Intelligent Buffer Routing** — when a trinity sync completes, the plugin reads the outbox and routes the Clean Room Snapshot to the appropriate buffer. If you are syncing for your own work (`<leader>6st`), the context goes to your local LLM buffer. If you are syncing for a review or a team handoff (`<leader>6sT`), it goes to a shared global buffer. The LLM always starts its next response with a current, verified context snapshot already in its buffer.

---

## The Dynamic Parser Cache

The plugin loads a parser configuration from `tos <project> system export-parsers` on startup. This configuration describes the exact block delimiters for each payload type in the project's language. The cache means the smart-yanking engine can handle projects that use customised or extended block formats without hardcoding the delimiters in the plugin itself.

If the parser cache fails to load (network error, the Ghost is not running), the plugin falls back to full-buffer mode — it passes the entire buffer content as the payload. This is less precise but never silently fails.

---

## The Git Guardrail

All TOS keymaps are automatically activated and deactivated based on whether the current buffer is inside a Git repository. When you open a file outside a Git repo, the `<leader>6w*` and `<leader>6s*` keymaps do not exist. When you enter a Git repo (either by opening a file within one, or by changing directory), they activate automatically via a `BufEnter` / `DirChanged` autocommand. This prevents accidental TOS operations from non-project buffers and keeps the keymap namespace clean when you are not doing TOS work.

---

## Keymap Reference

All keymaps are in the `<leader>6` namespace — displayed in which-key as "[T]eam of Six" if you use which-key.nvim.

### Sync Commands

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>6ss` | Sync Start | Provisions the sandbox for the current project. Equivalent to `tos <project> sync start`. Detects the project name from `git rev-parse --show-toplevel`. |
| `<leader>6st` | Sync Trinity (local) | Queries GitHub for open issues and PRs, presents a selection menu, syncs the chosen trinity, and routes the Clean Room Snapshot to the local LLM buffer. |
| `<leader>6sT` | Sync Trinity (global) | Same as above but routes the context to a global shared buffer. Useful when handing off context to a colleague or a different LLM session. |
| `<leader>6sp` | Sync Peek | Prompts for a space-separated list of filenames and injects their content into the outbox. Equivalent to `tos <project> sync peek <files>`. |

### Write Commands

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>6wc` | Write Code | Smart-yanks `TOS_META` and `TOS_FILE` blocks from the current buffer, writes them to the inbox, and runs `tos <project> write code`. |
| `<leader>6wm` | Write Comment | Smart-yanks `TOS_COMMENT` blocks and runs `tos <project> write comment`. |
| `<leader>6wt` | Write Tasks | Smart-yanks `TOS_ISSUE` blocks and runs `tos <project> write tasks`. |

---

## Installation

The plugin is a single Lua file. Install it with your preferred plugin manager by pointing it at the local path, or copy it into your Neovim runtime:

**Using lazy.nvim with a local path:**

```lua
{
    dir = "/path/to/team_of_six/plugins/neovim",
    name = "tos_bridge",
    config = function()
        require("tos_bridge").setup()
    end,
}
```

**Manual installation:**

```zsh
cp plugins/neovim/tos_bridge.lua ~/.config/nvim/lua/tos_bridge.lua
```

Then in your Neovim config:

```lua
require("tos_bridge").setup()
```

**Dependencies:**

The plugin uses only Neovim's built-in APIs (`vim.system`, `vim.ui.select`, `vim.ui.input`, `vim.notify`). It has no external Lua dependencies. For an enhanced selection UI, any plugin that overrides `vim.ui.select` (such as `telescope.nvim` or `dressing.nvim`) will work automatically.

---

## The Recommended LLM Integration

The plugin is designed to work alongside a Neovim LLM chat plugin such as `gp.nvim` or `codecompanion.nvim`. The intended setup is:

1. Your LLM chat plugin manages a dedicated buffer for each conversation
2. The TOS plugin reads from and writes to that same buffer via smart-yanking and buffer routing
3. The Clean Room Snapshot from `sync trinity` is injected into the chat buffer as the opening context for each new session

With this setup, the full cycle is:
- `<leader>6st` — sync the trinity, inject context into the chat buffer
- Chat with the LLM in the buffer; it produces TOS-formatted payloads
- `<leader>6wc` (or `6wt` or `6wm`) — smart-yank the payload, execute via Ghost, result appears in a terminal split
- Repeat

No manual text copying at any point.

---

← [06-security.md](06-security.md) | Next: [08-agentic-unleash.md](08-agentic-unleash.md) →
