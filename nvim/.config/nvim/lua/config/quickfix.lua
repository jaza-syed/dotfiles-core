-- Opening quickfix and location list entries, in the window the tab pins them to.
local M = {}

-- Windows that cannot serve as the target, because they hold no file.
local filter_rules = {
  include_current_win = true,
  bo = {
    filetype = { "qf", "trouble", "oil", "aerial", "NvimTree", "neo-tree", "notify", "snacks_notif" },
    buftype = { "quickfix", "terminal", "nofile", "prompt" },
  },
}

--- The window this tab pins entries to, if it is still open.
function M.pinned_window()
  local win = vim.t.qf_window
  if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
    return win
  end
  return nil
end

--- Picks a window that can hold a file.
function M.pick_window()
  local win = require("window-picker").pick_window({ filter_rules = filter_rules })
  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end
  return nil
end

--- Pins entries to a picked window, or unpins when that window is already pinned.
function M.pin()
  local win = M.pick_window()
  if not win then
    return
  end

  if win == M.pinned_window() then
    vim.t.qf_window = nil
    vim.notify("Quickfix unpinned")
    return
  end

  vim.t.qf_window = win
  local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
  vim.notify("Quickfix pinned to " .. (name ~= "" and vim.fn.fnamemodify(name, ":t") or "window " .. win))
end

local function jump_review(item)
  local review = package.loaded.review
  if not review then
    return false
  end

  local user_data = type(item.user_data) == "table" and item.user_data or {}
  local handled = item.module == "review.nvim"
    and review.jump_quickfix_thread
    and review.jump_quickfix_thread(user_data.session_id, user_data.thread_id)

  return handled or (review.jump_quickfix_location and review.jump_quickfix_location(item)) or false
end

local function show_in_window(win, item)
  local bufnr = item.bufnr
  if (not bufnr or bufnr == 0) and item.filename and item.filename ~= "" then
    bufnr = vim.fn.bufadd(item.filename)
  end
  if not bufnr or bufnr == 0 then
    return false
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

  return true
end

--- Opens entry `index` of the quickfix list, or of `loclist_win`'s location list.
--- `window` overrides the pinned window for this one entry.
function M.open(index, loclist_win, window)
  local list = loclist_win and vim.fn.getloclist(loclist_win, { items = 0 }) or vim.fn.getqflist({ items = 0 })
  local item = list.items[index]

  if not item then
    vim.notify("No list entry at " .. tostring(index), vim.log.levels.WARN)
    return
  end

  if loclist_win then
    vim.fn.setloclist(loclist_win, {}, "a", { idx = index })
  else
    vim.fn.setqflist({}, "a", { idx = index })
  end

  if jump_review(item) then
    return
  end

  local win = window or M.pinned_window()
  if win and show_in_window(win, item) then
    return
  end

  vim.cmd((loclist_win and "ll " or "cc ") .. index)
  vim.cmd("normal! zvzz")
end

--- Opens the quickfix entry `count` places from the current one.
function M.step(count)
  local list = vim.fn.getqflist({ items = 0, idx = 0 })
  local size = #list.items

  if size == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.WARN)
    return
  end

  M.open(math.min(math.max(list.idx + count, 1), size))
end

-- :copen splits, and the new window inherits the file window's winbar, which
-- is dropbar's project title. The list's own title belongs there instead.
local function title_winbar()
  local win = vim.api.nvim_get_current_win()
  local wintype = vim.fn.win_gettype(win)
  if wintype ~= "quickfix" and wintype ~= "loclist" then
    return
  end

  vim.wo[win][0].winbar = " %{get(w:, 'quickfix_title', '')}"
end

-- mini.bracketed jumps with :cc, so its traversal needs the same override to
-- reach the pinned window and Diffview.
function M.setup()
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("ConfigQuickfix", { clear = true }),
    callback = title_winbar,
  })

  local ok, bracketed = pcall(require, "mini.bracketed")
  if not ok then
    return
  end

  bracketed._dotfiles_quickfix = bracketed._dotfiles_quickfix or bracketed.quickfix
  local original = bracketed._dotfiles_quickfix

  bracketed.quickfix = function(direction, opts)
    if vim.g.minibracketed_disable == true or vim.b.minibracketed_disable == true then
      return original(direction, opts)
    end
    if not vim.tbl_contains({ "first", "backward", "forward", "last" }, direction) then
      return original(direction, opts)
    end

    local list = vim.fn.getqflist({ items = 0, idx = 0 })
    local size = #list.items
    if size == 0 then
      return original(direction, opts)
    end

    local config = vim.tbl_deep_extend("force", bracketed.config, vim.b.minibracketed_config or {})
    local options =
      vim.tbl_deep_extend("force", { n_times = vim.v.count1, wrap = true }, config.quickfix.options, opts or {})
    local index = bracketed.advance({
      state = list.idx,
      start_edge = 0,
      end_edge = size + 1,
      next = function(i)
        if i and i < size then
          return i + 1
        end
      end,
      prev = function(i)
        if i and i > 1 then
          return i - 1
        end
      end,
    }, direction, options)

    if not index then
      return
    end

    M.open(index)
  end
end

return M
