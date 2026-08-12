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
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		-- Mason setup
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		-- Servers to install
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

		-- Ensure servers are installed
		mason_lspconfig.setup({
			ensure_installed = servers,
		})

		-- Tools installer
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

		-- gopls configuration
		vim.lsp.config("gopls", {
			capabilities = capabilities,
			settings = {
				gopls = {
					staticcheck = false,
				},
			},
		})

		-- Enable gopls
		vim.lsp.enable("gopls")

		-- Configure and enable other servers
		for _, server in ipairs(servers) do
			if server ~= "gopls" then
				vim.lsp.config(server, {
					capabilities = capabilities,
				})

				vim.lsp.enable(server)
			end
		end
	end,
}
