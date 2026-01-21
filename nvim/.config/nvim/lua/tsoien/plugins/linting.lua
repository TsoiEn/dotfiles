-- linting.lua
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- Assign linters per filetype
		lint.linters_by_ft = {
			go = { "golangci_lint" },
			python = { "ruff" },
			json = { "jsonlint" },
			dockerfile = { "hadolint" },
			markdown = { "markdownlint" },
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
			css = { "stylelint" },
			scss = { "stylelint" },
		}

		-- Custom Ruff linter definition
		lint.linters.ruff = {
			cmd = "ruff",
			stdin = false,
			args = { "check", "--quiet", "--no-cache", "--format=compact", "--" },
			stream = "stderr",
			ignore_exitcode = true,
			parser = require("lint.parser").from_errorformat([[%f:%l:%c: %m]]),
		}

		-- Custom golangci-lint definition
		lint.linters.golangci_lint = {
			cmd = "golangci-lint",
			stdin = false,
			args = { "run", "--out-format", "line-number" },
			stream = "stdout",
			ignore_exitcode = true,
			parser = require("lint.parser").from_errorformat([[%f:%l:%c: %m]]),
		}

		-- Autocmd to trigger linting on save/enter
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				vim.schedule(function()
					lint.try_lint()
				end)
			end,
		})

		-- Manual trigger with <leader>l
		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
