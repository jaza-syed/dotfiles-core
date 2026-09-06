-- Quickfix buffer-local mapping for opening items in a picked window.
local function qf_open_in_picked_window()
  local qf_win = vim.api.nvim_get_current_win()
  local qf_buf = vim.api.nvim_get_current_buf()
  local qf_line = vim.api.nvim_win_get_cursor(qf_win)[1]
  local wininfo = vim.fn.getwininfo(qf_win)[1] or {}
  local is_loclist = wininfo.loclist == 1
  local list = is_loclist and vim.fn.getloclist(0, { items = 0 }) or vim.fn.getqflist({ items = 0 })
  local item = list.items and list.items[qf_line]

  if not item then
    vim.notify("No quickfix item under cursor", vim.log.levels.WARN)
    return
  end

  local win = require("window-picker").pick_window({
    filter_rules = {
      include_current_win = false,
      bo = {
        filetype = { "qf", "oil", "NvimTree", "neo-tree", "notify", "snacks_notif" },
        buftype = { "quickfix", "terminal", "nofile", "prompt" },
      },
    },
  })

  if not win then
    return
  end
  if not vim.api.nvim_win_is_valid(win) then
    vim.notify("Picked window is no longer valid", vim.log.levels.WARN)
    return
  end

  if is_loclist then
    vim.fn.setloclist(0, {}, "a", { idx = qf_line })
  else
    vim.fn.setqflist({}, "a", { idx = qf_line })
  end

  local bufnr = item.bufnr
  if (not bufnr or bufnr == 0) and item.filename and item.filename ~= "" then
    bufnr = vim.fn.bufadd(item.filename)
  end
  if not bufnr or bufnr == 0 then
    vim.notify("Quickfix item has no file to open", vim.log.levels.WARN)
    return
  end

  local user_data = type(item.user_data) == "table" and item.user_data or {}
  local lnum = item.lnum and item.lnum > 0 and item.lnum or user_data.lnum or 1
  local col = item.col and item.col > 0 and item.col - 1 or 0

  vim.bo[bufnr].buflisted = true
  vim.fn.bufload(bufnr)
  lnum = math.min(math.max(1, lnum), vim.api.nvim_buf_line_count(bufnr))

  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, bufnr)
  if not pcall(vim.api.nvim_win_set_cursor, win, { lnum, col }) then
    vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  end
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zvzz")
  end)

  if vim.api.nvim_win_is_valid(qf_win) and vim.api.nvim_win_get_buf(qf_win) == qf_buf then
    vim.api.nvim_win_set_cursor(qf_win, { qf_line, 0 })
  end
end

vim.keymap.set("n", "<leader><CR>", qf_open_in_picked_window, {
  buffer = true,
  desc = "Open quickfix item in picked window",
})

-- quicker.nvim only registers its follow autocmd if `follow.enabled` was true
-- at setup() time, so toggling the config field alone does nothing live.
local qf_follow_group = vim.api.nvim_create_augroup("qf_follow_toggle", { clear = false })

local function qf_toggle_follow()
  local config = require("quicker.config")
  config.follow.enabled = not config.follow.enabled
  vim.api.nvim_clear_autocmds({ group = qf_follow_group })
  if config.follow.enabled then
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
      group = qf_follow_group,
      desc = "Scroll quickfix to nearest item to cursor",
      callback = function()
        require("quicker.follow").seek_to_position()
      end,
    })
    require("quicker.follow").seek_to_position()
  end
  vim.notify("qf follow: " .. (config.follow.enabled and "on" or "off"))
end

vim.keymap.set("n", "<leader>qf", qf_toggle_follow, {
  buffer = true,
  desc = "Toggle quickfix/loclist follow mode",
})

vim.keymap.set("n", "<leader>qe", function()
  require("quicker").toggle_expand()
end, {
  buffer = true,
  desc = "Expand/collapse source context",
})

vim.keymap.set("n", "<leader>qr", function()
  require("quicker").refresh()
end, {
  buffer = true,
  desc = "Refresh list entries from source buffers",
})
