-- ==============================================================================
-- Team of Six (V70) - NeoVim IPC Bridge (Zsh Native)
-- ==============================================================================

local function get_project_name()
	local name = vim.fn.system("basename $(git rev-parse --show-toplevel 2>/dev/null)"):gsub("\n", "")
	return name ~= "" and name or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

vim.keymap.set("n", "<leader>l", "", { desc = "[L]LM Toolbox (Team of Six)" })

-- 1. The Work Trigger
vim.api.nvim_create_user_command("TosWork", function()
	local user = os.getenv("USER") or "architect"
	local context_path = "/mnt/team_of_six/.ipc/" .. user .. "/tos_outbox.md"
	local file = io.open(context_path, "r")
	if not file then
		return vim.notify("❌ No context found. Run 'tos <project> work <id>'", vim.log.levels.ERROR)
	end
	local context = file:read("*a")
	file:close()

	require("gp").ChatNew("edit", "TeamOfSix")
	vim.defer_fn(function()
		vim.api.nvim_buf_set_lines(0, -1, -1, false, vim.split(context, "\n"))
		vim.notify("👻 Ghost context loaded from GitHub Truth.", vim.log.levels.INFO)
	end, 100)
end, {})

-- 2. The Execution Bridge
local function run_tos_selection()
	vim.cmd('noau normal! "ty')
	local project = get_project_name()
	local ipc_file = "/mnt/team_of_six/.ipc/" .. (os.getenv("USER") or "architect") .. "/tos_inbox.sh"

	local f = io.open(ipc_file, "w")
	if not f then
		return print("❌ Error writing to IPC buffer")
	end
	f:write(vim.fn.getreg("t"))
	f:close()

	local cmd = string.format("sudo -u team_of_six /mnt/team_of_six/.local/bin/tos %s wrapper", project)
	vim.cmd("botright 20split | terminal " .. cmd)
	vim.cmd("startinsert")
end

vim.keymap.set("n", "<leader>lc", "<cmd>GpChatNew edit TeamOfSix<CR>", { desc = "New Ghost [C]hat" })
vim.keymap.set("n", "<leader>lw", "<cmd>TosWork<CR>", { desc = "Ghost [W]ork Sync" })
vim.keymap.set("v", "<leader>lr", run_tos_selection, { desc = "[R]un Selection via Ghost" })
