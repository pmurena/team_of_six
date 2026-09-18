-- ==============================================================================
-- Team of Six - Neovim IPC Bridge (COMPLETE EDITION)
-- Implements: Reversed Single-Pick, All Sync/Write Modules, Git Guardrails.
-- ==============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers & Environment Configuration
-- ---------------------------------------------------------------------------

local function get_project_name()
	local name = vim.fn.system("basename $(git rev-parse --show-toplevel 2>/dev/null)"):gsub("\n", "")
	return name ~= "" and name or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_mnt_root()
	return os.getenv("TOS_MNT_ROOT") or "/tmp"
end

local function get_user()
	return os.getenv("USER") or "architect"
end

local function ipc_path(filename)
	return string.format("%s/.ipc/%s/%s", get_mnt_root(), get_user(), filename)
end

local function tos_bin()
	return string.format("%s/.local/bin/tos.zsh", get_mnt_root())
end

local function in_git_repo()
	return vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null"):gsub("\n", "") == "true"
end

function M.get_agent_prompt(name)
	local agent_name = name or "code"

	-- 1. Resolve absolute path dynamically
	local src_info = debug.getinfo(1, "S").source
	local src_dir = vim.fn.fnamemodify(src_info:sub(2), ":p:h")
	local prompt_path = vim.fn.resolve(src_dir .. "/../../../llm_agents/" .. agent_name .. ".md")

	-- 2. Read and return the content safely
	local file = io.open(prompt_path, "r")
	if not file then
		return "Error: TOS System prompt not found at " .. prompt_path
	end

	local content = file:read("*a")
	file:close()

	return content
end

-- ---------------------------------------------------------------------------
-- Labels & Metadata Extraction
-- ---------------------------------------------------------------------------

local function extract_label(content, prefix)
	if prefix == "FILE" then
		return content:match(": (.-)===") or "unknown file"
	end
	if prefix == "META" or prefix == "ISSUE" or prefix == "TRINITY" then
		return content:match("TITLE=(.-)\n") or prefix
	end
	if prefix == "COMMENT" then
		local body = content:match("BODY=(.-)\n") or "Comment"
		return body:sub(1, 30) .. (body:len() > 30 and "..." or "")
	end
	return prefix
end

-- ---------------------------------------------------------------------------
-- Reversed Single-Pick Smart-Yanking
-- ---------------------------------------------------------------------------

local function smart_yank(command, callback)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(lines, "\n")
	local candidates = {}

	local function add_candidates(prefix)
		local start_pat = "===TOS_" .. prefix .. "_START"
		local end_pat = "===TOS_" .. prefix .. "_END==="
		local pattern = start_pat:gsub("%-", "%%-") .. "(.-)" .. end_pat:gsub("%-", "%%-")

		for block_body in text:gmatch(pattern) do
			table.insert(candidates, {
				label = string.format("[%s] %s", prefix, extract_label(block_body, prefix)),
				content = start_pat .. block_body .. end_pat,
			})
		end
	end

	if command == "code" then
		add_candidates("META")
		add_candidates("FILE")
	elseif command == "comment" then
		add_candidates("COMMENT")
	elseif command == "issue" then
		add_candidates("ISSUE")
	elseif command == "trinity" then
		add_candidates("TRINITY")
	end

	if #candidates == 0 then
		vim.notify("⚠️ No TOS blocks found for: " .. command, vim.log.levels.WARN)
		return
	end

	-- Reverse: Latest blocks first
	local reversed = {}
	for i = #candidates, 1, -1 do
		table.insert(reversed, candidates[i])
	end
	candidates = reversed

	local options = {}
	for i, c in ipairs(candidates) do
		table.insert(options, string.format("%d. %s", i, c.label))
	end
	table.insert(options, "❌ Cancel")

	vim.ui.select(options, { prompt = "👻 Pick ONE block (Recent First):" }, function(choice, idx)
		if not choice or choice == "❌ Cancel" then
			return
		end
		local pick = candidates[idx]
		local f = io.open(ipc_path("inbox.md"), "w")
		if f then
			f:write(pick.content)
			f:close()
			if callback then
				callback()
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Execution Engines
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
			if on_done then
				on_done(result)
			end
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Sync Trinity Implementation
-- ---------------------------------------------------------------------------

local function sync_trinity()
	local project = get_project_name()
	vim.notify("👻 Querying GitHub for open items...", vim.log.levels.INFO)
	local list = vim.fn.systemlist("gh pr list")
	if #list == 0 or (list[1] and list[1]:match("no open")) then
		list = vim.fn.systemlist("gh issue list")
	end

	if #list == 0 then
		vim.notify("❌ No open items found.", vim.log.levels.WARN)
		return
	end

	vim.ui.select(list, { prompt = "👻 Select Trinity to Sync:" }, function(choice)
		if not choice then
			return
		end
		local id = choice:match("%d+")
		if id then
			vim.notify("⏳ Syncing Trinity #" .. id .. "...", vim.log.levels.INFO)
			run_async(string.format("%s %s sync trinity %s", tos_bin(), project, id))
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Keymap Registration
-- ---------------------------------------------------------------------------

local function register_keymaps()
	local project = get_project_name()
	local opts = function(desc)
		return { desc = desc, noremap = true, silent = true }
	end
	local wk_ok, wk = pcall(require, "which-key")
	if wk_ok then
		wk.add({
			{ "<leader>6", group = "Team of Six [6]", icon = "👻" },
			{ "<leader>6s", group = "Sync" },
			{ "<leader>6w", group = "Write" },
		})
	end

	-- SYNC MODULE
	vim.keymap.set("n", "<leader>6ss", function()
		run_async(string.format("%s %s sync project", tos_bin(), project))
	end, opts("Sync Project"))

	vim.keymap.set("n", "<leader>6st", sync_trinity, opts("Sync Trinity"))

	vim.keymap.set("n", "<leader>6sp", function()
		vim.ui.input({ prompt = "Files to peek: " }, function(input)
			if input then
				run_async(string.format("%s %s sync peek %s", tos_bin(), project, input))
			end
		end)
	end, opts("Sync Peek"))

	-- WRITE MODULE
	vim.keymap.set("n", "<leader>6wc", function()
		smart_yank("code", function()
			run_async(string.format("%s %s write code", tos_bin(), project))
		end)
	end, opts("Write Code"))

	vim.keymap.set("n", "<leader>6wm", function()
		smart_yank("comment", function()
			run_async(string.format("%s %s write comment", tos_bin(), project))
		end)
	end, opts("Write Comment"))

	vim.keymap.set("n", "<leader>6wi", function()
		smart_yank("issue", function()
			run_async(string.format("%s %s write issue", tos_bin(), project))
		end)
	end, opts("Write Issue"))

	vim.keymap.set("n", "<leader>6wt", function()
		smart_yank("trinity", function()
			run_async(string.format("%s %s write trinity", tos_bin(), project))
		end)
	end, opts("Write Trinity"))
end

function M.setup()
	local group = vim.api.nvim_create_augroup("TosGuardrail", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
		group = group,
		callback = function()
			if in_git_repo() then
				register_keymaps()
			end
		end,
	})
end

return M
