-- Signature help for the call being typed, rendered as virtual lines below it
-- so it pushes code down rather than covering it. Off until the toggle key
-- turns it on.
local M = {}

local ns = vim.api.nvim_create_namespace("config.signature")

local WRAP_WIDTH = 80
local INDENT = "  "
local TITLE = " SIGNATURE "

-- Both keys sit under a prefix so neither shadows a single-key mapping.
local PREFIX = "<C-\\>"

-- The body is always this tall, so the code below the block does not move as
-- the documentation changes from keystroke to keystroke.
local BODY_HEIGHT = 6
local SPLIT_HEIGHT = 12

-- buf and line locate the extmark. result is the last response, which the
-- split key renders in full. split_label is the signature the split shows.
-- enabled gates the whole feature, including the requests.
local state = { buf = nil, line = nil, result = nil, split = nil, split_label = nil, enabled = false }
local generation = 0

local function split_open()
  return state.split ~= nil and vim.api.nvim_win_is_valid(state.split)
end

local function clear()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  end
  state.buf, state.line = nil, nil
end

local function invalidate()
  generation = generation + 1
  clear()
end

local function chunk_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + vim.fn.strdisplaywidth(chunk[1])
  end
  return width
end

-- Split the label at the parameter ranges the server sends. Each unit is one
-- parameter plus the separator that follows it, so a break puts the comma at
-- the end of a line rather than the start of the next.
local function label_units(signature, active)
  local label = signature.label
  local units, prefix, offset = {}, nil, 0

  local function whole_label()
    return { { { label, "SignatureType" } } }
  end

  for index, parameter in ipairs(signature.parameters or {}) do
    local range = parameter.label
    if type(range) ~= "table" then
      return whole_label()
    end

    local start, stop = range[1], range[2]
    local gap = label:sub(offset + 1, start)
    if index == 1 then
      prefix = { gap, "SignaturePunct" }
    else
      table.insert(units[#units], { gap, "SignaturePunct" })
    end

    local text = label:sub(start + 1, stop)
    local param, rest = text:match("^([%w_%*]+)(.*)$")
    local group = index == active + 1 and "SignatureActiveParam" or "SignatureParam"

    local chunks = {}
    if prefix then
      chunks[#chunks + 1] = prefix
      prefix = nil
    end
    if param then
      chunks[#chunks + 1] = { param, group }
      chunks[#chunks + 1] = { rest, "SignatureType" }
    else
      chunks[#chunks + 1] = { text, group }
    end

    units[#units + 1] = chunks
    offset = stop
  end

  local tail = label:sub(offset + 1)
  if tail ~= "" then
    if #units > 0 then
      table.insert(units[#units], { tail, "SignaturePunct" })
    else
      units = whole_label()
    end
  end

  return units
end

-- Fallback for a single argument wider than the limit, which cannot be broken
-- at an argument boundary. Without it the text past the window edge is lost.
local function hard_wrap(chunks, limit)
  local lines, current, width = {}, {}, 0

  for _, chunk in ipairs(chunks) do
    local text, group = chunk[1], chunk[2]
    while text ~= "" do
      if limit - width <= 0 then
        lines[#lines + 1] = current
        current = { { INDENT, "SignaturePunct" } }
        width = vim.fn.strdisplaywidth(INDENT)
      end

      local take = vim.fn.strcharpart(text, 0, limit - width)
      while take ~= "" and vim.fn.strdisplaywidth(take) > limit - width do
        take = vim.fn.strcharpart(take, 0, vim.fn.strchars(take) - 1)
      end
      if take == "" then
        break
      end

      current[#current + 1] = { take, group }
      width = width + vim.fn.strdisplaywidth(take)
      text = text:sub(#take + 1)
    end
  end

  if #current > 0 then
    lines[#lines + 1] = current
  end
  return lines
end

-- Virtual lines cannot exceed the text area, and the box spends 8 columns on
-- the indent and borders, so the wrap width is capped by the window too.
local function content_width()
  return math.max(20, math.min(WRAP_WIDTH, vim.api.nvim_win_get_width(0) - 8))
end

local function wrap(units, limit)
  local lines, current = {}, {}

  for _, unit in ipairs(units) do
    local width = chunk_width(unit)

    if width > limit then
      if #current > 0 then
        lines[#lines + 1] = current
        current = {}
      end
      vim.list_extend(lines, hard_wrap(unit, limit))
    else
      if #current > 0 and chunk_width(current) + width > limit then
        lines[#lines + 1] = current
        current = { { INDENT, "SignaturePunct" } }
      end
      vim.list_extend(current, unit)
    end
  end

  if #current > 0 then
    lines[#lines + 1] = current
  end

  -- A hard break can leave a line holding only the separator's trailing space.
  local kept = {}
  for _, line in ipairs(lines) do
    for _, chunk in ipairs(line) do
      if chunk[1]:match("%S") then
        kept[#kept + 1] = line
        break
      end
    end
  end
  return kept
end

local function documentation_of(signature)
  local documentation = signature.documentation
  if type(documentation) == "table" then
    documentation = documentation.value
  end
  return type(documentation) == "string" and documentation ~= "" and documentation or nil
end

local function truncate(text, width)
  text = vim.fn.strcharpart(text, 0, width)
  while text ~= "" and vim.fn.strdisplaywidth(text) > width do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text
end

-- Wrap the body in the same box review.nvim draws for an expanded thread.
local function boxed(body, width)
  local fill = math.max(1, width + 1 - vim.fn.strdisplaywidth(TITLE))
  local lines = {
    {
      { INDENT .. "╭─", "SignatureBorder" },
      { TITLE, "SignatureTitle" },
      { string.rep("─", fill) .. "╮", "SignatureBorder" },
    },
  }

  for _, row in ipairs(body) do
    local line = { { INDENT .. "│ ", "SignatureBorder" } }
    vim.list_extend(line, row)
    local pad = math.max(0, width - chunk_width(row))
    line[#line + 1] = { string.rep(" ", pad) .. " │", "SignatureBorder" }
    lines[#lines + 1] = line
  end

  lines[#lines + 1] = {
    { INDENT .. "╰" .. string.rep("─", width + 2) .. "╯", "SignatureBorder" },
  }
  return lines
end

local function render(result)
  local index = result.activeSignature or 0
  local signature = result.signatures[index + 1] or result.signatures[1]
  if not signature or not signature.label then
    return clear()
  end

  -- The split already shows this signature, so the block would repeat it.
  if split_open() and state.split_label == signature.label then
    return clear()
  end

  local active = signature.activeParameter or result.activeParameter
  if type(active) ~= "number" then
    active = -1
  end

  local width = content_width()
  local body = wrap(label_units(signature, active), width)
  while #body > BODY_HEIGHT - 1 do
    table.remove(body)
  end

  -- Only the first line of the documentation. <C-g> opens the rest in a split.
  local documentation = documentation_of(signature)
  if documentation then
    local first = vim.split(documentation, "\n", { plain = true })[1]
    body[#body + 1] = { { truncate(INDENT .. first, width), "SignatureDoc" } }
  end
  while #body < BODY_HEIGHT do
    body[#body + 1] = { { "", "SignatureBody" } }
  end

  local lines = boxed(body, width)
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1

  clear()
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    virt_lines = lines,
    virt_lines_overflow = "trunc",
  })
  state.buf, state.line = buf, line
end

-- The block pushes the surrounding code out of view, so it stays off until it
-- is asked for. Turning it off drops the in-flight request with the block.
function M.toggle()
  state.enabled = not state.enabled
  if state.enabled then
    M.update()
  else
    invalidate()
  end
end

function M.update()
  generation = generation + 1
  if not state.enabled then
    return clear()
  end
  local request_generation = generation
  if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
    return clear()
  end

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local changedtick = vim.api.nvim_buf_get_changedtick(buf)
  local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/signatureHelp" })[1]
  if not client then
    return clear()
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

  client:request("textDocument/signatureHelp", params, function(err, result)
    if
      request_generation ~= generation
      or vim.api.nvim_get_current_buf() ~= buf
      or vim.api.nvim_get_current_win() ~= win
      or vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i"
      or vim.api.nvim_buf_get_changedtick(buf) ~= changedtick
      or not vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor)
    then
      return
    end
    if err or not result or not result.signatures or #result.signatures == 0 then
      return clear()
    end
    if vim.api.nvim_get_current_buf() == buf then
      state.result = result
      render(result)
    end
  end, buf)
end

-- Move the last signature into a scrollable split. One way: close it with :q.
function M.open_split()
  local result = state.result
  if not result or not result.signatures then
    return
  end

  local signature = result.signatures[(result.activeSignature or 0) + 1] or result.signatures[1]
  if not signature then
    return
  end

  local active = signature.activeParameter or result.activeParameter
  if type(active) ~= "number" then
    active = -1
  end

  -- Same wrapping as the block, flattened into buffer text with the highlights
  -- re-applied as extmarks, since a real buffer cannot take chunk lists.
  local rows = wrap(label_units(signature, active), math.max(20, vim.api.nvim_win_get_width(0) - 2))
  local lines, marks = {}, {}

  for _, row in ipairs(rows) do
    local text = ""
    for _, chunk in ipairs(row) do
      marks[#marks + 1] = { #lines, #text, #text + #chunk[1], chunk[2] }
      text = text .. chunk[1]
    end
    lines[#lines + 1] = text
  end

  local documentation = documentation_of(signature)
  if documentation then
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(documentation, "\n", { plain = true }))
  end

  state.split_label = signature.label
  invalidate()

  -- Outrank treesitter so markdown highlights the documentation without
  -- reaching the signature lines.
  local priority = (vim.hl.priorities.treesitter or 100) + 10

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, mark in ipairs(marks) do
    if mark[3] > mark[2] then
      vim.api.nvim_buf_set_extmark(buf, ns, mark[1], mark[2], {
        end_col = mark[3],
        hl_group = mark[4],
        priority = priority,
      })
    end
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  -- Open/update the documentation without leaving the editing window or mode.
  if not (state.split and vim.api.nvim_win_is_valid(state.split)) then
    state.split = vim.api.nvim_open_win(buf, false, {
      split = "below",
      win = vim.api.nvim_get_current_win(),
      height = SPLIT_HEIGHT,
    })
  end

  vim.api.nvim_win_set_buf(state.split, buf)
  vim.wo[state.split].wrap = true
  vim.wo[state.split].winfixheight = true
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close signature split" })
end

M.teardown = invalidate

function M.setup()
  invalidate()
  local group = vim.api.nvim_create_augroup("ConfigSignature", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    group = group,
    callback = M.update,
  })

  vim.keymap.set({ "i", "n" }, PREFIX .. "<C-s>", M.open_split, { desc = "Signature help in a split" })
  vim.keymap.set({ "i", "n" }, PREFIX .. "<C-t>", M.toggle, { desc = "Toggle signature help" })

  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = group,
    callback = invalidate,
  })
end

return M
