return {
  'vim-test/vim-test',
  dependencies = {
    "preservim/vimux"
  },
  config = function ()
    local keymap = vim.keymap

    keymap.set("n", "<leader>te", ":TestNearest<CR>")
    keymap.set("n", "<leader>T", ":TestFile<CR>")
    keymap.set("n", "<leader>ta", ":TestSuite<CR>")
    keymap.set("n", "<leader>l", ":TestLast<CR>")
    keymap.set("n", "<leader>g", ":TestVisit<CR>")
    vim.cmd("let test#strategy = 'vimux'")
  end

}
