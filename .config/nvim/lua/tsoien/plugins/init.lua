return {
	{ "nvim-lua/plenary.nvim" },
	{
		"christoomey/vim-tmux-navigator",
		config = function()
			vim.g.tmux_navigator_no_mappings = 1
			vim.api.nvim_set_keymap("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true })
			vim.api.nvim_set_keymap("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { noremap = true, silent = true })
			vim.api.nvim_set_keymap("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { noremap = true, silent = true })
			vim.api.nvim_set_keymap("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { noremap = true, silent = true })
		end,
	},
}
