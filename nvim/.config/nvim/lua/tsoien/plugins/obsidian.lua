return {
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		build = "cd app && npm install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
		ft = { "markdown" },
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" },
		opts = {},
	},
	{
		"mfussenegger/nvim-lint",
		ft = { "markdown" },
		config = function()
			local lint = require("lint")

			lint.linters_by_ft = {
				markdown = { "markdownlint-cli2" },
			}

			-- Custom args for markdownlint (instead of .markdownlint.json)
			lint.linters["markdownlint-cli2"] = {
				cmd = "markdownlint-cli2",
				stdin = true,
				args = {
					"--stdin",
					"--config",
					vim.fn.stdpath("config") .. "/lint-config/markdownlint.json",
				},
			}

			-- Auto-lint on save
			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				callback = function()
					require("lint").try_lint()
				end,
			})
		end,
	},
}
