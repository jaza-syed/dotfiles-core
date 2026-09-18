-- Opens a mermaid block's rendered image in a split and rerenders it on write.
local M = {}

-- width and scale are mmdc's pixel dimensions, so they set how much detail
-- survives being fitted to the window.
M.mermaid_options = { theme = "neutral", width = 2400, scale = 2 }

local split_win = nil
local source_buf = nil
local block_index = nil
-- Width in columns, nil while the image is fitted to the window.
local width = nil

local STEP = 20

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

local function images()
  if not (split_win and vim.api.nvim_win_is_valid(split_win)) then
    return {}
  end
  return require("image").get_images({ window = split_win })
end

-- image.nvim only ever shrinks an image to fit, so overflowing the window
-- needs ignore_global_max_size as well as a width.
local function resize()
  for _, image in ipairs(images()) do
    image.ignore_global_max_size = width ~= nil
    image.geometry.width = width
    image:render()
  end
end

local function scale(columns)
  local current = width or (images()[1] and images()[1].rendered_geometry.width)
  if not current then
    vim.notify("No diagram is displayed", vim.log.levels.WARN)
    return
  end
  width = math.max(STEP, current + columns)
  resize()
end

local function fit()
  width = nil
  resize()
end

local function show(path)
  if not (split_win and vim.api.nvim_win_is_valid(split_win)) then
    return
  end

  local current = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(split_win)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))

  -- Each refresh swaps in a buffer for the new path, so the keys are rebound.
  local opts = { buffer = 0, nowait = true }
  for _, key in ipairs({ "+", "=" }) do
    vim.keymap.set("n", key, function()
      scale(STEP)
    end, vim.tbl_extend("force", opts, { desc = "Widen the diagram" }))
  end
  vim.keymap.set("n", "-", function()
    scale(-STEP)
  end, vim.tbl_extend("force", opts, { desc = "Narrow the diagram" }))
  vim.keymap.set("n", "0", fit, vim.tbl_extend("force", opts, { desc = "Fit the diagram to the window" }))

  resize()
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

  -- A width set on the last diagram should not carry over to this one. A write
  -- keeps it, since show reapplies it.
  source_buf, block_index, width = buf, index, nil
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
  split_win, source_buf, block_index, width = nil, nil, nil, nil
end

return M
