return {
    {
        "theprimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local harpoon = require("harpoon")
            harpoon:setup()

            local conf = require("telescope.config").values
            local function toggle_telescope(harpoon_files)
                local file_paths = {}
                for _, item in ipairs(harpoon_files.items) do
                    table.insert(file_paths, item.value)
                end

                require("telescope.pickers").new({}, {
                    prompt_title = "Harpoon",
                    finder = require("telescope.finders").new_table({
                        results = file_paths,
                    }),
                    previewer = conf.file_previewer({}),
                    sorter = conf.generic_sorter({}),
                }):find()
            end

            local keymap = vim.keymap

            keymap.set("n", "<leader>ad", function() harpoon:list():add() end, { desc = "add file" })
            keymap.set("n", "<leader>rm", function() harpoon:list():remove() end, {desc = "remove harpoon file"})
            keymap.set("n", "<leader>a", function() toggle_telescope(harpoon:list()) end, { desc = "Toggle harpoon ui" })
            for i = 1, 5 do
                vim.keymap.set("n", "<leader>" .. i, function()
                    harpoon:list():select(i)
                end, { desc = "Navigate to Harpoon file " .. i })
            end
        end,
    },
}
