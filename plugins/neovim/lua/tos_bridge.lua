-- ==============================================================================
-- Team of Six - Neovim IPC Bridge
-- Implements: async execution, dynamic parser caching, smart-yanking,
--             intelligent buffer routing, branded context headers,
--             and the full 6... semantic keymap taxonomy.
-- ==============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_project_name()
    local name = vim.fn.system("basename $(git rev-parse --show-toplevel 2>/dev/null)"):gsub("\n", "")
    return name ~= "" and name or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_mnt_root()
    return os.getenv("TOS_MNT_ROOT") or "/mnt/team_of_six"
end

local function get_user()
    return os.getenv("USER") or "architect"
end

local function ipc_path(filename)
    local mnt = get_mnt_root()
    local user = get_user()
    return string.format("%s/.ipc/%s/%s", mnt, user, filename)
end

local function tos_bin()
    return string.format("%s/.local/bin/tos.zsh", get_mnt_root())
end

-- Check we are inside a Git repository. Used by the Git Guardrail autocmds.
local function in_git_repo()
    return vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null"):gsub("\n", "") == "true"
end

-- ---------------------------------------------------------------------------
-- Dynamic Parser Cache  (ADR 3)
-- ---------------------------------------------------------------------------

M._parser_cache = nil

local function load_parsers(callback)
    if M._parser_cache then
        if callback then callback(M._parser_cache) end
        return
    end

    local project = get_project_name()
    local cmd = string.format("%s %s system export-parsers", tos_bin(), project)

    vim.system(vim.split(cmd, " "), { text = true }, function(result)
        if result.code == 0 and result.stdout and result.stdout ~= "" then
            local ok, parsed = pcall(vim.json.decode, result.stdout)
            if ok then
                M._parser_cache = parsed
                if callback then callback(M._parser_cache) end
                return
            end
        end
        -- Fallback: empty cache — smart-yanking will use full-buffer mode
        M._parser_cache = {}
        if callback then callback(M._parser_cache) end
    end)
end

-- ---------------------------------------------------------------------------
-- Smart-Yanking Engine
-- Scans the last LLM response in the current buffer for blocks matching
-- the requested TOS command (e.g., "code" -> TOS_META + TOS_FILE blocks),
-- bundles them, and writes to inbox.md.
-- ---------------------------------------------------------------------------

-- Returns all lines in the current buffer as a single string.
local function current_buffer_text()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    return table.concat(lines, "\n")
end

-- Extract all blocks for a given prefix (e.g., "META", "FILE", "COMMENT", "ISSUE")
-- from raw text, using the delimiters from the parser cache when available.
local function extract_blocks(text, prefix)
    local blocks = {}
    local start_pat = "===TOS_" .. prefix .. "_START"
    local end_pat   = "===TOS_" .. prefix .. "_END==="
    for block in text:gmatch(start_pat .. "(.-)" .. end_pat) do
        table.insert(blocks, start_pat .. block .. end_pat)
    end
    return blocks
end

-- For "code" command: grab META + FILE blocks.
-- For "comment": grab COMMENT blocks.
-- For "issue": grab ISSUE blocks.
local function smart_yank(command, callback)
    local text = current_buffer_text()
    local collected = {}

    if command == "code" then
        for _, b in ipairs(extract_blocks(text, "META")) do table.insert(collected, b) end
        for _, b in ipairs(extract_blocks(text, "FILE")) do table.insert(collected, b) end
    elseif command == "comment" then
        for _, b in ipairs(extract_blocks(text, "COMMENT")) do table.insert(collected, b) end
    elseif command == "issue" then
        for _, b in ipairs(extract_blocks(text, "ISSUE")) do table.insert(collected, b) end
    end

    if #collected == 0 then
        vim.notify("⚠️  No TOS payload blocks found in buffer for command: " .. command, vim.log.levels.WARN)
        return
    end

    local payload = table.concat(collected, "\n")
    local inbox = ipc_path("inbox.md")
    local f = io.open(inbox, "w")
    if not f then
        vim.notify("❌ Cannot write to inbox: " .. inbox, vim.log.levels.ERROR)
        return
    end
    f:write(payload)
    f:close()

    vim.notify(string.format("📥 %d block(s) staged in inbox.", #collected), vim.log.levels.INFO)
    if callback then callback() end
end

-- ---------------------------------------------------------------------------
-- Async Engine Execution
-- ---------------------------------------------------------------------------

local function run_async(cmd_str, on_done)
    local parts = vim.split(cmd_str, " ")
    vim.system(parts, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                vim.notify("❌ Ghost Engine Error:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
            else
                vim.notify("✅ Engine complete.", vim.log.levels.INFO)
            end
            -- Append outbox to current buffer
            local outbox = ipc_path("outbox.md")
            local f = io.open(outbox, "r")
            if f then
                local content = f:read("*a")
                f:close()
                if content and content ~= "" then
                    local lines = vim.split(content, "\n")
                    vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)
                end
            end
            if on_done then on_done(result) end
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Intelligent Buffer Routing
-- ---------------------------------------------------------------------------

-- Ghost chat buffers are identified by the branded header pattern.
local BRAND_PATTERN = "^# .*: Trinity #"

local function list_tos_buffers()
    local result = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local first_line = (vim.api.nvim_buf_get_lines(buf, 0, 1, false))[1] or ""
            if first_line:match(BRAND_PATTERN) then
                table.insert(result, { buf = buf, header = first_line })
            end
        end
    end
    return result
end

local function inject_branded_header(buf, project, trinity_id)
    local header = string.format(
        "# %s: Trinity #%s\n> Contribute(d) @ https://github.com/pmurena/team_of_six\n\n",
        project, trinity_id
    )
    local lines = vim.split(header, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
end

-- Present a picker: reuse an existing TOS buffer, or open a new one.
-- `scope`: "local" filters by current project name, "global" shows all.
local function route_to_buffer(project, trinity_id, context_text, scope)
    local bufs = list_tos_buffers()
    local choices = { "[New Ghost Chat]" }
    local buf_map = {}

    for _, entry in ipairs(bufs) do
        local label = entry.header
        if scope == "local" and not label:find(project, 1, true) then
            goto continue
        end
        table.insert(choices, label)
        buf_map[label] = entry.buf
        ::continue::
    end

    vim.ui.select(choices, {
        prompt = "👻 Route context to buffer (Team of Six):",
    }, function(choice)
        if not choice then return end

        local target_buf
        if choice == "[New Ghost Chat]" then
            vim.cmd("GpChatNew")
            target_buf = vim.api.nvim_get_current_buf()
            inject_branded_header(target_buf, project, trinity_id)
        else
            target_buf = buf_map[choice]
            if not target_buf then return end
            -- Switch to that buffer
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == target_buf then
                    vim.api.nvim_set_current_win(win)
                    break
                end
            end
        end

        vim.defer_fn(function()
            vim.api.nvim_buf_set_lines(target_buf, -1, -1, false, vim.split(context_text, "\n"))
            vim.notify("✅ Ghost context loaded.", vim.log.levels.INFO)
        end, 100)
    end)
end

-- ---------------------------------------------------------------------------
-- Git Guardrail  (ADR — keymaps only active inside a Git repo)
-- ---------------------------------------------------------------------------

local function setup_guardrail(callback)
    local group = vim.api.nvim_create_augroup("TosGitGuardrail", { clear = true })
    local function refresh()
        if in_git_repo() then
            callback(true)
        else
            callback(false)
        end
    end
    vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
        group = group,
        callback = refresh,
    })
    refresh() -- run immediately
end

-- ---------------------------------------------------------------------------
-- Sync Actions
-- ---------------------------------------------------------------------------

local function sync_start()
    if not in_git_repo() then
        vim.notify("🚨 Not inside a Git repository.", vim.log.levels.ERROR)
        return
    end
    local project = get_project_name()
    local cmd = string.format("%s %s sync start", tos_bin(), project)
    vim.notify("⏳ Provisioning sandbox for " .. project .. "...", vim.log.levels.INFO)
    run_async(cmd)
end

local function sync_trinity(scope)
    if not in_git_repo() then
        vim.notify("🚨 Not inside a Git repository.", vim.log.levels.ERROR)
        return
    end

    local project = get_project_name()

    vim.notify("👻 Querying GitHub for open items...", vim.log.levels.INFO)
    local list_output = vim.fn.systemlist("gh pr list")
    if #list_output == 0 or (list_output[1] and list_output[1]:match("no open")) then
        list_output = vim.fn.systemlist("gh issue list")
    end

    if vim.v.shell_error ~= 0 or #list_output == 0 then
        vim.notify("❌ No open PRs or Issues found.", vim.log.levels.WARN)
        return
    end

    vim.ui.select(list_output, {
        prompt = "👻 Select Trinity to Sync:",
    }, function(choice)
        if not choice then return end

        local trinity_id = choice:match("%d+")
        if not trinity_id then
            vim.notify("❌ Could not parse an ID from the selection.", vim.log.levels.ERROR)
            return
        end

        vim.notify("⏳ Syncing Trinity #" .. trinity_id .. "...", vim.log.levels.INFO)
        local cmd = string.format("%s %s sync trinity %s", tos_bin(), project, trinity_id)

        vim.system(vim.split(cmd, " "), { text = true }, function(result)
            vim.schedule(function()
                if result.code ~= 0 then
                    vim.notify("❌ Sync error: " .. (result.stderr or ""), vim.log.levels.ERROR)
                    return
                end

                local outbox = ipc_path("outbox.md")
                local f = io.open(outbox, "r")
                if not f then
                    vim.notify("❌ Outbox not found after sync.", vim.log.levels.ERROR)
                    return
                end
                local context = f:read("*a")
                f:close()

                route_to_buffer(project, trinity_id, context, scope)
            end)
        end)
    end)
end

local function sync_peek()
    if not in_git_repo() then
        vim.notify("🚨 Not inside a Git repository.", vim.log.levels.ERROR)
        return
    end

    vim.ui.input({ prompt = "Files to peek (space-separated): " }, function(input)
        if not input or input == "" then return end
        local project = get_project_name()
        local cmd = string.format("%s %s sync peek %s", tos_bin(), project, input)
        vim.notify("⏳ Peeking: " .. input, vim.log.levels.INFO)
        run_async(cmd)
    end)
end

-- ---------------------------------------------------------------------------
-- Write Actions  (smart-yanking → inbox → engine)
-- ---------------------------------------------------------------------------

local function write_action(command)
    if not in_git_repo() then
        vim.notify("🚨 Not inside a Git repository.", vim.log.levels.ERROR)
        return
    end

    load_parsers(function(_)
        smart_yank(command, function()
            local project = get_project_name()
            local cmd = string.format("%s %s write %s", tos_bin(), project, command)
            vim.notify("⏳ Firing write " .. command .. "...", vim.log.levels.INFO)
            run_async(cmd)
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Keymap Registration  (guarded by Git Guardrail)
-- ---------------------------------------------------------------------------

local keymaps_active = false

local function register_keymaps()
    if keymaps_active then return end
    keymaps_active = true

    local opts = function(desc)
        return { desc = desc, noremap = true, silent = true }
    end

    -- 1. Force Which-Key Group Registration
    local wk_ok, wk = pcall(require, "which-key")
    if wk_ok then
        -- Try Which-Key v3 API (Modern)
        local ok_v3 = pcall(wk.add, {
            { "<leader>6", group = "Team of Six [6]", icon = "👻" },
            { "<leader>6s", group = "Sync with 6" },
            { "<leader>6w", group = "Write to 6" },
        })
        -- Fallback to Which-Key v2 API (Older)
        if not ok_v3 then
            pcall(wk.register, {
                ["<leader>6"]  = { name = "+Team of Six [6]" },
                ["<leader>6s"] = { name = "+[S]ync with 6" },
                ["<leader>6w"] = { name = "+[W]rite to 6" },
            })
        end
    else
        -- Fallback if Which-Key isn't loaded yet
        vim.keymap.set("n", "<leader>6", "<Nop>", opts("Team of Six [6]"))
        vim.keymap.set("n", "<leader>6s", "<Nop>", opts("[S]ync with 6"))
        vim.keymap.set("n", "<leader>6w", "<Nop>", opts("[W]rite to 6"))
    end

    -- 2. Sync Actions
    vim.keymap.set("n", "<leader>6ss", sync_start,                         opts("[S]ync Start"))
    vim.keymap.set("n", "<leader>6st", function() sync_trinity("local") end,  opts("Sync [T]rinity (local)"))
    vim.keymap.set("n", "<leader>6sT", function() sync_trinity("global") end, opts("Sync [T]rinity (global)"))
    vim.keymap.set("n", "<leader>6sp", sync_peek,                          opts("Sync [P]eek"))

    -- 3. Write Actions
    vim.keymap.set("n", "<leader>6wc", function() write_action("code")    end, opts("Write [C]ode"))
    vim.keymap.set("n", "<leader>6wm", function() write_action("comment") end, opts("Write Comment"))
    vim.keymap.set("n", "<leader>6wi", function() write_action("issue") end, opts("Write [I]ssue"))
    vim.keymap.set("n", "<leader>6wt", function() write_action("trinity") end, opts("Write [T]rinity"))
end

local function deregister_keymaps()
    if not keymaps_active then return end
    keymaps_active = false

    -- Define all keys to be wiped
    local maps = { 
        "<leader>6", 
        "<leader>6s", "<leader>6ss", "<leader>6st", "<leader>6sT", "<leader>6sp",
        "<leader>6w", "<leader>6wc", "<leader>6wm", "<leader>6wi", "<leader>6wt" 
    }

    for _, lhs in ipairs(maps) do
        pcall(vim.keymap.del, "n", lhs)
    end
end

-- ---------------------------------------------------------------------------
-- Plugin Initialisation
-- ---------------------------------------------------------------------------

function M.setup()
    -- Pre-warm parser cache silently
    load_parsers(function(_) end)

    -- Git Guardrail: only activate keymaps inside a Git repo
    setup_guardrail(function(is_git)
        if is_git then
            register_keymaps()
        else
            deregister_keymaps()
        end
    end)
end

return M
