-- Shared behavior for scroll-bound diff panes.
local M = {}

local wheel_focus_ns = vim.api.nvim_create_namespace("DotfilesDiffWheelFocus")
local wheel_keys = {
  [vim.keycode("<ScrollWheelUp>")] = true,
  [vim.keycode("<ScrollWheelDown>")] = true,
}

local function focus_hovered_scrollbound_window(key)
  if not wheel_keys[key] then
    return
  end

  local win = vim.fn.getmousepos().winid
  if win == 0 or not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.api.nvim_win_get_tabpage(win) ~= vim.api.nvim_get_current_tabpage() then
    return
  end
  if vim.wo[win].scrollbind then
    vim.api.nvim_set_current_win(win)
  end
end

local function apply_difftastic_window_highlights(buf)
  local difftastic = package.loaded["difftastic-nvim"]
  if type(difftastic) ~= "table" or type(difftastic.state) ~= "table" then
    return
  end

  local state = difftastic.state
  for _, side in ipairs({ "left", "right" }) do
    local win = state[side .. "_win"]
    if state[side .. "_buf"] == buf and win and vim.api.nvim_win_is_valid(win) then
      require("colors").apply_diff_window_highlights(win)
    end
  end
end

-- Private-API adapter: difftastic.nvim exposes no view-creation hook. The
-- pristine open is kept on the module and the wrapper rebuilt over it, so
-- repeated calls cannot stack wrappers.
function M.configure_difftastic(difftastic)
  difftastic._dotfiles_open = difftastic._dotfiles_open or difftastic.open

  local original_open = difftastic._dotfiles_open
  difftastic.open = function(...)
    -- difftastic assigns old/new semantics to left_win/right_win, but its
    -- plain :vsplit physically reverses them when the user's global
    -- 'splitright' is off. Scope the option to view creation so old remains
    -- on the left and new on the right without changing normal split policy.
    local splitright = vim.o.splitright
    vim.o.splitright = true
    local ok, err = pcall(original_open, ...)
    vim.o.splitright = splitright
    if not ok then
      error(err, 0)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("SettingsDiffWindows", { clear = true })

  -- Difftastic does not expose view hooks. Its stable left/right buffer IDs
  -- let us target only its code panes as they open and when their filetype is
  -- assigned for Treesitter; the file tree is deliberately excluded.
  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
    group = group,
    callback = function(args)
      apply_difftastic_window_highlights(args.buf)
    end,
  })

  -- Neovim ignores scrollbind when the wheel event targets an unfocused
  -- window. Focus the hovered bound pane while the wheel key is still being
  -- processed so native scrolling keeps every diff viewer synchronized.
  vim.on_key(focus_hovered_scrollbound_window, wheel_focus_ns)
end

return M
