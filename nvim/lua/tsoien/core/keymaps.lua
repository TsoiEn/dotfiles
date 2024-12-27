vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>", {}) -- exit insert mode
keymap.set("n", "<leader>pv", vim.cmd.Ex) -- enter to filemanager

keymap.set("n", "<leader>nh", ":nohl<CR>", {}) -- clear search highlight

--increment/decrement
keymap.set("n", "<leader>+", "<C-a>", {}) -- increment number?
keymap.set("n", "<leader>-", "<C-x>", {}) -- decrement number?

-- window management
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", {}) -- new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", {}) -- close tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", {}) --  next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", {}) --  prev tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", {}) -- buffer new tab
