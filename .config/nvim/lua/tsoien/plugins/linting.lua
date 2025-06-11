return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- Configure linters by filetype
		lint.linters_by_ft = {
			-- Frontend
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
			css = { "stylelint" },
			scss = { "stylelint" },

			-- Backend
			go = { "golangci_lint" },
			python = { "pylint" },
			java = {}, -- Consider using LSP instead (e.g., jdtls handles linting)
			cs = {}, -- No well-supported linter for C# in nvim-lint

			-- Config/Markup
			json = { "jsonlint" },
			yaml = { "yamllint" },
			markdown = { "markdownlint" },
			dockerfile = { "hadolint" },

			-- SQL
			sql = { "sqlfluff" },
		}

		-- Autocommand to trigger linting
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		-- Manual trigger
		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
