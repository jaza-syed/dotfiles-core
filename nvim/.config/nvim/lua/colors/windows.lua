-- Window-local highlight namespace helpers for markdown, zen mode, and diff viewers.
local M = {}

local diff_window_var = "alabaster_diff_window"

M.markdown_hl_ns = vim.api.nvim_create_namespace("AlabasterMarkdownNoBg")
M.zen_hl_ns = vim.api.nvim_create_namespace("AlabasterZen")
M.zen_markdown_hl_ns = vim.api.nvim_create_namespace("AlabasterZenMarkdown")

-- Diff panes need side-specific colours: native diff paints lines unique to a
-- buffer with DiffAdd in both panes, so the left pane must render them as
-- deletions. A namespace is per-window, hence one per side.
M.diff_hl_ns = {
  a = vim.api.nvim_create_namespace("AlabasterDiffA"),
  b = vim.api.nvim_create_namespace("AlabasterDiffB"),
}
M.diff_markdown_hl_ns = {
  a = vim.api.nvim_create_namespace("AlabasterDiffMarkdownA"),
  b = vim.api.nvim_create_namespace("AlabasterDiffMarkdownB"),
}

local applied_ns_var = "alabaster_applied_hl_ns"

-- Assigning a window namespace permanently overrides 'winhighlight' for that
-- window, and no value (including -1) undoes it. Windows that need no
-- namespace of ours must therefore never be assigned one. Pass nil for those.
local function set_hl_ns(win, ns)
  local ok, previous = pcall(vim.api.nvim_win_get_var, win, applied_ns_var)
  previous = ok and previous or nil

  if previous == ns or (previous == nil and ns == nil) then
    return
  end

  vim.api.nvim_win_set_hl_ns(win, ns or -1)
  vim.api.nvim_win_set_var(win, applied_ns_var, ns or -1)
end

local function set_namespace_highlights(namespace, theme)
  for group, hl in pairs(theme) do
    vim.api.nvim_set_hl(namespace, group, hl)
  end
end

---@param diff_themes table Per-side themes, keyed "a" (left) and "b" (right).
function M.apply_highlights(markdown_theme, zen_theme, diff_themes)
  set_namespace_highlights(M.markdown_hl_ns, markdown_theme)
  set_namespace_highlights(M.zen_hl_ns, zen_theme)

  local zen_markdown_theme = vim.tbl_extend("force", {}, markdown_theme, zen_theme)
  set_namespace_highlights(M.zen_markdown_hl_ns, zen_markdown_theme)

  for side, theme in pairs(diff_themes) do
    set_namespace_highlights(M.diff_hl_ns[side], theme)

    -- Markdown remains the more specific context when shown inside a diff viewer.
    set_namespace_highlights(M.diff_markdown_hl_ns[side], vim.tbl_extend("force", {}, theme, markdown_theme))
  end
end

function M.apply_window_highlights(win)
  local target = (win == nil or win == 0) and vim.api.nvim_get_current_win() or win
  local buf = vim.api.nvim_win_get_buf(target)
  local ft = vim.bo[buf].filetype
  local has_diff_context, diff_side = pcall(vim.api.nvim_win_get_var, target, diff_window_var)
  local is_zen = false
  local ok, view = pcall(require, "zen-mode.view")
  if ok and view.win and vim.api.nvim_win_is_valid(view.win) then
    is_zen = target == view.win
  end

  if has_diff_context and M.diff_hl_ns[diff_side] then
    local by_side = ft == "markdown" and M.diff_markdown_hl_ns or M.diff_hl_ns
    set_hl_ns(target, by_side[diff_side])
  elseif is_zen then
    set_hl_ns(target, ft == "markdown" and M.zen_markdown_hl_ns or M.zen_hl_ns)
  else
    set_hl_ns(target, ft == "markdown" and M.markdown_hl_ns or nil)
  end
end

---@param side string|nil Diffview layout symbol; only "a" and "b" are styled.
function M.apply_diff_window_highlights(win, side)
  local target = (win == nil or win == 0) and vim.api.nvim_get_current_win() or win
  if not vim.api.nvim_win_is_valid(target) then
    return
  end

  vim.api.nvim_win_set_var(target, diff_window_var, side or "b")
  M.apply_window_highlights(target)
end

return M
