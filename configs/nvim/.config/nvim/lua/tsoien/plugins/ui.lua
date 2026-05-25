return {
	-- Colorscheme
	{
		"rose-pine/neovim",
		name = "rose-pine",
		config = function()
			require("rose-pine").setup({
				variant = "main",
				dark_variant = "main",
				disable_background = true,
				disable_float_background = true,
				disable_italics = false,
				highlight_groups = {
					Normal = { bg = "none" },
					NormalFloat = { bg = "none" },
					StatusLine = { bg = "none" },
					StatusLineNC = { bg = "none" },
					SignColumn = { bg = "none" },
					LineNr = { bg = "none" },
				},
			})
			vim.cmd("colorscheme rose-pine")
		end,
		lazy = false,
		priority = 1000,
	},

	-- Keybinding hints
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 500
		end,
		opts = {},
	},

	-- Telescope
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			"nvim-tree/nvim-web-devicons",
			"nvim-telescope/telescope-file-browser.nvim",
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")

			telescope.setup({
				defaults = {
					path_display = { "smart" },
					file_ignore_patterns = {
						"__pycache__",
						"%.pyc",
						"%.pyo",
						"node_modules",
						"%.git/",
						"%.DS_Store",
						"%.o",
						"%.a",
						"%.out",
						"%.class",
						"build/",
						"dist/",
					},
					mappings = {
						i = {
							["<C-k>"] = actions.move_selection_previous,
							["<C-j>"] = actions.move_selection_next,
							["<C-q>"] = function(...)
								actions.send_selected_to_qflist(...)
								actions.open_qflist(...)
							end,
						},
						n = {
							["<leader>hq"] = actions.close,
						},
					},
				},
			})

			telescope.load_extension("fzf")
			telescope.load_extension("file_browser")

			local keymap = vim.keymap
			keymap.set("n", "<leader>pf", "<cmd>Telescope find_files<cr>", { desc = "Find files in cwd" })
			keymap.set("n", "<leader>ps", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
			keymap.set("n", "<leader>pr", "<cmd>Telescope oldfiles<cr>", { desc = "Find recent files" })
			keymap.set(
				"n",
				"<leader>pc",
				"<cmd>Telescope grep_string<cr>",
				{ desc = "Find string under cursor in cwd" }
			)
			keymap.set("n", "<leader>fb", "<cmd>Telescope file_browser<cr>", { desc = "Telescope file browser" })
			keymap.set("n", "<C-p>", "<cmd>Telescope git_files<cr>", { desc = "Find files in git repo" })
			keymap.set("n", "<leader>pt", "<cmd>TodoTelescope<cr>", { desc = "Find TODOs" })
		end,
	},

	-- Lualine (status line)
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({
				options = {
					icons_enabled = true,
					theme = "rose-pine",
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					disabled_filetypes = {},
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { "filename" },
					lualine_x = { "encoding", "fileformat", "filetype" },
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = { "filename" },
					lualine_x = { "location" },
					lualine_y = {},
					lualine_z = {},
				},
				tabline = {},
				extensions = {},
			})
		end,
	},

	-- Dashboard
	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",
		opts = {
			theme = "doom",
			config = {
				header = {
					"",
					"⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿",
					"            Welcome to your Dev Environment            ",
					"⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿",
					"",
				},
				center = {
					{ icon = "  ", desc = "New file", action = "enew", key = "n" },
					{ icon = "  ", desc = "Find file", action = "Telescope find_files", key = "f" },
					{ icon = "  ", desc = "Recent files", action = "Telescope oldfiles", key = "r" },
					{ icon = "  ", desc = "File browser", action = "NvimTreeToggle", key = "b" },
					{ icon = "  ", desc = "Quit", action = "qa", key = "q" },
				},
			},
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},

	-- UI Notifications and LSP messages
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = { "MunifTanjim/nui.nvim" },
		opts = function(_, opts)
			opts.presets = opts.presets or {}
			opts.routes = opts.routes or {}

			table.insert(opts.routes, {
				filter = { event = "notify", find = "No information available" },
				opts = { skip = true },
			})

			local focused = true
			vim.api.nvim_create_autocmd("FocusGained", {
				callback = function()
					focused = true
				end,
			})
			vim.api.nvim_create_autocmd("FocusLost", {
				callback = function()
					focused = false
				end,
			})

			table.insert(opts.routes, 1, {
				filter = {
					cond = function()
						return not focused
					end,
				},
				view = "notify_send",
				opts = { stop = false },
			})

			opts.commands = {
				all = {
					view = "split",
					opts = { enter = true, format = "details" },
					filter = {},
				},
			}

			opts.presets.lsp_doc_border = true
		end,
	},

	{
		"rcarriga/nvim-notify",
		opts = {
			timeout = 3000,
			background_colour = "#000000",
			render = "wrapped-compact",
		},
	},

	-- Show current file at top
	{
		"b0o/incline.nvim",
		event = "BufReadPre",
		priority = 1200,
		config = function()
			local helpers = require("incline.helpers")
			require("incline").setup({
				window = {
					padding = 0,
					margin = { horizontal = 0 },
				},
				render = function(props)
					local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
					local ft_icon, ft_color = require("nvim-web-devicons").get_icon_color(filename)
					local modified = vim.bo[props.buf].modified
					return {
						ft_icon and { " ", ft_icon, " ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) }
							or "",
						" ",
						{ filename, gui = modified and "bold,italic" or "bold" },
						" ",
						guibg = "#363944",
					}
				end,
			})
		end,
	},

	-- Git UI
	{
		"kdheepak/lazygit.nvim",
		keys = {
			{ "<leader>lg", ":LazyGit<CR>", desc = "Open LazyGit", silent = true },
		},
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- SQL/Database UI
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		dependencies = {
			"tpope/vim-dadbod",
			{ "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" } },
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
		end,
		keys = {
			{ "<leader>d", "<cmd>NvimTreeClose<cr><cmd>tabnew<cr><cmd>DBUI<cr>", desc = "Open DB UI" },
		},
	},

	-- undo tree
	{
		"jiaoshijie/undotree",
		dependencies = "nvim-lua/plenary.nvim",
		config = true,
		keys = { -- load the plugin only when using it's keybinding:
			{ "<leader>u", "<cmd>lua require('undotree').toggle()<cr>" },
		},
	},
}
