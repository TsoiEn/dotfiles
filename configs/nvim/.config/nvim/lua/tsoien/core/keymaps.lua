vim.g.mapleader = " "

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set("i", "jk", "<ESC>", {}) -- exit insert mode
keymap.set("i", "JK", "<ESC>", {}) -- exit insert mode
keymap.set("n", "<leader>pv", vim.cmd.Ex) -- enter to filemanager

keymap.set("n", "<leader>nh", ":nohl<CR>", {}) -- clear search highlight

keymap.set("n", "x", '"_x')

-- Increment/decrement
keymap.set("n", "+", "<C-x>")
keymap.set("n", "-", "<C-a>")

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- Save file and quit
keymap.set("n", "<Leader>w", ":wa<Return>", opts)
keymap.set("n", "<Leader>q", ":qa<Return>", opts)
keymap.set("n", "<Leader>Q", ":qa!<Return>", opts)

-- Window management
keymap.set("n", "<leader>sv", "<C-w>v", opts)
keymap.set("n", "<leader>sh", "<C-w>s", opts)
keymap.set("n", "<leader>se", "<C-w>=", opts)
keymap.set("n", "<leader>sx", "<cmd>close<CR>", opts)

-- Custom keys
keymap.set("n", "<leader>rc", ":source $MYVIMRC<CR>", opts) -- Reload config
keymap.set("n", "<leader>rr", ":LspRestart<CR>", opts) -- Reload config
