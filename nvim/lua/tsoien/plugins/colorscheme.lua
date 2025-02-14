return {
    "rose-pine/neovim",
    name = "rose-pine",
    config = function()
        require("rose-pine").setup({
            variant = "main", -- or "moon" / "dawn" depending on your preference
            dark_variant = "main", -- Ensures a dark theme variant
            disable_background = true, -- Makes the background transparent
            extend_background_behind_borders = false, -- Prevents extending bg to floating windows
        })
        vim.cmd("colorscheme rose-pine")
    end
}
