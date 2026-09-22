-- Quickfix buffer-local mappings for opening entries and pinning the list to a window.
local function qf_open(window)
  local quickfix = require("config.quickfix")
  local qf_win = vim.api.nvim_get_current_win()
  local qf_buf = vim.api.nvim_get_current_buf()
  local qf_line = vim.api.nvim_win_get_cursor(qf_win)[1]
  local wininfo = vim.fn.getwininfo(qf_win)[1] or {}

  quickfix.open(qf_line, wininfo.loclist == 1 and qf_win or nil, window)

  if vim.api.nvim_win_is_valid(qf_win) and vim.api.nvim_win_get_buf(qf_win) == qf_buf then
    vim.api.nvim_win_set_cursor(qf_win, { qf_line, 0 })
  end
end

vim.keymap.set("n", "<CR>", function()
  qf_open()
end, {
  buffer = true,
  desc = "Open quickfix item",
})

vim.keymap.set("n", "<2-LeftMouse>", function()
  qf_open()
end, {
  buffer = true,
  desc = "Open quickfix item",
})

vim.keymap.set("n", "<C-CR>", function()
  local win = require("config.quickfix").pick_window()
  if win then
    qf_open(win)
  end
end, {
  buffer = true,
  desc = "Open quickfix item in picked window",
})

vim.keymap.set("n", "<C-p>", function()
  require("config.quickfix").pin()
end, {
  buffer = true,
  desc = "Pin list entries to a picked window",
})

-- Step the list and show the entry without leaving the list, so the target
-- window follows the selection. Shadows the tmux-navigator <C-j>/<C-k> here.
local function qf_follow(delta)
  local qf_win = vim.api.nvim_get_current_win()
  local line = vim.api.nvim_win_get_cursor(qf_win)[1] + delta
  if line < 1 or line > vim.api.nvim_buf_line_count(0) then
    return
  end

  vim.api.nvim_win_set_cursor(qf_win, { line, 0 })
  qf_open()
  if vim.api.nvim_win_is_valid(qf_win) then
    vim.api.nvim_set_current_win(qf_win)
  end
end

vim.keymap.set("n", "<C-j>", function()
  qf_follow(1)
end, {
  buffer = true,
  desc = "Show next entry, staying in the list",
})

vim.keymap.set("n", "<C-k>", function()
  qf_follow(-1)
end, {
  buffer = true,
  desc = "Show previous entry, staying in the list",
})

vim.keymap.set("n", "<C-e>", function()
  require("quicker").toggle_expand()
end, {
  buffer = true,
  desc = "Expand/collapse source context",
})

vim.keymap.set("n", "<C-r>", function()
  require("quicker").refresh()
end, {
  buffer = true,
  desc = "Refresh list entries from source buffers",
})
