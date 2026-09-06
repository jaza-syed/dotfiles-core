-- Markdown rendering helpers for code-block backgrounds and cursorline.
local M = {}

local markdown_code_block_ns = vim.api.nvim_create_namespace("AlabasterMarkdownCodeBlock")
local markdown_code_block_query = nil

do
  local ok, query = pcall(
    vim.treesitter.query.parse,
    "markdown",
    [[
    (fenced_code_block) @code_block
    (indented_code_block) @code_block
  ]]
  )
  if ok then
    markdown_code_block_query = query
  end
end

local function clear_window_match(win, var_name)
  local ok, id = pcall(vim.api.nvim_win_get_var, win, var_name)
  if ok then
    pcall(vim.fn.matchdelete, id, win)
    pcall(vim.api.nvim_win_del_var, win, var_name)
  end
end

local function clear_markdown_cursorline(win)
  clear_window_match(win, "markdown_cursorline_match_id")
end

local function collect_markdown_fence_lines_fallback(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local positions = {}
  local fence_char = nil
  local fence_len = 0

  for lnum, line in ipairs(lines) do
    if fence_char then
      positions[#positions + 1] = { row = lnum - 1, end_col = #line }
      local closing_marker = line:match("^%s*([`~]+)%s*$")
      if
        closing_marker
        and closing_marker:sub(1, 1) == fence_char
        and closing_marker == fence_char:rep(#closing_marker)
        and #closing_marker >= fence_len
      then
        fence_char = nil
        fence_len = 0
      end
    else
      local marker = line:match("^%s*([`~]+)")
      if marker and #marker >= 3 and marker == marker:sub(1, 1):rep(#marker) then
        fence_char = marker:sub(1, 1)
        fence_len = #marker
        positions[#positions + 1] = { row = lnum - 1, end_col = #line }
      end
    end
  end

  return positions
end

local function collect_markdown_fence_lines(buf)
  if not markdown_code_block_query then
    return collect_markdown_fence_lines_fallback(buf)
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return collect_markdown_fence_lines_fallback(buf)
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local positions = {}
  local seen = {}

  for _, tree in ipairs(parser:parse()) do
    local root = tree:root()
    for capture_id, node in markdown_code_block_query:iter_captures(root, buf, 0, -1) do
      if markdown_code_block_query.captures[capture_id] == "code_block" then
        local start_row, _, end_row, _ = node:range()
        for row = start_row, end_row - 1 do
          if not seen[row] then
            seen[row] = true
            positions[#positions + 1] = {
              row = row,
              end_col = #(lines[row + 1] or ""),
            }
          end
        end
      end
    end
  end

  if #positions == 0 then
    return collect_markdown_fence_lines_fallback(buf)
  end

  table.sort(positions, function(a, b)
    return a.row < b.row
  end)

  return positions
end

local function refresh_window_highlights(win)
  win = win or 0
  require("colors").apply_window_highlights(win)

  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "markdown" then
    return
  end
end

local function refresh_markdown_code_block_highlights(win)
  win = win or 0
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_buf_clear_namespace(buf, markdown_code_block_ns, 0, -1)

  if vim.bo[buf].filetype ~= "markdown" then
    return
  end

  local positions = collect_markdown_fence_lines(buf)
  for _, pos in ipairs(positions) do
    vim.api.nvim_buf_set_extmark(buf, markdown_code_block_ns, pos.row, 0, {
      hl_group = "AlabasterMarkdownCodeBlock",
      line_hl_group = "AlabasterMarkdownCodeBlock",
      end_row = pos.row,
      end_col = pos.end_col,
      hl_eol = true,
      cursorline_hl_group = "CursorLine",
      priority = 100,
    })
  end
end

local function refresh_markdown_cursorline(win)
  win = win or 0
  clear_markdown_cursorline(win)

  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "markdown" then
    return
  end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local id = vim.fn.matchaddpos("CursorLine", { { line } }, 200, -1, { window = win })
  vim.api.nvim_win_set_var(win, "markdown_cursorline_match_id", id)
end

local function refresh_markdown_window(win)
  win = win or 0
  refresh_window_highlights(win)
  refresh_markdown_code_block_highlights(win)
  refresh_markdown_cursorline(win)
end

function M.setup_buffer(win)
  win = win or 0
  vim.opt_local.spell = false
  vim.opt_local.linebreak = true
  refresh_markdown_window(win)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("SettingsMarkdown", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function()
      refresh_markdown_window(0)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      refresh_markdown_cursorline(0)
    end,
  })
end

return M
