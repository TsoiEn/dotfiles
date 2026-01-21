return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		"hrsh7th/cmp-nvim-lsp",
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

		local servers = {
			"html",
			"cssls",
			"tailwindcss",
			"svelte",
			"emmet_ls",
			"graphql",
			"gopls",
			"pyright",
			"jdtls",
			"clangd",
			"omnisharp",
			"dockerls",
			"jsonls",
			"yamlls",
		}

		mason_lspconfig.setup({
			ensure_installed = servers,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				-- Formatters
				"prettier",
				"stylua",
				"black",
				"isort",
				"gofumpt",
				"goimports",
				"clang-format",

				-- Linters
				"eslint_d",
				"pylint",
				"golangci-lint",
				"jsonlint",
				"yamllint",
				"markdownlint",
				"hadolint",
			},
			auto_update = false,
		})

		for _, server in ipairs(servers) do
			if server ~= "lua_ls" then
				lspconfig[server].setup({
					capabilities = capabilities,
				})
			end
		end
	end,
}
