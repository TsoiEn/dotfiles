return {
    "rose-pine/neovim",
    name = "rose-pine",
    config = function()
        require("rose-pine").setup({
            variant = "main", -- main, moon, or dawn
            dark_variant = "main", -- Used for dark variant
            disable_background = true, -- Makes the background transparent
            disable_float_background = true, -- Makes floating window backgrounds transparent 
            disable_italics = false, -- Keeps italics enabled
            -- Highlight groups can be customized
            highlight_groups = {
                -- Ensure consistent background colors
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
    -- LazyVim specific settings
    lazy = false,
    priority = 1000, -- Ensures the colorscheme loads early
}
