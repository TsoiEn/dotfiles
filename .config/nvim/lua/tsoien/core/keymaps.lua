vim.g.mapleader = " "

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set("i", "jk", "<ESC>", {}) -- exit insert mode
keymap.set("i", "JK", "<ESC>", {}) -- exit insert mode
keymap.set("n", "<leader>pv", vim.cmd.Ex) -- enter to filemanager

keymap.set("n", "<leader>nh", ":nohl<CR>", {}) -- clear search highlight

keymap.set("n", "x", '"_x')

-- Increment/decrement
keymap.set("n", "+", "<C-a>")
keymap.set("n", "-", "<C-x>")

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- Save file and quit
keymap.set("n", "<Leader>w", ":wa<Return>", opts)
keymap.set("n", "<Leader>q", ":wqa<Return>", opts)
keymap.set("n", "<Leader>Q", ":qa!<Return>", opts)
