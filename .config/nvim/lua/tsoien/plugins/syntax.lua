return {
    -- treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPre", "BufNewFile" },
        build = ":TSUpdate",
        dependencies = {
            "windwp/nvim-ts-autotag",
        },
        config = function()
            local treesitter = require("nvim-treesitter.configs")

            treesitter.setup({
                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },
                indent = {
                    enable = true,
                },
                autotag = {
                    enable = true,
                },
                ensure_installed = {
                    -- Frontend
                    "html", "css", "svelte", "javascript", "typescript", "graphql",
                    -- Backend
                    "go", "python", "java", "c", "cpp", "c_sharp", "sql", "dockerfile",
                    -- Config & DB support
                    "json", "yaml",
                },
                incremental_selection = {
                    enable = true,
                    keymaps = {
                        init_selection = "<C-space>",
                        node_incremental = "<C-space>",
                        scope_incremental = false,
                        node_decremental = "<bs>",
                    },
                },
                sync_install = false,
                auto_install = true,
                ignore_install = { "haskell" },
                modules = {},
            })
        end,
    },


}
