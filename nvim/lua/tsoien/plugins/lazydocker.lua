return {
    "crnvl96/lazydocker.nvim",
    event = "VeryLazy",
    opts = {
        popup_window = {
            enter = true,
            focusable = true,
            zindex = 40,
            position = "50%",
            relative = "win",
            size = {
                width = "90%",
                height = "90%",
            },
            buf_options = {
                modifiable = true,
                readonly = false,
            },
            win_options = {
                winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                winblend = 0,
            },
            border = {
                highlight = "FloatBorder",
                style = "rounded",
                text = {
                    top = " Lazydocker ",
                },
            },
        },
    },
    dependencies = {
        "MunifTanjim/nui.nvim",
    },
    config = function(_, opts)
        require("lazydocker").setup(opts)
        -- Add the key mapping
        vim.keymap.set("n", "<leader>ld", ":LazyDocker<CR>", { desc = "Open Lazydocker" })
    end,
}


