return {
	{
		"ThePrimeagen/99",
		dependencies = { "nvim-telescope/telescope.nvim", "hrsh7th/nvim-cmp" },
		config = function()
			local _99 = require("99")
			local cwd = vim.uv.cwd()
			local basename = vim.fs.basename(cwd)

			_99.setup({
				-- opencode is the plugin default; you have both CLIs installed
				provider = _99.Providers.ClaudeCodeProvider,
				-- the provider default is claude-sonnet-4-5; "sonnet" also works
				model = "claude-sonnet-5-5",

				logger = {
					level = _99.DEBUG,
					type = "file",
					path = "/tmp/" .. basename .. ".99.debug",
					print_on_error = true,
				},

				-- must live inside the cwd or claude/opencode will refuse to read it
				tmp_dir = (function()
					-- the dir only exists while nvim runs, so it never lingers in git status
					vim.api.nvim_create_autocmd("VimLeavePre", {
						callback = function()
							vim.fn.delete(cwd .. "/tmp", "rf")
						end,
					})
					return "./tmp"
				end)(),

				completion = {
					source = "cmp",
				},

				-- auto-attached when found next to the file the request came from
				md_files = {
					"AGENT.md",
					"CLAUDE.md",
				},
			})

			-- 99 writes its work-item straight to tmp_dir without creating it
			-- first (extensions/work/worker.lua:71), so <leader>9w errors with
			-- "unable to save work item" in any project lacking a tmp/ dir.
			local created_dirs = {}

			local function ensure_tmp_dir()
				local dir = vim.fn.getcwd() .. "/tmp"
				if not vim.uv.fs_stat(dir) then
					vim.fn.mkdir(dir, "p")
					created_dirs[dir] = true
				end
			end

			-- true when the dir is empty or only holds files 99 wrote (99-*)
			local function only_99_files(dir)
				local handle = vim.uv.fs_scandir(dir)
				if not handle then
					return false
				end
				while true do
					local name = vim.uv.fs_scandir_next(handle)
					if not name then
						return true
					end
					if not vim.startswith(name, "99") then
						return false
					end
				end
			end

			ensure_tmp_dir()
			vim.api.nvim_create_autocmd("DirChanged", {
				callback = ensure_tmp_dir,
			})

			-- only remove dirs this session created, so a user's own tmp/ is never touched
			vim.api.nvim_create_autocmd("VimLeavePre", {
				callback = function()
					for dir in pairs(created_dirs) do
						if vim.uv.fs_stat(dir) and only_99_files(dir) then
							vim.fn.delete(dir, "rf")
						end
					end
				end,
			})

			local keymap = vim.keymap

			-- visual mode only, so an old selection never gets reused by accident
			keymap.set("v", "<leader>9v", function()
				_99.visual()
			end, { desc = "99 replace selection" })
			keymap.set("n", "<leader>9s", function()
				_99.search()
			end, { desc = "99 search project" })
			keymap.set("n", "<leader>9o", function()
				_99.open()
			end, { desc = "99 open last interaction" })
			keymap.set("n", "<leader>9x", function()
				_99.stop_all_requests()
			end, { desc = "99 stop requests" })
			keymap.set("n", "<leader>9c", function()
				_99.clear_previous_requests()
			end, { desc = "99 clear requests" })
			keymap.set("n", "<leader>9l", function()
				_99.view_logs()
			end, { desc = "99 view logs" })

			-- persistent work item, then search for what is left to do
			keymap.set("n", "<leader>9w", function()
				_99.Extensions.Worker.set_work()
			end, { desc = "99 set work" })
			keymap.set("n", "<leader>9W", function()
				_99.Extensions.Worker.search()
			end, { desc = "99 search work" })

			keymap.set("n", "<leader>9m", function()
				require("99.extensions.telescope").select_model()
			end, { desc = "99 select model" })
			keymap.set("n", "<leader>9p", function()
				require("99.extensions.telescope").select_provider()
			end, { desc = "99 select provider" })
		end,
	},
}
