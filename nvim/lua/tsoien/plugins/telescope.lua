return{
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        "nvim-tree/nvim-web-devicons",
        "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")
        local builtin = require("telescope.builtin") -- Correctly load the built-in module

        telescope.setup({
            defaults = {
                path_display = { "smart" },
                mappings = {
                    i = {
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
                    },
                    n = {
                        ["<leader>hq"] = actions.close,
                    }
                },
            },
        })

        telescope.load_extension("fzf")
        telescope.load_extension("file_browser") -- Load the file_browser extension

        -- Keymaps
        local keymap = vim.keymap

        keymap.set("n", "<leader>pf", "<cmd>Telescope find_files<cr>", { desc = "find files in cwd" })
        keymap.set("n", "<leader>ps", "<cmd>Telescope live_grep<cr>", { desc = "find string in cwd" })
        keymap.set("n", "<leader>pr", "<cmd>Telescope oldfiles<cr>", { desc = "find recent files" })
        keymap.set("n", "<leader>pc", "<cmd>Telescope grep_string<cr>", { desc = "find string under cursor in cwd" })
        keymap.set("n", "<C-p>", "<cmd>Telescope git_files<cr>", { desc = "find files in git repo" })
        keymap.set("n", "<leader>pt", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
    end,
}
