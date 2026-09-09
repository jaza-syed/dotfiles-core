-- Startup bootstrap for vim.pack plugins and editor integrations.

vim.loader.enable() -- Byte-compiled Lua module cache; lazy.nvim carried its own

vim.g.mapleader = " " -- Must be set before plugin setup

-- Per-machine module linked by the machine repo; see config.machine.
local machine_path = vim.fn.expand("~/.config/nvim-local")
if vim.uv.fs_stat(machine_path) then
  vim.opt.rtp:prepend(machine_path)
end

local function gh(repo)
  return "https://github.com/" .. repo
end

-- Build steps, registered before the first add so a fresh install runs them.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("dotfiles_pack_build", { clear = true }),
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
      vim.system({ "make" }, { cwd = ev.data.path }):wait()
    elseif name == "nvim-treesitter" and kind == "update" then
      -- Parsers follow the plugin; a fresh install gets them from install()
      -- below, where the plugin is already on the runtimepath.
      require("nvim-treesitter").update()
    end
  end,
})

-- Globals read by plugin/ files, which Nvim sources at the end of startup.
vim.g.tradewinds_no_maps = 1
vim.g.wrapwidth_sign = "│"
vim.g.virtcolumn_char = "┆"
vim.g.rooter_cd_cmd = "lcd"
vim.g.rooter_silent_chdir = 1
vim.g.rooter_patterns = {
  -- .envrc marks a devshell root; keep it first so :pwd lands at the
  -- direnv/sub-repo root. flake.nix follows but is unreliable alone
  -- (stray copies exist, e.g. under redback/.elm/…).
  ".envrc",
  ".git",
  "flake.nix",
  "stack.yaml",
  "*.cabal",
  "cabal.project",
  "package.yaml",
  "hie.yaml",
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "pyrightconfig.json",
  "Cargo.toml",
  "rust-project.json",
  "go.mod",
  "stylua.toml",
  ".luarc.json",
  "Makefile",
  "justfile",
}
vim.g["conjure#client_on_load"] = false
vim.g["conjure#filetypes"] = { "clojure" }

vim.pack.add({
  -- Shared libraries
  gh("nvim-lua/plenary.nvim"),
  gh("nvim-neotest/nvim-nio"),
  gh("MunifTanjim/nui.nvim"),
  gh("antoinemadec/FixCursorHold.nvim"),
  gh("nvim-mini/mini.icons"),

  -- Text manipulation
  gh("nvim-mini/mini.files"),
  gh("nvim-mini/mini.surround"),
  gh("nvim-mini/mini.splitjoin"),
  gh("nvim-mini/mini.align"),
  gh("nvim-mini/mini.ai"),
  gh("nvim-mini/mini.operators"),
  gh("nvim-mini/mini.clue"),
  gh("windwp/nvim-autopairs"),
  gh("tpope/vim-repeat"), -- Repeat plugin commands
  { src = gh("smoka7/hop.nvim"), version = vim.version.range("*") },

  -- Windows and quickfix
  { src = gh("s1n7ax/nvim-window-picker"), version = vim.version.range("2.*") },
  gh("nvim-zh/colorful-winsep.nvim"),
  gh("andymass/vim-tradewinds"),
  gh("Bekaboo/dropbar.nvim"),
  gh("stevearc/quicker.nvim"),

  -- Git integration
  gh("lewis6991/gitsigns.nvim"),
  gh("dlyongemallo/diffview-plus.nvim"),
  gh("clabby/difftastic.nvim"),
  gh("NeogitOrg/neogit"),

  -- Fuzzy finding
  gh("nvim-telescope/telescope.nvim"),
  gh("nvim-telescope/telescope-fzf-native.nvim"),
  gh("nvim-telescope/telescope-ui-select.nvim"),
  { src = gh("nvim-telescope/telescope-live-grep-args.nvim"), version = vim.version.range("^1.0.0") },
  gh("jvgrootveld/telescope-zoxide"),
  gh("jmacadie/telescope-hierarchy.nvim"),

  -- Tmux and project roots
  gh("christoomey/vim-tmux-navigator"), -- Navigate between tmux panes
  gh("airblade/vim-rooter"),

  -- Comment annotations
  gh("folke/todo-comments.nvim"),

  -- Treesitter
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  { src = gh("nvim-treesitter/nvim-treesitter-textobjects"), version = "main" },

  -- Display
  gh("rickhowe/wrapwidth"),
  gh("karb94/neoscroll.nvim"),
  gh("xiyaowong/virtcolumn.nvim"),
  gh("stevearc/oil.nvim"),
  gh("nvim-lualine/lualine.nvim"),
  gh("folke/zen-mode.nvim"),

  -- LSP, completion and linting
  gh("folke/lazydev.nvim"),
  gh("hrsh7th/nvim-cmp"),
  gh("hrsh7th/cmp-nvim-lsp"),
  gh("mfussenegger/nvim-lint"),

  -- Debugging
  gh("mfussenegger/nvim-dap"),
  gh("mfussenegger/nvim-dap-python"),
  gh("rcarriga/nvim-dap-ui"),

  -- Testing
  gh("nvim-neotest/neotest"),
  gh("nvim-neotest/neotest-python"),
  gh("rouge8/neotest-rust"),

  -- Clojure and TidalCycles
  gh("julienvincent/nvim-paredit"),
  gh("grddavies/tidal.nvim"),
}, { confirm = false })

-- Conjure attaches a client to Clojure buffers, so it is added on request
-- rather than at startup. vim.pack still keeps it installed and locked, since
-- it reinstalls anything the lockfile names but the disk lacks.
vim.api.nvim_create_user_command("ConjureStart", function()
  vim.pack.add({ gh("Olical/conjure") }, { confirm = false })
end, { desc = "Load Conjure on demand" })

-- review.nvim is a local checkout rather than an installed plugin.
local review_dir = vim.fn.expand("~/code/jaza-syed/review.nvim")
local review_present = vim.fn.isdirectory(review_dir) == 1
if review_present then
  vim.opt.rtp:append(review_dir)
end

-- Icons first, since the pickers and dropbar read the devicons mock.
require("mini.icons").setup()
require("mini.icons").mock_nvim_web_devicons()

local mini_files = require("mini.files")
mini_files.setup({
  windows = {
    preview = true,
  },
})
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  callback = function(args)
    vim.keymap.set("n", "<CR>", function()
      local entry = mini_files.get_fs_entry()
      if entry and entry.fs_type == "directory" then
        mini_files.close()
        vim.cmd("Oil " .. vim.fn.fnameescape(entry.path))
      else
        mini_files.go_in({ close_on_file = true })
      end
    end, { buffer = args.data.buf_id, desc = "Open entry (dirs in Oil)" })
  end,
})

require("mini.surround").setup({
  mappings = {
    add = "ys",
    delete = "ds",
    replace = "cs",
    find = "",
    find_left = "",
    highlight = "",
    update_n_lines = "",
  },
})
require("mini.splitjoin").setup({})
require("mini.align").setup({})
require("mini.ai").setup({})
require("mini.operators").setup({})

local clue = require("mini.clue")
clue.setup({
  triggers = {
    { mode = "n", keys = "<Leader>" },
    { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" },
    { mode = "x", keys = "g" },
    { mode = "n", keys = "'" },
    { mode = "n", keys = "`" },
    { mode = "x", keys = "'" },
    { mode = "x", keys = "`" },
    { mode = "n", keys = '"' },
    { mode = "x", keys = '"' },
    { mode = "i", keys = "<C-r>" },
    { mode = "c", keys = "<C-r>" },
    { mode = "n", keys = "<C-w>" },
    { mode = "n", keys = "z" },
    { mode = "x", keys = "z" },
  },
  clues = {
    { mode = "n", keys = "<Leader>f", desc = "+find" },
    { mode = "n", keys = "<Leader>l", desc = "+lsp" },
    { mode = "n", keys = "<Leader>lc", desc = "+call hierarchy" },
    { mode = "n", keys = "<Leader>ld", desc = "+goto definition" },
    { mode = "n", keys = "<Leader>lt", desc = "+goto type definition" },
    { mode = "n", keys = "<Leader>d", desc = "+debug" },
    { mode = "n", keys = "<Leader>n", desc = "+test" },
    { mode = "n", keys = "<Leader>g", desc = "+git" },
    { mode = "n", keys = "<Leader>q", desc = "+quickfix" },
    -- review.nvim registers its own <Leader>r groups.
    { mode = "n", keys = "<Leader>h", desc = "+hunks" },
    { mode = "n", keys = "<Leader>w", desc = "+window" },
    { mode = "n", keys = "<Leader>t", desc = "+tab/theme" },
    { mode = "n", keys = "<Leader>c", desc = "+config/clear" },
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
    clue.gen_clues.windows(),
    clue.gen_clues.z(),
  },
  window = {
    delay = 500,
  },
})

-- mini.clue only maps triggers in listed buffers, so review.nvim's
-- unlisted scratch splits need them installed by hand.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("dotfiles_clue_review", { clear = true }),
  pattern = "review://*",
  callback = function(ev)
    clue.enable_buf_triggers(ev.buf)
  end,
})

require("nvim-autopairs").setup()
require("cmp").event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())

require("hop").setup()

require("window-picker").setup({
  hint = "floating-big-letter",
})
vim.keymap.set("n", "<Leader>ww", function()
  local win = require("window-picker").pick_window()
  if win then
    vim.api.nvim_set_current_win(win)
  end
end, { desc = "Pick window" })

require("colorful-winsep").setup({
  -- Double lines read as the nested layer against tmux's heavy pane borders.
  border = "double",
  animate = {
    enabled = false,
  },
})

require("config.dropbar").setup()

require("quicker").setup({})
vim.keymap.set("n", "<leader>qq", function()
  require("quicker").toggle()
end, { desc = "Toggle quickfix" })
vim.keymap.set("n", "<leader>ql", function()
  require("quicker").toggle({ loclist = true })
end, { desc = "Toggle location list" })

require("gitsigns").setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "-" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
    untracked = { text = "+" },
  },
  on_attach = function(bufnr)
    local gitsigns = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    vim.keymap.set("n", "]c", function()
      if vim.wo.diff then
        return "]c"
      end
      vim.schedule(gitsigns.next_hunk)
      return "<Ignore>"
    end, { buffer = bufnr, expr = true, desc = "Next git hunk" })

    vim.keymap.set("n", "[c", function()
      if vim.wo.diff then
        return "[c"
      end
      vim.schedule(gitsigns.prev_hunk)
      return "<Ignore>"
    end, { buffer = bufnr, expr = true, desc = "Previous git hunk" })

    map("n", "<leader>hs", gitsigns.stage_hunk, "Stage git hunk")
    map("n", "<leader>hr", gitsigns.reset_hunk, "Reset git hunk")
    map("v", "<leader>hs", function()
      gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage selected git hunk")
    map("v", "<leader>hr", function()
      gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Reset selected git hunk")
    map("n", "<leader>hS", gitsigns.stage_buffer, "Stage git buffer")
    map("n", "<leader>hR", gitsigns.reset_buffer, "Reset git buffer")
    map("n", "<leader>hp", gitsigns.preview_hunk, "Preview git hunk")
    map("n", "<leader>hb", function()
      gitsigns.blame_line({ full = true })
    end, "Blame git line")
    map("n", "<leader>hd", gitsigns.diffthis, "Diff git file")
    map("n", "<leader>hD", function()
      gitsigns.diffthis("~")
    end, "Diff git file against HEAD~")
    map("n", "<leader>hQ", gitsigns.setqflist, "Git hunks to quickfix")
    map("n", "<leader>ht", gitsigns.toggle_deleted, "Toggle deleted git lines")
  end,
})

require("diffview").setup({
  -- Off because it works through 'winhighlight', which the window
  -- namespaces set below take precedence over. The per-side diff
  -- namespaces reproduce its left-pane remap instead.
  enhanced_diff_hl = false,
  view = {
    cycle_layouts = {
      default = {
        "diff2_horizontal",
        "diff2_vertical",
        "diff1_inline",
      },
    },
  },
  hooks = {
    diff_buf_win_enter = function(_, winid, ctx)
      require("colors").apply_diff_window_highlights(winid, ctx and ctx.symbol)
    end,
  },
})

local difftastic = require("difftastic-nvim")
difftastic.setup({
  download = true,
  vcs = "git",
})
require("config.diff_windows").configure_difftastic(difftastic)

require("neogit").setup({
  integrations = {
    diffview = true,
  },
})

if review_present then
  local review = require("review")
  local workspace_root = require("config.machine").workspace_root
  review.setup({
    -- Pinned so the workspace commands work outside the mani root.
    workspace = workspace_root and { mani = workspace_root .. "/mani.yaml" } or nil,
    -- lualine owns the tabline and renders review.tab_label itself.
    tab_titles = false,
  })
  -- review.nvim binds these buffer-locally inside a review. Mirror them
  -- globally on the same keys, since a capital under <Leader>r now means
  -- "post to GitLab now".
  vim.keymap.set("n", "<Leader>rrm", review.prompt_open_mr, { desc = "Attach a GitLab MR" })
  vim.keymap.set("n", "<Leader>rrl", review.select_mr, { desc = "Select from open MRs" })
end

local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local live_grep_args_actions = require("telescope-live-grep-args.actions")
local themes = require("telescope.themes")

telescope.setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_strategy = "vertical",
    layout_config = {
      prompt_position = "top",
      vertical = {
        mirror = true,
        preview_height = 0.5,
      },
    },
    mappings = {
      i = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
      },
      n = {
        ["<C-j>"] = telescope_actions.move_selection_next,
        ["<C-k>"] = telescope_actions.move_selection_previous,
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    ["ui-select"] = themes.get_dropdown({}),
    live_grep_args = {
      auto_quoting = true,
      additional_args = { "--hidden" },
      mappings = {
        i = {
          ["<C-g>"] = live_grep_args_actions.to_fuzzy_refine,
        },
        n = {
          ["<C-g>"] = live_grep_args_actions.to_fuzzy_refine,
        },
      },
    },
    hierarchy = {
      initial_multi_expand = false,
      multi_depth = 5,
      layout_strategy = "horizontal",
    },
    zoxide = {
      mappings = {
        default = {
          action = function(selection)
            vim.cmd("lcd " .. vim.fn.fnameescape(selection.path))
          end,
          after_action = function(selection)
            vim.schedule(function()
              require("oil").open(selection.path)
            end)
          end,
        },
      },
    },
  },
})

telescope.load_extension("fzf")
telescope.load_extension("live_grep_args")
telescope.load_extension("ui-select")
telescope.load_extension("hierarchy")
telescope.load_extension("zoxide")

require("todo-comments").setup({
  signs = false,
  gui_style = {
    fg = "BOLD",
    bg = "NONE",
  },
  highlight = {
    before = "",
    keyword = "fg",
    after = "fg",
    comments_only = true,
  },
  keywords = {
    FIX = { color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
    TODO = { color = "error" },
    HACK = { color = "warning" },
    WARN = { color = "warning", alt = { "WARNING", "XXX" } },
    NOTE = { color = "warning", alt = { "INFO" } },
  },
  colors = {
    error = { "DiagnosticError", "ErrorMsg" },
    warning = { "DiagnosticWarn", "WarningMsg" },
  },
})

local treesitter = require("nvim-treesitter")
treesitter.setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})
treesitter.install({
  "bash",
  "c",
  "clojure",
  "cpp",
  "diff",
  "go",
  "haskell",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "nix",
  "python",
  "query",
  "rust",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}, { max_jobs = 4 })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("SettingsTreesitter", { clear = true }),
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "V",
    },
  },
  move = {
    set_jumps = true,
  },
})

local ts_select = require("nvim-treesitter-textobjects.select")
local ts_move = require("nvim-treesitter-textobjects.move")

local function textobject(lhs, capture, desc)
  vim.keymap.set({ "x", "o" }, lhs, function()
    ts_select.select_textobject(capture, "textobjects")
  end, { desc = desc })
end

textobject("aa", "@parameter.outer", "Around parameter")
textobject("ia", "@parameter.inner", "Inside parameter")
textobject("af", "@function.outer", "Around function")
textobject("if", "@function.inner", "Inside function")
textobject("ac", "@class.outer", "Around class")
textobject("ic", "@class.inner", "Inside class")

vim.keymap.set({ "n", "x", "o" }, "]f", function()
  ts_move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
vim.keymap.set({ "n", "x", "o" }, "[f", function()
  ts_move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
vim.keymap.set({ "n", "x", "o" }, "]F", function()
  ts_move.goto_next_end("@function.outer", "textobjects")
end, { desc = "Next function end" })
vim.keymap.set({ "n", "x", "o" }, "[F", function()
  ts_move.goto_previous_end("@function.outer", "textobjects")
end, { desc = "Previous function end" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.cmd("Wrapwidth 99")
  end,
})

require("neoscroll").setup({
  duration_multiplier = 0.35,
})

local function oil_select_in_picked_window()
  local win = require("window-picker").pick_window({
    filter_rules = {
      include_current_win = false,
      bo = {
        filetype = { "oil", "NvimTree", "neo-tree", "notify", "snacks_notif" },
        buftype = { "terminal", "quickfix", "nofile", "prompt" },
      },
    },
  })

  if not win then
    return
  end

  require("oil").select({
    handle_buffer_callback = function(bufnr)
      if not vim.api.nvim_win_is_valid(win) then
        vim.notify("Picked window is no longer valid", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(win)
      vim.cmd({ cmd = "buffer", args = { bufnr } })
    end,
  })
end

require("oil").setup({
  keymaps = {
    -- Let global window/tmux navigation mappings work in Oil buffers.
    ["<C-h>"] = false,
    ["<C-j>"] = false,
    ["<C-k>"] = false,
    ["<C-l>"] = false,
    ["<C-s>"] = false,
    ["<C-v>"] = false,
    ["<leader><CR>"] = {
      callback = oil_select_in_picked_window,
      desc = "Open entry in picked window",
      mode = "n",
    },
    ["<leader>-"] = {
      callback = function()
        require("config.keymaps").open_mini_files()
      end,
      desc = "Open mini.files",
      mode = "n",
    },
  },
  view_options = { show_hidden = true },
  win_options = {
    winbar = "%{v:lua.require('oil').get_current_dir()}",
  },
})

require("zen-mode").setup({
  window = {
    backdrop = 0.95,
  },
  on_open = function(win)
    require("colors").apply_window_highlights(win)
  end,
})

require("lazydev").setup({
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
})

require("neotest").setup({
  adapters = {
    require("neotest-python")({
      runner = "pytest",
      dap = {
        justMyCode = false,
      },
    }),
    require("neotest-rust"),
  },
})

require("nvim-paredit").setup({
  filetypes = { "clojure" },
})

require("tidal").setup({})

-- Editor integrations configured after plugins are available.
require("config.editor").setup()

-- Load reloadable settings (options, keymaps, autocommands)
require("settings")
