-- Opens a mermaid block's rendered image in a split and rerenders it on write.
local M = {}

-- width and scale are mmdc's pixel dimensions, so they set how much detail
-- survives being fitted to the window.
M.mermaid_options = { theme = "neutral", width = 2400, scale = 2 }

local split_win = nil
local source_buf = nil
local block_index = nil

local function blocks(buf)
  return require("diagram.integrations.markdown").query_buffer_diagrams(buf)
end

-- range covers the ```mermaid line alone, so the closing fence is that row
-- plus the source's line count plus one.
local function index_at_cursor(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for i, diagram in ipairs(blocks(buf)) do
    local last_row = diagram.range.start_row + #vim.split(diagram.source, "\n") + 1
    if row >= diagram.range.start_row and row <= last_row then
      return i
    end
  end
end

local function render(diagram)
  return require("diagram.renderers.mermaid").render(diagram.source, M.mermaid_options).file_path
end

local function show(path)
  if not (split_win and vim.api.nvim_win_is_valid(split_win)) then
    return
  end

  local current = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(split_win)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
  vim.api.nvim_set_current_win(current)
end

-- mmdc runs as a job, so the file appears after the render call returns.
local function show_when_ready(path, attempts)
  if vim.fn.filereadable(path) == 1 then
    show(path)
    return
  end
  if attempts <= 0 then
    vim.notify("Timed out rendering the diagram", vim.log.levels.ERROR)
    return
  end
  vim.defer_fn(function()
    show_when_ready(path, attempts - 1)
  end, 200)
end

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  local index = index_at_cursor(buf)
  if not index then
    vim.notify("No diagram under the cursor", vim.log.levels.WARN)
    return
  end

  local path = render(blocks(buf)[index])
  -- A horizontal split, since these diagrams are far wider than they are tall.
  -- belowright rather than split, which 'splitbelow' being off puts on top.
  if not (split_win and vim.api.nvim_win_is_valid(split_win)) then
    local current = vim.api.nvim_get_current_win()
    vim.cmd("belowright split")
    split_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(current)
  end

  source_buf, block_index = buf, index
  show_when_ready(path, 150)
end

function M.setup()
  vim.api.nvim_create_user_command("DiagramSplit", M.open, {
    desc = "Open the diagram under the cursor in a split",
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("dotfiles_diagrams", { clear = true }),
    callback = function(ev)
      if ev.buf ~= source_buf or not block_index then
        return
      end
      local diagram = blocks(source_buf)[block_index]
      if diagram then
        show_when_ready(render(diagram), 150)
      end
    end,
  })
end

function M.teardown()
  split_win, source_buf, block_index = nil, nil, nil
end

return M
