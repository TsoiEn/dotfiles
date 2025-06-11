return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				-- Frontend
				javascript = { "prettier" },
				typescript = { "prettier" },
				javascriptreact = { "prettier" },
				typescriptreact = { "prettier" },
				svelte = { "prettier" },
				css = { "prettier" },
				scss = { "prettier" },
				html = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				graphql = { "prettier" },
				liquid = { "prettier" },

				-- Backend
				lua = { "stylua" },
				python = { "isort", "black" },
				go = { "goimports", "gofumpt" },
				java = {}, -- Generally formatted by jdtls LSP
				c = { "clang_format" },
				cpp = { "clang_format" },
				cs = {}, -- Not natively supported by conform
				sql = { "sql_formatter" },

				-- Configs and others
				dockerfile = {}, -- Usually handled by LSP
				toml = {}, -- Optional, prettier can handle some cases
			},

			format_on_save = { -- Fixed typo: was `format_afteron_save`
				lsp_fallback = true,
			},
		})

		-- Keymap for manual formatting
		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format({
				lsp_fallback = true,
				async = true,
				timeout_ms = 5000,
			})
		end, { desc = "Format file or range (in visual mode)" })
	end,
}
