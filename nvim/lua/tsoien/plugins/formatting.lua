return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local conform = require("conform")

        conform.setup({
            formatters_by_ft = {
                javascript = { "prettier" },
                typescript = { "prettier" },
                javascriptreact = { "prettier" },
                typescriptreact = { "prettier" },
                svelte = { "prettier" },
                css = { "prettier" },
                html = { "prettier" },
                json = { "prettier" },
                yaml = { "prettier" },
                markdown = { "prettier" },
                graphql = { "prettier" },
                liquid = { "prettier" },
                lua = { "stylua" },
                python = { "isort", "black" },
                go = { "goimports", "gofmt" },
            },
            format_afteron_save = {
                lsp_fallback = true,
                async = true, -- Enable async formatting
                timeout_ms = 6000, -- Increased timeout to 5 seconds
            },
        })

        vim.keymap.set({ "n", "v" }, "<leader>mp", function()
            conform.format({
                lsp_fallback = true,
                async = true, -- Enable async formatting for manual format command
                timeout_ms = 5000, -- Increased timeout
            })
        end, { desc = "Format file or range (in visual mode)" })
    end,
}
