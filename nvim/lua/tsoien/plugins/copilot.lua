return{
    "github/copilot.vim",
    config = function()
        vim.g.copilot_no_tab_map = true -- Disable default tab completion for Copilot
        vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
    end,

}
