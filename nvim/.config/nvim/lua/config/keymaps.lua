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

-- venn.nvim draws where the cursor is, including past the end of a line, so
-- the mode turns on 'virtualedit' and binds the drawing keys until it is off.
local function toggle_venn()
  local draw = { H = "h", J = "j", K = "k", L = "l" }

  if vim.b.venn_enabled then
    vim.wo.virtualedit = vim.b.venn_virtualedit
    for key in pairs(draw) do
      vim.keymap.del("n", key, { buffer = 0 })
    end
    vim.keymap.del("x", "f", { buffer = 0 })
    vim.b.venn_enabled = nil
    return
  end

  vim.b.venn_virtualedit = vim.wo.virtualedit
  vim.wo.virtualedit = "all"
  for key, motion in pairs(draw) do
    vim.keymap.set("n", key, "<C-v>" .. motion .. ":VBox<CR>", {
      buffer = 0,
      desc = "Draw a line " .. motion,
    })
  end
  vim.keymap.set("x", "f", ":VBox<CR>", { buffer = 0, desc = "Draw a box round the selection" })
  vim.b.venn_enabled = true
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

  -- Buffer names for terminals and other plugins are URIs rather than paths
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or not vim.uv.fs_stat(path) then
    return vim.uv.cwd()
  end

  return path
end

-- mini.sessions detects session files during setup, so re-running setup picks
-- up sessions another Nvim instance has written since.
local function refresh_sessions()
  MiniSessions.setup(MiniSessions.config)
end

-- MiniSessions.select() sorts names alphabetically with no option to change it.
local function select_session(action)
  refresh_sessions()

  local names = vim.tbl_keys(MiniSessions.detected)
  if #names == 0 then
    vim.notify("No sessions detected", vim.log.levels.WARN)
    return
  end

  table.sort(names, function(a, b)
    return MiniSessions.detected[a].modify_time > MiniSessions.detected[b].modify_time
  end)

  vim.ui.select(names, {
    prompt = "Select session to " .. action,
    format_item = function(name)
      return ("%s (%s)"):format(name, os.date("%Y-%m-%d %H:%M", MiniSessions.detected[name].modify_time))
    end,
  }, function(name)
    if name then
      MiniSessions[action](name)
    end
  end)
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

  -- C-hjkl move between windows and, at an edge, tmux panes. The plugin's own
  -- mappings are off (g:tmux_navigator_no_mappings) because its terminal-mode
  -- ones use Vim 8's <C-w>: prefix, which Neovim's terminal lacks.
  local navigate = {
    ["<C-h>"] = "TmuxNavigateLeft",
    ["<C-j>"] = "TmuxNavigateDown",
    ["<C-k>"] = "TmuxNavigateUp",
    ["<C-l>"] = "TmuxNavigateRight",
  }
  for key, command in pairs(navigate) do
    vim.keymap.set("n", key, "<Cmd>" .. command .. "<CR>", { desc = command })
  end
  vim.keymap.set("n", "<C-\\>", "<Cmd>TmuxNavigatePrevious<CR>", { desc = "TmuxNavigatePrevious" })

  -- In a terminal the same keys navigate while the shell is idle. A running
  -- program such as fzf, atuin or a pager gets the key instead.
  local shells = { zsh = true, bash = true, fish = true, sh = true }
  local function shell_is_idle()
    local pid = vim.b.terminal_job_pid
    if not pid then
      return false
    end
    local name = vim.trim(vim.system({ "ps", "-o", "comm=", "-p", tostring(pid) }):wait().stdout or "")
    return shells[vim.fs.basename(name):gsub("^%-", "")] == true
      and vim.system({ "pgrep", "-P", tostring(pid) }):wait().code ~= 0
  end
  for key, command in pairs(navigate) do
    vim.keymap.set("t", key, function()
      if shell_is_idle() then
        return "<C-\\><C-n><Cmd>" .. command .. "<CR>"
      end
      return key
    end, { expr = true, desc = command .. " unless a program is running" })
  end
  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })

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

  -- Diagrams
  vim.keymap.set("n", "<Leader>v", toggle_venn, { desc = "Toggle venn box drawing" })
  vim.keymap.set("n", "<Leader>i", function()
    require("diagram").show_diagram_hover()
  end, { desc = "Show the diagram under the cursor in a float" })

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
  vim.keymap.set("n", "<leader>ln", vim.lsp.buf.rename, { desc = "LSP rename" })
  vim.keymap.set("n", "<leader>lk", restart_lsp_clients, { desc = "Restart LSP clients" })
  map_lsp_jump("d", vim.lsp.buf.definition, "Goto definition")
  map_lsp_jump("t", vim.lsp.buf.type_definition, "Goto type definition")
  vim.keymap.set("n", "<leader>ll", vim.diagnostic.setloclist, { desc = "File diagnostics to loclist" })
  vim.keymap.set("n", "<leader>lq", vim.diagnostic.setqflist, { desc = "All diagnostics to quickfix" })
  vim.keymap.set("n", "<leader>lf", function()
    require("config.format").format()
  end, { desc = "Format buffer" })

  -- Tasks
  vim.keymap.set("n", "<leader>kr", "<cmd>OverseerRun<cr>", { desc = "Run a task" })
  vim.keymap.set("n", "<leader>kt", "<cmd>OverseerToggle<cr>", { desc = "Toggle the task list" })
  vim.keymap.set("n", "<leader>ka", "<cmd>OverseerTaskAction<cr>", { desc = "Act on a task" })
  vim.keymap.set("n", "<leader>kq", "<cmd>OverseerQuickAction<cr>", { desc = "Quick action on the last task" })
  vim.keymap.set("n", "<leader>kl", function()
    -- list_tasks() sorts by start time, newest first.
    local task = require("overseer").list_tasks({ unique = true })[1]
    if task == nil then
      vim.notify("No tasks to restart", vim.log.levels.WARN)
      return
    end

    task:restart(true)
  end, { desc = "Restart the last task" })

  -- Sessions
  vim.keymap.set("n", "<leader>ss", function()
    MiniSessions.write(os.date("%Y-%m-%d_%H-%M-%S"))
  end, { desc = "Save timestamped session" })
  vim.keymap.set("n", "<leader>sw", function()
    vim.ui.input({ prompt = "Session name: " }, function(name)
      if name and name ~= "" then
        MiniSessions.write(name)
      end
    end)
  end, { desc = "Save named session" })
  vim.keymap.set("n", "<leader>sl", function()
    refresh_sessions()

    local latest = MiniSessions.get_latest()
    if latest == nil then
      vim.notify("No sessions detected", vim.log.levels.WARN)
      return
    end

    MiniSessions.read(latest)
  end, { desc = "Read the latest session" })
  vim.keymap.set("n", "<leader>sp", function()
    select_session("read")
  end, { desc = "Pick a session" })
  vim.keymap.set("n", "<leader>sd", function()
    select_session("delete")
  end, { desc = "Delete a session" })

  -- Telescope shortcuts
  local pickers = require("config.pickers")

  vim.keymap.set("n", "<leader>ff", pickers.files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fB", pickers.buffers, { desc = "Find buffers" })
  vim.keymap.set("n", "<leader>fg", pickers.git_files, { desc = "Git files" })
  vim.keymap.set("n", "<leader>fr", pickers.live_grep, { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fd", pickers.live_grep_dir, { desc = "Live grep in directory" })
  vim.keymap.set("n", "<leader>fb", pickers.current_buffer, { desc = "Current buffer fuzzy find" })
  vim.keymap.set("n", "<leader>fh", pickers.command_history, { desc = "Command history" })
  vim.keymap.set("n", "<leader>fp", pickers.builtin, { desc = "Telescope pickers" })
  vim.keymap.set("n", "<leader>fs", pickers.workspace_symbols, { desc = "Live workspace symbols" })
  vim.keymap.set("n", "<leader>fo", "<cmd>Telescope aerial<cr>", { desc = "Document symbols" })
  vim.keymap.set("n", "<leader>fc", pickers.commands, { desc = "Find Vim commands" })
  vim.keymap.set("n", "<leader>fz", pickers.zoxide, { desc = "Zoxide" })
  vim.keymap.set("n", "<leader>fS", pickers.global_symbols, { desc = "Live global symbols" })

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
