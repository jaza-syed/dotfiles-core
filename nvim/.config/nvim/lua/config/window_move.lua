-- Sticky window movement mode, modelled after tmux's move key table.
local M = {}

local active = false
local namespace = vim.api.nvim_create_namespace("SettingsWindowMove")

local directions = {
  h = "h",
  j = "j",
  k = "k",
  l = "l",
  H = "h",
  J = "j",
  K = "k",
  L = "l",
}

local exit_keys = {
  [vim.keycode("<Esc>")] = true,
  [vim.keycode("<C-c>")] = true,
  q = true,
}

local function refresh_statusline()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    pcall(lualine.refresh, {
      force = true,
      place = { "statusline" },
      scope = "tabpage",
    })
  end
  vim.cmd("redrawstatus")
end

local function window_in_direction(dir)
  local current = vim.fn.winnr()
  local target = vim.fn.winnr(dir)
  if target == 0 or target == current then
    return nil
  end

  local win = vim.fn.win_getid(target)
  return win ~= 0 and win or nil
end

function M.reorder(dir)
  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current).relative ~= "" then
    return false
  end

  local target = window_in_direction(dir)
  if not target then
    return false
  end

  local result = vim.fn.win_splitmove(current, target, {
    vertical = dir == "h" or dir == "l",
    rightbelow = dir == "j" or dir == "l",
  })
  if result ~= 0 then
    return false
  end

  if vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_set_current_win(current)
  end
  return true
end

function M.change_level(dir)
  if #vim.api.nvim_tabpage_list_wins(0) < 2 then
    return false
  end

  vim.cmd("TradewindsMove " .. dir)
  return true
end

-- Nvim has no cross-tab window move, so the window is closed and reopened on
-- the target tab. Focus follows it.
function M.to_tab(n)
  local target = vim.api.nvim_list_tabpages()[n]
  if not target or target == vim.api.nvim_get_current_tabpage() then
    return false
  end

  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current).relative ~= "" then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(current)
  local view = vim.fn.winsaveview()
  vim.api.nvim_win_close(current, false)
  vim.api.nvim_set_current_tabpage(target)
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  vim.fn.winrestview(view)
  return true
end

function M.is_active()
  return active
end

function M.leave()
  if not active then
    return
  end

  active = false
  vim.on_key(nil, namespace)
  refresh_statusline()
end

local function run(action)
  vim.schedule(function()
    if not active then
      return
    end

    local ok, err = xpcall(action, debug.traceback)
    if not ok then
      M.leave()
      vim.notify("Window move mode failed:\n" .. err, vim.log.levels.ERROR)
      return
    end

    refresh_statusline()
  end)
end

local function on_key(key, typed)
  local input = typed ~= "" and typed or key

  if exit_keys[input] then
    vim.schedule(M.leave)
    return ""
  end

  local tab = input:match("^[1-9]$")
  if tab then
    run(function()
      M.to_tab(tonumber(tab))
    end)
    return ""
  end

  local dir = directions[input]
  if not dir then
    vim.schedule(M.leave)
    return ""
  end

  if input:match("%u") then
    run(function()
      M.change_level(dir)
    end)
  else
    run(function()
      M.reorder(dir)
    end)
  end

  return ""
end

function M.enter()
  if active then
    return
  end

  active = true
  vim.on_key(on_key, namespace)
  refresh_statusline()
end

-- A reload should never leave a listener owned by the previous module active.
vim.on_key(nil, namespace)

return M
