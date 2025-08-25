return {
	"epwalsh/obsidian.nvim",
	version = "*", -- Use latest release
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {

		workspaces = {
			{
				name = "work",
				path = "~/Development/projects/Work/notes",
			},
		},

		ui = {
			enable = true, -- enable Obsidian UI features like conceal
		},
	},
	config = function(_, opts)
		require("obsidian").setup(opts)

		-- Set conceallevel to 2 for markdown files
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				vim.opt_local.conceallevel = 2
			end,
		})
	end,
}
