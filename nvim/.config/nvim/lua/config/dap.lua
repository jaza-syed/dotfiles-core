-- Debug adapter protocol setup with a dedicated Debug tab layout.
local M = {}

local listener_key = "dotfiles_dap"
local debug_tab_var = "dotfiles_dap_debug_tab"
local origin_tab = nil

local function debugpy_python()
  return vim.fn.stdpath("data") .. "/debugpy/bin/python"
end

M.debugpy_python = debugpy_python

local function tab_has_var(tabpage, name, expected)
  local ok, value = pcall(vim.api.nvim_tabpage_get_var, tabpage, name)
  return ok and value == expected
end

local function find_debug_tab()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if tab_has_var(tabpage, debug_tab_var, true) then
      return tabpage
    end
  end
  return nil
end

local function remember_origin_tab(current_tab, debug_tab)
  if current_tab and current_tab ~= debug_tab and vim.api.nvim_tabpage_is_valid(current_tab) then
    origin_tab = current_tab
  end
end

local function set_debug_tab_vars()
  vim.t[debug_tab_var] = true
  vim.t.tabname = "Debug"
end

function M.ensure_debug_tab()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local debug_tab = find_debug_tab()
  if debug_tab and vim.api.nvim_tabpage_is_valid(debug_tab) then
    remember_origin_tab(current_tab, debug_tab)
    vim.api.nvim_set_current_tabpage(debug_tab)
    return debug_tab
  end

  origin_tab = current_tab
  local source_buf = vim.api.nvim_get_current_buf()
  local source_cursor = vim.api.nvim_win_get_cursor(0)

  vim.cmd("tabnew")
  set_debug_tab_vars()

  if vim.api.nvim_buf_is_valid(source_buf) then
    pcall(vim.api.nvim_win_set_buf, 0, source_buf)
    pcall(vim.api.nvim_win_set_cursor, 0, source_cursor)
  end

  return vim.api.nvim_get_current_tabpage()
end

function M.open_debug_ui()
  M.ensure_debug_tab()

  local ok, dapui = pcall(require, "dapui")
  if ok then
    dapui.open({ reset = true })
  end
end

local function close_debug_tab()
  local debug_tab = find_debug_tab()
  if not debug_tab or not vim.api.nvim_tabpage_is_valid(debug_tab) then
    return
  end

  if #vim.api.nvim_list_tabpages() <= 1 then
    return
  end

  local target_tab = origin_tab
  vim.schedule(function()
    if vim.api.nvim_tabpage_is_valid(debug_tab) then
      pcall(vim.api.nvim_set_current_tabpage, debug_tab)
      pcall(vim.cmd, "tabclose")
    end

    if target_tab and vim.api.nvim_tabpage_is_valid(target_tab) then
      pcall(vim.api.nvim_set_current_tabpage, target_tab)
    end
  end)
end

function M.close_debug_ui()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local debug_tab = find_debug_tab()

  if debug_tab and vim.api.nvim_tabpage_is_valid(debug_tab) then
    pcall(vim.api.nvim_set_current_tabpage, debug_tab)
  end

  local ok, dapui = pcall(require, "dapui")
  if ok then
    dapui.close()
  end

  if debug_tab and #vim.api.nvim_list_tabpages() > 1 then
    close_debug_tab()
  elseif current_tab and vim.api.nvim_tabpage_is_valid(current_tab) then
    pcall(vim.api.nvim_set_current_tabpage, current_tab)
  end
end

local function setup_signs()
  local signs = {
    DapBreakpoint = "●",
    DapBreakpointCondition = "◆",
    DapBreakpointRejected = "○",
    DapLogPoint = "◆",
    DapStopped = "▶",
  }

  for name, text in pairs(signs) do
    vim.fn.sign_define(name, {
      text = text,
      texthl = name,
      linehl = name == "DapStopped" and "DapStoppedLine" or "",
      numhl = name,
    })
  end
end

local function setup_dap_python()
  local ok, dap_python = pcall(require, "dap-python")
  if not ok then
    return
  end

  local python = debugpy_python()
  if vim.fn.executable(python) ~= 1 then
    local install_cmd = "uv venv "
      .. vim.fn.stdpath("data")
      .. "/debugpy"
      .. " && uv pip install --python "
      .. python
      .. " debugpy"
    vim.notify("debugpy adapter not found at " .. python .. "; run: " .. install_cmd, vim.log.levels.WARN)
    return
  end

  dap_python.setup(python)
  dap_python.test_runner = "pytest"
end

local function setup_dap_ui()
  local ok, dapui = pcall(require, "dapui")
  if not ok then
    return
  end

  dapui.setup({
    controls = {
      enabled = true,
      element = "repl",
      icons = {
        pause = "⏸",
        play = "▶",
        step_into = "↧",
        step_over = "↷",
        step_out = "↥",
        step_back = "↶",
        run_last = "↻",
        terminate = "■",
        disconnect = "⏏",
      },
    },
    floating = {
      border = "rounded",
    },
    layouts = {
      {
        elements = {
          { id = "scopes", size = 0.45 },
          { id = "stacks", size = 0.25 },
          { id = "breakpoints", size = 0.15 },
          { id = "watches", size = 0.15 },
        },
        position = "left",
        size = 48,
      },
      {
        elements = {
          { id = "repl", size = 0.5 },
          { id = "console", size = 0.5 },
        },
        position = "bottom",
        size = 12,
      },
    },
  })
end

local function setup_listeners(dap)
  dap.listeners.before.attach[listener_key] = function()
    M.open_debug_ui()
  end
  dap.listeners.before.launch[listener_key] = function()
    M.open_debug_ui()
  end
  dap.listeners.before.event_terminated[listener_key] = function()
    M.close_debug_ui()
  end
  dap.listeners.before.event_exited[listener_key] = function()
    M.close_debug_ui()
  end
end

function M.setup()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end

  setup_signs()
  setup_dap_python()
  setup_dap_ui()
  setup_listeners(dap)
end

return M
