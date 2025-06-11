return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		"hrsh7th/cmp-nvim-lsp", -- Required for capabilities
	},
	config = function()
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")
		local lspconfig = require("lspconfig")
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			ensure_installed = {
				-- Frontend
				"html",
				"cssls",
				"tailwindcss",
				"svelte",
				"emmet_ls",
				"tsserver",
				"graphql",

				-- Backend
				"gopls",
				"pyright",
				"jdtls",
				"clangd",
				"omnisharp",
				"sqlls",
				"dockerls",

				-- Config/Infra/Other
				"jsonls",
				"yamlls",
			},
		})

		mason_tool_installer.setup({
			ensure_installed = {
				-- Formatter: Web
				"prettier",
				"stylelint",

				-- Formatter: Lua
				"stylua",

				-- Formatter: Python
				"black",
				"isort",

				-- Formatter: Go
				"gofumpt",
				"goimports",

				-- Formatter: C/C++
				"clang-format",

				-- Formatter: SQL
				"sql-formatter",

				-- Linter: JS/TS
				"eslint_d",

				-- Linter: Python
				"pylint",

				-- Linter: Go
				"golangci-lint",

				-- Linter: Config/Markup
				"jsonlint",
				"yamllint",
				"markdownlint",
				"hadolint",
				"sqlfluff",
			},
		})

		for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
			lspconfig[server_name].setup({
				capabilities = capabilities,
			})
		end
	end,
}
