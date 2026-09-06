-- Telescope picker for ty's dependency-aware `ty/globalSymbols` request.
local M = {}

local METHOD = "ty/globalSymbols"
local DEFAULT_LIMIT = 500
local DEFAULT_TIMEOUT_MS = 5000

local function ty_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "ty" })
  local supported = {}

  for _, client in ipairs(clients) do
    local experimental = client.server_capabilities and client.server_capabilities.experimental
    if type(experimental) == "table" and experimental.tyGlobalSymbolsProvider == true then
      table.insert(supported, client)
    end
  end

  return supported
end

local function kind_name(kind)
  if type(kind) == "string" then
    return kind
  end

  return vim.lsp.protocol.SymbolKind[kind] or tostring(kind or "Symbol")
end

local function location_target(location)
  if not location or not location.uri or not location.range or not location.range.start then
    return nil
  end

  local uri = tostring(location.uri)
  local filename = nil
  if uri:match("^file://") then
    local ok, path = pcall(vim.uri_to_fname, uri)
    if ok and path and path ~= "" then
      filename = path
    end
  end

  return {
    uri = uri,
    filename = filename,
    lnum = (location.range.start.line or 0) + 1,
    col = (location.range.start.character or 0) + 1,
  }
end

local function symbol_text(symbol)
  local qualified = symbol.qualifiedName or symbol.name or ""
  local text = string.format("[%s] %s", kind_name(symbol.kind), qualified)

  if symbol.deprecated then
    text = text .. " [deprecated]"
  end

  return text
end

local function request_global_symbols(client, bufnr, query, opts)
  local response, err = client:request_sync(METHOD, {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    query = query,
    limit = opts.limit or DEFAULT_LIMIT,
  }, opts.timeout_ms or DEFAULT_TIMEOUT_MS, bufnr)

  if err or not response or response.err then
    return {}
  end

  return response.result or {}
end

local function entries_for_query(query, opts, clients)
  if not query or #query < (opts.min_query or 1) then
    return {}
  end

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local entries = {}

  for _, client in ipairs(clients) do
    for _, symbol in ipairs(request_global_symbols(client, bufnr, query, opts)) do
      local target = location_target(symbol.location)
      if target then
        table.insert(
          entries,
          vim.tbl_extend("force", target, {
            text = symbol_text(symbol),
            symbol = symbol,
          })
        )
      end
    end
  end

  return entries
end

local function display_path(entry)
  if entry.filename and entry.filename ~= "" then
    return vim.fn.fnamemodify(entry.filename, ":~:.")
  end
  return entry.uri
end

local function telescope_entry(entry)
  return {
    value = entry,
    ordinal = entry.text,
    display = string.format("%s:%d:%d  %s", display_path(entry), entry.lnum, entry.col, entry.text),
    filename = entry.filename,
    lnum = entry.lnum,
    col = entry.col,
    text = entry.text,
    uri = entry.uri,
  }
end

local function jump_to_entry(entry, command)
  local target = entry and (entry.value or entry)
  if not target then
    return
  end

  if target.filename and target.filename ~= "" then
    vim.cmd(command .. " " .. vim.fn.fnameescape(target.filename))
    vim.api.nvim_win_set_cursor(0, { target.lnum, math.max(target.col - 1, 0) })
    vim.cmd("normal! zv")
    return
  end

  local location = {
    uri = target.uri,
    range = {
      start = {
        line = target.lnum - 1,
        character = target.col - 1,
      },
      ["end"] = {
        line = target.lnum - 1,
        character = target.col - 1,
      },
    },
  }

  vim.lsp.util.jump_to_location(location, "utf-8", true)
end

local function quickfix_item(entry)
  local target = entry and (entry.value or entry)
  if not target or not target.filename then
    return nil
  end

  return {
    filename = target.filename,
    lnum = target.lnum,
    col = target.col,
    text = target.text,
  }
end

local function send_to_quickfix(prompt_bufnr)
  local state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local picker = state.get_current_picker(prompt_bufnr)
  local selections = picker:get_multi_selection()

  if #selections == 0 then
    local selected = state.get_selected_entry()
    if selected then
      selections = { selected }
    end
  end

  local items = {}
  for _, entry in ipairs(selections) do
    local item = quickfix_item(entry)
    if item then
      table.insert(items, item)
    end
  end

  actions.close(prompt_bufnr)
  if #items == 0 then
    vim.notify("No file-backed global symbols selected", vim.log.levels.WARN)
    return
  end

  vim.fn.setqflist({}, " ", { title = "Global symbols", items = items })
  vim.cmd("copen")
end

local function attach_mappings(bufnr, toggle, toggle_desc)
  return function(prompt_bufnr, map)
    local state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local function open_with(command)
      return function()
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        jump_to_entry(entry, command)
      end
    end

    local function toggle_mode()
      local query = state.get_current_line()
      actions.close(prompt_bufnr)
      vim.schedule(function()
        toggle({ bufnr = bufnr, query = query, default_text = query })
      end)
    end

    actions.select_default:replace(open_with("edit"))
    map({ "i", "n" }, "<C-s>", open_with("split"), { desc = "Open in split" })
    map({ "i", "n" }, "<C-v>", open_with("vsplit"), { desc = "Open in vertical split" })
    map({ "i", "n" }, "<C-t>", open_with("tabedit"), { desc = "Open in tab" })
    map({ "i", "n" }, "<C-q>", send_to_quickfix, { desc = "Send to quickfix" })
    map({ "i", "n" }, "<C-g>", toggle_mode, { desc = toggle_desc })
    return true
  end
end

local function resolve_clients(opts)
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local clients = ty_clients(bufnr)
  if #clients == 0 then
    vim.notify("No ty client with globalSymbols support attached", vim.log.levels.WARN)
    return nil
  end
  return bufnr, clients
end

function M.live_global_symbols(opts)
  opts = opts or {}
  local bufnr, clients = resolve_clients(opts)
  if not bufnr then
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local conf = require("telescope.config").values
  local picker_opts = vim.tbl_extend("force", {
    bufnr = bufnr,
    prompt_title = "Global symbols (live, <C-g> local refine, <C-/> help)",
    default_text = opts.query,
  }, opts)

  pickers
    .new(picker_opts, {
      finder = finders.new_dynamic({
        fn = function(prompt)
          return entries_for_query(prompt, picker_opts, clients)
        end,
        entry_maker = telescope_entry,
      }),
      sorter = sorters.highlighter_only(picker_opts),
      previewer = conf.grep_previewer(picker_opts),
      attach_mappings = attach_mappings(bufnr, M.static_global_symbols, "Local fuzzy refine results"),
    })
    :find()
end

function M.static_global_symbols(opts)
  opts = opts or {}
  local bufnr, clients = resolve_clients(opts)
  if not bufnr then
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local query = opts.query or ""
  local picker_opts = vim.tbl_extend("force", {
    bufnr = bufnr,
    prompt_title = "Global symbols (local, <C-g> search again, <C-/> help)",
    default_text = query,
  }, opts)

  pickers
    .new(picker_opts, {
      finder = finders.new_table({
        results = entries_for_query(query, picker_opts, clients),
        entry_maker = telescope_entry,
      }),
      sorter = conf.generic_sorter(picker_opts),
      previewer = conf.grep_previewer(picker_opts),
      attach_mappings = attach_mappings(bufnr, M.live_global_symbols, "Search symbols again"),
    })
    :find()
end

return M
