-- Project-wide mypy for the machine-managed workspace. One run per save fills
-- the quickfix list and the diagnostics of every file mypy reports on.
local M = {}

local projects = require("config.projects")
local machine = require("config.machine")

local severities = {
  e = vim.diagnostic.severity.ERROR,
  w = vim.diagnostic.severity.WARN,
  n = vim.diagnostic.severity.HINT,
}

-- mypy writes `path:line:col: severity: message`. A note elaborating on an
-- error carries no column, hence the second branch.
local errorformat = "%f:%l:%c: %t%*[^:]: %m,%f:%l: %t%*[^:]: %m"

local namespaces = {}
local latest = {}

local function namespace(root)
  namespaces[root] = namespaces[root] or vim.api.nvim_create_namespace("config.lint.mypy:" .. root)
  return namespaces[root]
end

-- mypy reports paths relative to the workspace root, which quickfix would
-- otherwise resolve against Vim's cwd.
local function rooted(root, line)
  return vim.startswith(line, "/") and line or (root .. "/" .. line)
end

-- The id of the list a root already owns, found by title. Looked up per publish
-- rather than kept, since pushing any new list frees the ones after it.
local function list_id(title)
  for nr = 1, vim.fn.getqflist({ nr = "$" }).nr do
    local list = vim.fn.getqflist({ nr = nr, id = 0, title = 0 })
    if list.title == title then
      return list.id
    end
  end
end

local function publish(root, output)
  local lines = {}
  for _, line in ipairs(vim.split(output, "\n", { trimempty = true })) do
    table.insert(lines, rooted(root, line))
  end

  local items = vim.tbl_filter(function(item)
    return item.valid == 1 and item.bufnr > 0
  end, vim.fn.getqflist({ lines = lines, efm = errorformat }).items)

  -- `u` updates the root's own list wherever it is in the stack and keeps the
  -- selected entry. Without an id it would overwrite whatever list is current,
  -- so a clean run with no list yet writes nothing.
  local title = "mypy " .. vim.fn.fnamemodify(root, ":t")
  local id = list_id(title)
  if id then
    vim.fn.setqflist({}, "u", { id = id, title = title, items = items })
  elseif #items > 0 then
    vim.fn.setqflist({}, " ", { title = title, items = items })
  end

  local by_buffer = {}
  for _, item in ipairs(items) do
    by_buffer[item.bufnr] = by_buffer[item.bufnr] or {}
    table.insert(by_buffer[item.bufnr], {
      lnum = item.lnum - 1,
      col = math.max(item.col - 1, 0),
      severity = severities[item.type] or vim.diagnostic.severity.ERROR,
      message = item.text,
      source = "mypy",
    })
  end

  vim.diagnostic.reset(namespace(root))
  for bufnr, diagnostics in pairs(by_buffer) do
    vim.diagnostic.set(namespace(root), bufnr, diagnostics)
  end
end

-- Run from the workspace root, through `direnv exec <root>` so mypy comes from
-- the devshell and resolves the same project CI does.
local function check(root)
  latest[root] = (latest[root] or 0) + 1
  local token = latest[root]

  vim.system({
    "direnv",
    "exec",
    root,
    "uv",
    "run",
    "mypy",
    "--show-column-numbers",
    "--no-error-summary",
    "--no-pretty",
  }, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      -- A slow run must not overwrite the results of a newer one.
      if token ~= latest[root] then
        return
      end
      -- mypy exits 1 for the errors it found and 2 for a failure to run.
      if result.code > 1 then
        vim.notify(result.stderr or "mypy failed", vim.log.levels.WARN)
        return
      end
      publish(root, result.stdout or "")
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("ConfigLint", { clear = true }),
    pattern = "*.py",
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if not machine.is_managed(name) then
        return
      end

      local root = projects.workspace_root(name, "pyproject.toml", "[tool.uv.workspace]")
      if root then
        check(root)
      end
    end,
  })
end

return M
