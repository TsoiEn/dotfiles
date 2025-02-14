return {
    "epwalsh/obsidian.nvim",
    version = "*",  -- Latest release
    lazy = true,
    ft = "markdown",
    dependencies = { "nvim-lua/plenary.nvim" },

    opts = {
        workspaces = {
            {
                name = "personal",
                path = "~/github/personal/documtation",
                overrides = {
                    notes_subdir = "notes",
                    daily_notes = { folder = "daily" },
                },
            },
        },
        link_across_workspaces = true,
        log_level = vim.log.levels.WARN,
        use_frontmatter = true,  -- For metadata and tasks
        completion = { nvim_cmp = true },  -- Enable note linking
    },

    -- Markdown preview plugin
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        build = "cd ~/.local/share/nvim/lazy/markdown-preview.nvim/app && yarn install",
        ft = { "markdown" },
    }
}

