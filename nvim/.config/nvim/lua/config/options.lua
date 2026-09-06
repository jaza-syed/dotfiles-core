-- Core editor option setup.
local M = {}

function M.setup()
  -- Core settings
  vim.opt.title = true -- Show filename in titlebar
  vim.opt.encoding = "utf-8" -- Set encoding
  vim.opt.showcmd = true -- Display incomplete commands
  vim.opt.autoread = true -- Auto-reload changed files
  vim.opt.backspace = "indent,eol,start" -- Backspace behavior
  vim.opt.tabpagemax = 100 -- More tabs
  vim.opt.wildignorecase = true -- Case-insensitive filename completion
  vim.opt.number = true -- Line numbers
  vim.opt.numberwidth = 1 -- Minimum width; grows to fit the file's line count
  vim.opt.cursorline = true -- Highlight cursor line
  vim.opt.colorcolumn = "80" -- 80-column guide
  vim.opt.updatetime = 300 -- Update time for plugins
  vim.opt.signcolumn = "yes" -- Always show sign column
  vim.opt.hidden = true -- Allow background buffers
  vim.opt.termguicolors = true -- True color support
  vim.opt.foldlevelstart = 99 -- Open files with all folds expanded
  vim.opt.wildmode = "longest,list" -- Bash-like tab completions
  vim.opt.exrc = true -- Trust-based project-local config

  -- Backup/swap file locations
  vim.fn.mkdir(vim.fn.expand("~/.vim/backup"), "p")
  vim.fn.mkdir(vim.fn.expand("~/.vim/backupf"), "p")
  vim.opt.backupdir = vim.fn.expand("~/.vim/backup")
  vim.opt.directory = vim.fn.expand("~/.vim/backupf")

  -- Search settings
  vim.opt.hlsearch = true -- Highlight search results
  vim.opt.incsearch = true -- Incremental search
  vim.opt.gdefault = true -- :s replaces all matches by default
  vim.opt.ignorecase = true -- Case insensitive search
  vim.opt.smartcase = true -- Smart case sensitivity

  -- Indentation settings
  vim.opt.copyindent = true -- Copy structure of existing lines
  vim.opt.smarttab = true -- Smart tab behavior
  vim.opt.autoindent = true -- Auto indent
  vim.opt.smartindent = true -- Smart autoindent
  vim.opt.shiftwidth = 4 -- Spaces for indents
  vim.opt.expandtab = true -- Use spaces instead of tabs
  vim.opt.tabstop = 4 -- Tab display width
  vim.opt.softtabstop = 4 -- Tab edit width

  -- Display invisible characters
  vim.opt.list = true
  vim.opt.listchars = {
    tab = "▸▸",
    trail = "·",
  }

  -- Borders on all floating windows (Neovim 0.11+)
  vim.o.winborder = "rounded"

  -- Word-granular inline diffs. Neovim 0.12 defaults to inline:char, which
  -- scatters highlights mid-word across reflowed prose.
  vim.opt.diffopt:remove("inline:char")
  vim.opt.diffopt:append("inline:word")

  -- Fold settings
  -- https://www.jackfranklin.co.uk/blog/code-folding-in-vim-neovim/
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.opt.foldcolumn = "0" -- Don't use an extra column to display fold info
  vim.opt.foldtext = "" -- First line of fold will be syntax highlighted
  vim.opt.foldlevel = 99 -- Don't close deep folds by default
  -- vim.opt.foldlevelstart = 1  -- Start with just top level folds closed
  -- Avoid Neovim's treesitter fold OptionSet refresh tripping over stale
  -- deleted-buffer fold caches during config reloads.
  vim.cmd("silent! noautocmd setglobal foldnestmax=5")
  vim.cmd("silent! noautocmd setlocal foldnestmax=5") -- Disable folding on highly nested expressions
end

return M
