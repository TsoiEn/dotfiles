local opt = vim.opt

--General settings
opt.number = true -- Enable line numbers
opt.relativenumber = true -- Enable relative line numbers

-- Tabs & indentation
opt.tabstop = 4 -- Number of spaces a tab counts for
opt.shiftwidth = 4 -- Number of spaces for auto-indents
opt.expandtab = true -- Use spaces instead of tabs
opt.autoindent = true -- Enable auto-indentation
opt.smartindent = true -- Smarter auto-indentation

-- Wrapping
opt.wrap = true -- Disable line wrapping
opt.linebreak = true -- Break lines at word boundaries when wrapping is enabled
opt.breakindent = true -- Indent wrapped lines visually

-- Clipboard
opt.clipboard:append("unnamedplus") -- Use system clipboard

-- Backspace behavior
opt.backspace = "indent,eol,start" -- Allow backspacing over indentation, EOLs, and insert start

-- Cursor and UI enhancements
opt.cursorline = true -- Highlight the current line
opt.termguicolors = true -- Enable 24-bit RGB colors
opt.background = "dark" -- Use dark background
opt.signcolumn = "yes" -- Always show the sign column

-- Splitting behavior
opt.splitright = true -- Vertical splits open to the right
opt.splitbelow = true -- Horizontal splits open below
opt.splitkeep = "cursor" -- Keep the cursor in place when splitting

-- Search settings
opt.ignorecase = true -- Case-insensitive search
opt.hlsearch = true -- Highlight search matches
opt.inccommand = "split" -- Preview substitutions incrementally
opt.smarttab = true -- Tab behavior is smart

-- Backup and file behavior
opt.backup = false -- Disable file backups
opt.scrolloff = 10 -- Keep 10 lines visible above/below the cursor
opt.title = true -- Set the terminal title based on the file
opt.showcmd = true -- Display the current command in the last line
opt.cmdheight = 0 -- Reduce the command-line height
opt.laststatus = 0 -- Hide the status line in some contexts

-- Mouse (if needed, enable or adjust here)
-- opt.mouse = ''
