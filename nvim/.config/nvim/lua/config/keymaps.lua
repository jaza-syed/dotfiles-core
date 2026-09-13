-- Global keymaps and navigation helper functions.
local M = {}

local function find_window_in_direction(dir)
  local current = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)

  local target = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(current)

  if target == current then
    return nil
  end

  return target
end

local function jump_to_item_in_win(win, item, tagname, from)
  if not vim.api.nvim_win_is_valid(win) then
    vim.notify("Target window is no longer valid", vim.log.levels.WARN)
    return
  end

  local bufnr = item.bufnr or vim.fn.bufadd(item.filename)
  vim.bo[bufnr].buflisted = true

  vim.fn.settagstack(win, { items = { { tagname = tagname, from = from } } }, "t")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.api.nvim_win_set_cursor(win, { item.lnum, item.col - 1 })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zv")
  end)
end

local function lsp_in_direction(dir, fn)
  return function()
    local target = find_window_in_direction(dir)
    if not target then
      vim.notify("No window in direction: " .. dir, vim.log.levels.WARN)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local from = vim.fn.getpos(".")
    from[1] = bufnr
    local tagname = vim.fn.expand("<cword>")

    fn({
      on_list = function(options)
        if #options.items == 1 then
          jump_to_item_in_win(target, options.items[1], tagname, from)
          return
        end

        vim.fn.setqflist({}, " ", { title = options.title, items = options.items })
        vim.cmd("botright copen")
      end,
    })
  end
end

local function map_lsp_jump(key, fn, desc)
  local directions = {
    h = "left",
    j = "down",
    k = "up",
    l = "right",
  }

  vim.keymap.set("n", "<leader>l" .. key .. key, fn, { desc = desc })

  for dir, name in pairs(directions) do
    vim.keymap.set("n", "<leader>l" .. key .. dir, lsp_in_direction(dir, fn), {
      desc = desc .. " in " .. name .. " window",
    })
  end
end

local function restart_lsp_clients()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  if #clients == 0 then
    vim.notify("No LSP clients attached", vim.log.levels.WARN)
    return
  end

  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
    client:stop()
  end

  vim.notify("Restarting LSP: " .. table.concat(names, ", "), vim.log.levels.INFO)

  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    vim.api.nvim_buf_call(bufnr, function()
      local filetype = vim.bo[bufnr].filetype
      if filetype ~= "" then
        vim.cmd("doautocmd <nomodeline> FileType " .. vim.fn.fnameescape(filetype))
      end
    end)
  end, 500)
end

local function set_foldlevel_for_buffer(level)
  local bufnr = vim.api.nvim_get_current_buf()
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].foldlevel = level
    end
  end
end

local function go_to_tab(tabnr)
  if tabnr > vim.fn.tabpagenr("$") then
    vim.notify("No tab " .. tabnr, vim.log.levels.WARN)
    return
  end

  vim.cmd("tabnext " .. tabnr)
end

local function close_current_tab()
  if vim.fn.tabpagenr("$") == 1 then
    vim.notify("Cannot close the last tab", vim.log.levels.WARN)
    return
  end

  vim.cmd("tabclose")
end

local function current_mini_files_path()
  if vim.bo.filetype == "oil" then
    local ok, oil = pcall(require, "oil")
    if ok then
      local dir = oil.get_current_dir()
      if dir and dir ~= "" then
        return dir
      end
    end
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.uv.cwd()
  end

  return path
end

function M.open_mini_files()
  require("mini.files").open(current_mini_files_path(), false)
end

function M.setup()
  -- Clear search highlight
  vim.keymap.set("n", "<leader>cc", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

  -- Disable multi-line command input
  vim.keymap.set("n", "q:", "<nop>")

  -- Use C-a like readline in command-line editing
  vim.keymap.set("c", "<C-a>", "<C-b>", { noremap = true })

  -- Tab management
  for tabnr = 1, 9 do
    vim.keymap.set("n", "<leader>t" .. tabnr, function()
      go_to_tab(tabnr)
    end, { desc = "Go to tab " .. tabnr })
  end
  vim.keymap.set("n", "<leader>tn", "<cmd>tabnext<cr>", { desc = "Next tab" })
  vim.keymap.set("n", "<leader>tp", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
  vim.keymap.set("n", "<leader>tc", "<cmd>tabnew<cr>", { desc = "New tab" })
  vim.keymap.set("n", "<leader>tx", close_current_tab, { desc = "Close tab" })

  -- vim-tmux-navigator maps C-hjkl in terminal mode using Vim 8's <C-w>: window
  -- prefix, which Neovim's terminal has no equivalent of, so the Ex command gets
  -- typed into the shell. Drop them; these keys belong to the program in the
  -- terminal. <C-\><C-n> first still navigates.
  for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
    pcall(vim.keymap.del, "t", key)
  end

  -- Window/tab management
  vim.keymap.set("n", "<Leader>nn", ":set invnumber<CR>", { noremap = true, desc = "Toggle line numbers" })
  vim.keymap.set("n", "<Leader>wh", "<C-w>h", { noremap = true, desc = "Focus window left" })
  vim.keymap.set("n", "<Leader>wj", "<C-w>j", { noremap = true, desc = "Focus window down" })
  vim.keymap.set("n", "<Leader>wk", "<C-w>k", { noremap = true, desc = "Focus window up" })
  vim.keymap.set("n", "<Leader>wl", "<C-w>l", { noremap = true, desc = "Focus window right" })
  vim.keymap.set("n", "<Leader>wv", "<C-w>v<C-w>l", { noremap = true, desc = "Vertical split" })
  vim.keymap.set("n", "<Leader>ws", "<C-w>s<C-w>j", { noremap = true, desc = "Horizontal split" })
  vim.keymap.set("n", "<Leader>wd", "<C-w>q", { noremap = true, desc = "Close window" })
  vim.keymap.set("n", "<Leader>w=", "<C-w>=", { noremap = true, desc = "Equalize windows" })
  -- Clear the former one-shot maps when reloading an existing session.
  for _, key in ipairs({ "<Leader>wgh", "<Leader>wgj", "<Leader>wgk", "<Leader>wgl" }) do
    pcall(vim.keymap.del, "n", key)
  end
  vim.keymap.set("n", "<Leader>wm", function()
    require("config.window_move").enter()
  end, { desc = "Window move mode" })

  -- Folds
  for level = 0, 9 do
    local foldlevel = level
    vim.keymap.set("n", "z" .. foldlevel, function()
      set_foldlevel_for_buffer(foldlevel)
    end, { desc = "Set foldlevel " .. foldlevel .. " for buffer" })
  end

  -- Files
  vim.keymap.set("n", "<leader>-", M.open_mini_files, { desc = "Open mini.files" })
  vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle reveal<cr>", { desc = "Toggle file tree" })

  -- Quickfix
  vim.keymap.set("n", "<leader>qj", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
  vim.keymap.set("n", "<leader>qk", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })
  vim.keymap.set("n", "<leader>q[", "<cmd>colder<cr>", { desc = "Older quickfix list" })
  vim.keymap.set("n", "<leader>q]", "<cmd>cnewer<cr>", { desc = "Newer quickfix list" })

  -- Git
  vim.keymap.set("n", "<leader>gt", "<cmd>Neogit kind=tab<cr>", { desc = "Neogit tab" })
  vim.keymap.set("n", "<leader>gs", "<cmd>Neogit kind=split<cr>", { desc = "Neogit split" })
  vim.keymap.set("n", "<leader>gv", "<cmd>Neogit kind=vsplit<cr>", { desc = "Neogit vertical split" })
  vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diffview open" })
  vim.keymap.set("n", "<leader>gr", function()
    require("config.pickers").diff_range()
  end, { desc = "Diffview commit range (a..b)" })
  vim.keymap.set("n", "<leader>gR", function()
    require("config.pickers").diff_range_merge_base()
  end, { desc = "Diffview commit range from merge base (a...b)" })
  vim.keymap.set("n", "<leader>gD", "<cmd>Difft<cr>", { desc = "Difftastic unstaged diff" })
  vim.keymap.set("n", "<leader>gS", "<cmd>Difft --staged<cr>", { desc = "Difftastic staged diff" })
  vim.keymap.set({ "n", "x", "o" }, "s", function()
    require("hop").hint_char2()
  end, { desc = "Hop char2" })
  vim.keymap.set({ "n", "x", "o" }, "S", function()
    require("hop").hint_char2()
  end, { desc = "Hop char2" })
  vim.keymap.set("n", "<leader>;", function()
    require("dropbar.api").pick()
  end, { desc = "Pick symbols in winbar" })
  vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<cr>", { desc = "Toggle symbol outline" })
  vim.keymap.set("n", "[;", function()
    require("dropbar.api").goto_context_start()
  end, { desc = "Go to start of current context" })
  vim.keymap.set("n", "];", function()
    require("dropbar.api").select_next_context()
  end, { desc = "Select next context" })

  -- LSP
  vim.keymap.set("n", "<leader>le", function()
    vim.diagnostic.open_float({ header = "" })
  end, { desc = "Line diagnostics" })
  vim.keymap.set({ "n", "x" }, "<leader>la", vim.lsp.buf.code_action, { desc = "LSP code action" })
  vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, { desc = "LSP references" })
  vim.keymap.set("n", "<leader>li", vim.lsp.buf.implementation, { desc = "Goto implementation" })
  vim.keymap.set(
    "n",
    "<leader>lci",
    "<cmd>Telescope hierarchy incoming_calls<cr>",
    { desc = "Incoming call hierarchy" }
  )
  vim.keymap.set(
    "n",
    "<leader>lco",
    "<cmd>Telescope hierarchy outgoing_calls<cr>",
    { desc = "Outgoing call hierarchy" }
  )
  vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, { desc = "LSP rename" })
  vim.keymap.set("n", "<leader>lS", restart_lsp_clients, { desc = "Restart LSP clients" })
  map_lsp_jump("d", vim.lsp.buf.definition, "Goto definition")
  map_lsp_jump("t", vim.lsp.buf.type_definition, "Goto type definition")
  vim.keymap.set("n", "<leader>lf", vim.diagnostic.setloclist, { desc = "File diagnostics to loclist" })
  vim.keymap.set("n", "<leader>lQ", vim.diagnostic.setqflist, { desc = "All diagnostics to quickfix" })

  -- Telescope shortcuts
  local pickers = require("config.pickers")

  vim.keymap.set("n", "<leader>ff", pickers.files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fb", pickers.buffers, { desc = "Find buffers" })
  vim.keymap.set("n", "<leader>fg", pickers.git_files, { desc = "Git files" })
  vim.keymap.set("n", "<leader>fr", pickers.live_grep, { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fd", pickers.live_grep_dir, { desc = "Live grep in directory" })
  vim.keymap.set("n", "<leader>fR", pickers.current_buffer, { desc = "Current buffer fuzzy find" })
  vim.keymap.set("n", "<leader>fh", pickers.command_history, { desc = "Command history" })
  vim.keymap.set("n", "<leader>fp", pickers.builtin, { desc = "Telescope pickers" })
  vim.keymap.set("n", "<leader>fS", pickers.workspace_symbols, { desc = "Live workspace symbols" })
  vim.keymap.set("n", "<leader>fo", "<cmd>Telescope aerial<cr>", { desc = "Document symbols" })
  vim.keymap.set("n", "<leader>fc", pickers.commands, { desc = "Find Vim commands" })
  vim.keymap.set("n", "<leader>fz", pickers.zoxide, { desc = "Zoxide" })
  vim.keymap.set("n", "<leader>fG", pickers.global_symbols, { desc = "Live global symbols" })

  -- Debugging
  vim.keymap.set("n", "<leader>db", function()
    require("dap").toggle_breakpoint()
  end, { desc = "Toggle breakpoint" })
  vim.keymap.set("n", "<leader>dB", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Set conditional breakpoint" })
  vim.keymap.set("n", "<leader>dl", function()
    require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
  end, { desc = "Set logpoint" })
  vim.keymap.set("n", "<leader>dc", function()
    require("dap").continue()
  end, { desc = "DAP continue/start" })
  vim.keymap.set("n", "<leader>dq", function()
    require("dap").terminate()
  end, { desc = "DAP terminate" })
  vim.keymap.set("n", "<leader>di", function()
    require("dap").step_into()
  end, { desc = "DAP step into" })
  vim.keymap.set("n", "<leader>do", function()
    require("dap").step_over()
  end, { desc = "DAP step over" })
  vim.keymap.set("n", "<leader>dO", function()
    require("dap").step_out()
  end, { desc = "DAP step out" })
  vim.keymap.set("n", "<leader>dr", function()
    require("dap").repl.open()
  end, { desc = "DAP REPL" })
  vim.keymap.set("n", "<leader>du", function()
    require("config.dap").ensure_debug_tab()
    require("dapui").toggle()
  end, { desc = "Toggle DAP UI" })

  -- Neotest
  vim.keymap.set("n", "<leader>nr", function()
    require("neotest").run.run()
  end, { desc = "Run nearest test" })
  vim.keymap.set("n", "<leader>nf", function()
    require("neotest").run.run(vim.fn.expand("%"))
  end, { desc = "Run test file" })
  vim.keymap.set("n", "<leader>nl", function()
    require("neotest").run.run_last()
  end, { desc = "Run last test" })
  vim.keymap.set("n", "<leader>nd", function()
    require("neotest").run.run({ strategy = "dap" })
  end, { desc = "Debug nearest test" })
  vim.keymap.set("n", "<leader>nD", function()
    require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" })
  end, { desc = "Debug test file" })
  vim.keymap.set("n", "<leader>nL", function()
    require("neotest").run.run_last({ strategy = "dap" })
  end, { desc = "Debug last test" })
  vim.keymap.set("n", "<leader>ns", function()
    require("neotest").run.stop()
  end, { desc = "Stop test" })
  vim.keymap.set("n", "<leader>no", function()
    require("neotest").output.open({ enter = true })
  end, { desc = "Open test output" })
  vim.keymap.set("n", "<leader>nO", function()
    require("neotest").output_panel.toggle()
  end, { desc = "Toggle test output panel" })
  vim.keymap.set("n", "<leader>nS", function()
    require("neotest").summary.toggle()
  end, { desc = "Toggle test summary" })

  -- Config settings
  vim.keymap.set("n", "<leader>cr", function()
    -- Clear the reload module itself so changes to its module list are picked
    -- up before it reloads the rest of the settings graph.
    package.loaded["config.reload"] = nil
    require("config.reload").reload()
    vim.notify("Config reloaded", vim.log.levels.INFO)
  end, { noremap = true, desc = "Reload config" })

  vim.keymap.set("n", "<leader>ce", function()
    vim.cmd("edit " .. vim.fn.stdpath("config") .. "/lua")
  end, { noremap = true, desc = "Edit config" })

  -- Theme detection: re-detect terminal background and switch colorscheme
  vim.keymap.set("n", "<leader>td", function()
    require("colors").detect_and_apply()
  end, { desc = "Detect and apply theme" })
end

return M
