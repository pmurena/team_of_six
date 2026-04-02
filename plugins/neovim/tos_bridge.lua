-- ==============================================================================
-- Team of Six (V76) - NeoVim IPC Bridge (Zsh Native)
-- ==============================================================================

local function get_project_name()
	local name = vim.fn.system("basename $(git rev-parse --show-toplevel 2>/dev/null)"):gsub("\n", "")
	return name ~= "" and name or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_mnt_root()
	return os.getenv("TOS_MNT_ROOT") or "/mnt/team_of_six"
end

vim.keymap.set("n", "<leader>l", "", { desc = "[L]LM Toolbox (Team of Six)" })

-- 1. The Work Trigger (Evolved with Interactive GitHub Sync)
vim.api.nvim_create_user_command("TosWork", function()
	local project = get_project_name()
	local user = os.getenv("USER") or "architect"
	local mnt_root = get_mnt_root()

	vim.notify("👻 Querying GitHub for active tasks...", vim.log.levels.INFO)

	-- Fetch PRs (Fallback to Issues if no PRs are open)
	local list_output = vim.fn.systemlist("gh pr list")
	if #list_output == 0 or (list_output[1] and list_output[1]:match("no open")) then
		list_output = vim.fn.systemlist("gh issue list")
	end

	-- Error check the GH CLI
	if vim.v.shell_error ~= 0 then
		return vim.notify("❌ Failed to query GitHub. Is 'gh' CLI authenticated?", vim.log.levels.ERROR)
	end
	if #list_output == 0 or (list_output[1] and list_output[1]:match("no open")) then
		return vim.notify("❌ No open PRs or Issues found.", vim.log.levels.WARN)
	end

	-- Trigger Neovim's native UI selection (Hooks into Telescope/FZF automatically)
	vim.ui.select(list_output, {
		prompt = "👻 Select Target to Sync (Team of Six):",
	}, function(choice)
		if not choice then
			return
		end -- User hit escape/aborted

		-- Extract the first sequence of numbers (The PR or Issue ID)
		local target_id = choice:match("%d+")
		if not target_id then
			return vim.notify("❌ Could not parse an ID from the selection.", vim.log.levels.ERROR)
		end

		vim.notify("⏳ Syncing Remote Truth for ID: " .. target_id .. "...", vim.log.levels.INFO)

		-- Execute the daemon synchronously to generate the outbox
		-- FIXED: Removed redundant sudo call. Let the gateway handle escalation.
		local tos_cmd = string.format("%s/.local/bin/tos %s work %s", mnt_root, project, target_id)
		local res = vim.fn.system(tos_cmd)

		if vim.v.shell_error ~= 0 then
			return vim.notify("❌ Ghost Engine Error: " .. res, vim.log.levels.ERROR)
		end

		-- Read the newly generated context from the IPC directory
		local context_path = string.format("%s/tos_home/%s/.ipc/outbox.md", mnt_root, user)
		local file = io.open(context_path, "r")
		if not file then
			return vim.notify("❌ Context not found after sync. Path: " .. context_path, vim.log.levels.ERROR)
		end
		local context = file:read("*a")
		file:close()

		-- Launch the Agent Interface
		vim.cmd("GpChatNew")
		vim.cmd("GpAgent TeamOfSix")

		vim.defer_fn(function()
			vim.api.nvim_buf_set_lines(0, -1, -1, false, vim.split(context, "\n"))
			vim.notify("✅ Ghost context loaded successfully.", vim.log.levels.INFO)
		end, 100)
	end)
end, {})

-- 2. The Execution Bridge (The Air-Gap)
local function run_tos_selection()
	vim.cmd('noau normal! "ty')
	local project = get_project_name()
	local user = os.getenv("SUDO_USER") or os.getenv("USER") or "architect"
	local mnt_root = get_mnt_root()

	-- Updated to the new Markdown Typewriter format
	local ipc_file = string.format("%s/tos_home/%s/.ipc/inbox.md", mnt_root, user)

	local f = io.open(ipc_file, "w")
	if not f then
		return print("❌ Error writing to IPC buffer at " .. ipc_file)
	end
	f:write(vim.fn.getreg("t"))
	f:close()

	-- Ask the Architect if this is a code change or a comment
	vim.ui.select({ "code", "comment" }, {
		prompt = "👻 Select Write Action (Team of Six):",
	}, function(action)
		if not action then
			return
		end
		-- FIXED: Removed redundant sudo call. Let the gateway handle escalation.
		local cmd = string.format("%s/.local/bin/tos %s write %s", mnt_root, project, action)
		vim.cmd("botright 20split | terminal " .. cmd)
		vim.cmd("startinsert")
	end)
end

-- Keymaps
vim.keymap.set("n", "<leader>lc", "<cmd>GpChatNew<CR><cmd>GpAgent TeamOfSix<CR>", { desc = "New Ghost [C]hat" })
vim.keymap.set("n", "<leader>lw", "<cmd>TosWork<CR>", { desc = "Ghost [W]ork Sync" })
vim.keymap.set("v", "<leader>lr", run_tos_selection, { desc = "[R]un Selection via Ghost" })
