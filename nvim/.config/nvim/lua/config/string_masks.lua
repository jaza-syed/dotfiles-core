-- Shared lifecycle for the per-language string whitespace maskers: Treesitter
-- query acquisition, buffer validation, refresh coalescing, extmark ownership,
-- and autocmds. Language adapters supply the query and an optional indent rule.
local M = {}

-- spec fields: filetype (also the parser language), ns and augroup names,
-- query text, and optional mask_col(node, lines, first_row, end_row, end_col)
-- returning the max column to mask, or nil for the full leading whitespace.
function M.new(spec)
  local instance = {}
  local ns = vim.api.nvim_create_namespace(spec.ns)
  local pending = {}
  local query_cache = nil
  local alive = true

  local function is_target_buffer(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == spec.filetype
  end

  local function get_query()
    if query_cache then
      return query_cache
    end

    local ok, query = pcall(vim.treesitter.query.parse, spec.filetype, spec.query)
    if not ok then
      return nil
    end

    query_cache = query
    return query_cache
  end

  local function get_parser(buf)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, spec.filetype)
    if not ok then
      return nil
    end
    return parser
  end

  local function mask_leading_whitespace(buf, node)
    local start_row, _, end_row, end_col = node:range()
    if start_row == end_row then
      return
    end

    local first_row = start_row + 1
    local line_count = vim.api.nvim_buf_line_count(buf)
    end_row = math.min(end_row, line_count - 1)
    if first_row > end_row then
      return
    end

    local lines = vim.api.nvim_buf_get_lines(buf, first_row, end_row + 1, false)
    local mask_col = spec.mask_col and spec.mask_col(node, lines, first_row, end_row, end_col) or math.huge

    for i, line in ipairs(lines) do
      local row = first_row + i - 1
      local indent = line:match("^[ \t]*") or ""
      local indent_end = math.min(#indent, mask_col)

      -- The final line may contain the closing delimiter followed by code. Only
      -- mask whitespace that is still inside the string node.
      if row == end_row then
        indent_end = math.min(indent_end, end_col)
      end

      if indent_end > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          end_row = row,
          end_col = indent_end,
          hl_group = "AlabasterStringLeadingWhitespace",
          priority = 120,
        })
      end
    end
  end

  function instance.refresh(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if not is_target_buffer(buf) then
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
      return
    end

    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    local query = get_query()
    local parser = get_parser(buf)
    if not query or not parser then
      return
    end

    local ok, trees = pcall(parser.parse, parser)
    if not ok or not trees then
      return
    end

    for _, tree in ipairs(trees) do
      local root = tree:root()
      for _, node in query:iter_captures(root, buf, 0, -1) do
        mask_leading_whitespace(buf, node)
      end
    end
  end

  local function schedule_refresh(buf)
    if pending[buf] then
      return
    end

    pending[buf] = true
    vim.defer_fn(function()
      pending[buf] = nil
      if alive then
        instance.refresh(buf)
      end
    end, 40)
  end

  function instance.setup()
    alive = true
    local group = vim.api.nvim_create_augroup(spec.augroup, { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = spec.filetype,
      callback = function(args)
        schedule_refresh(args.buf)
      end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
      group = group,
      callback = function(args)
        if is_target_buffer(args.buf) then
          schedule_refresh(args.buf)
        end
      end,
    })

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if is_target_buffer(buf) then
        schedule_refresh(buf)
      end
    end
  end

  -- Invalidate pending work so a deferred refresh from a torn-down instance
  -- cannot repaint after reload.
  function instance.teardown()
    alive = false
  end

  return instance
end

return M
