return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- Assign linters per filetype
		lint.linters_by_ft = {
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
			css = { "stylelint" },
			scss = { "stylelint" },
			python = { "ruff" }, -- ✅ Use Ruff for Python
			json = { "jsonlint" },
			dockerfile = { "hadolint" },
			sql = { "sqlfluff" },
		}

		-- Custom Ruff linter definition
		lint.linters.ruff = {
			cmd = "ruff",
			stdin = false, -- Ruff uses file paths, not stdin
			args = {
				"check",
				"--quiet",
				"--no-cache",
				"--format=compact",
				"--",
			},
			stream = "stderr",
			ignore_exitcode = true,
			parser = require("lint.parser").from_errorformat([[%f:%l:%c: %m]]),
		}

		-- Autocmd to trigger linting
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				vim.schedule(function()
					vim.notify("Linting file with Ruff...", vim.log.levels.INFO)
					lint.try_lint()
				end)
			end,
		})

		-- Manual trigger with <leader>l
		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })

		-- Optional: Run Ruff --fix manually with <leader>rf
		vim.keymap.set("n", "<leader>rf", function()
			vim.cmd("write") -- save current file
			vim.fn.jobstart({ "ruff", "check", "--fix", vim.fn.expand("%") }, {
				stdout_buffered = true,
				on_exit = function(_, code)
					if code == 0 then
						vim.notify("Ruff fix applied", vim.log.levels.INFO)
						vim.cmd("edit") -- reload file
					else
						vim.notify("Ruff fix failed", vim.log.levels.ERROR)
					end
				end,
			})
		end, { desc = "Run Ruff --fix on current file" })
	end,
}
