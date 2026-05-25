return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		event = { "BufReadPre", "BufNewFile" },
		build = ":TSUpdate",
		dependencies = {
			"windwp/nvim-ts-autotag",
		},
	},

	{
		"MeanderingProgrammer/treesitter-modules.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {
			highlight = { enable = true },
			indent = { enable = true },
			autotag = { enable = true },

			ensure_installed = {
				"html",
				"css",
				"svelte",
				"javascript",
				"typescript",
				"graphql",
				"go",
				"python",
				"java",
				"c",
				"cpp",
				"c_sharp",
				"dockerfile",
				"json",
				"yaml",
				"lua",
				"vim",
				"markdown",
				"regex",
				"bash",
			},

			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<C-space>",
					node_incremental = "<C-space>",
					scope_incremental = "<C-s>",
					node_decremental = "<BS>",
				},
			},

			auto_install = true,
		},
	},
}
