-- Renders mermaid code blocks as virtual lines below the block, via mmdflux.
local M = {}

local ns = vim.api.nvim_create_namespace("DotfilesDiagrams")
local query = vim.treesitter.query.parse(
  "markdown",
  [[
    (fenced_code_block
      (info_string (language) @lang)
      (code_fence_content) @content
      (#eq? @lang "mermaid"))
  ]]
)

local enabled = {}
local timers = {}

local function virt_lines(text, hl)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = { { line, hl } }
  end
  -- gmatch on a trailing newline yields one empty final line.
  table.remove(lines)
  return lines
end

-- Each block renders on its own, so one failing block does not hide the rest.
local function render(buf, end_row, source)
  vim.system({ "mmdflux", "--format", "text", "--color", "off" }, { stdin = source, text = true }, function(done)
    vim.schedule(function()
      if not enabled[buf] or not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local failed = done.code ~= 0
      local text = failed and (done.stderr or "") or done.stdout
      if text == "" then
        return
      end

      pcall(vim.api.nvim_buf_set_extmark, buf, ns, end_row, 0, {
        virt_lines = virt_lines(text, failed and "DiagnosticError" or "Comment"),
      })
    end)
  end)
end

local function refresh(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not enabled[buf] then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return
  end

  for _, tree in ipairs(parser:parse()) do
    for id, node in query:iter_captures(tree:root(), buf, 0, -1) do
      if query.captures[id] == "content" then
        local _, _, end_row, _ = node:range()
        render(buf, end_row, vim.treesitter.get_node_text(node, buf))
      end
    end
  end
end

local function schedule_refresh(buf)
  if timers[buf] then
    timers[buf]:stop()
  end
  timers[buf] = vim.defer_fn(function()
    timers[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
      refresh(buf)
    end
  end, 300)
end

function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if not enabled[buf] and vim.fn.executable("mmdflux") == 0 then
    vim.notify("mmdflux is not on PATH", vim.log.levels.WARN)
    return
  end

  enabled[buf] = not enabled[buf] or nil
  refresh(buf)
end

function M.setup()
  vim.api.nvim_create_user_command("DiagramsToggle", function()
    M.toggle()
  end, { desc = "Toggle mermaid diagram rendering in this buffer" })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("dotfiles_diagrams", { clear = true }),
    pattern = "*.md",
    callback = function(ev)
      if enabled[ev.buf] then
        schedule_refresh(ev.buf)
      end
    end,
  })
end

function M.teardown()
  for buf in pairs(enabled) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
  enabled = {}
end

return M
