-- Shared project path detection helpers.
local M = {}

local function trim_trailing_slash(path)
  while #path > 1 and path:sub(-1) == "/" do
    path = path:sub(1, -2)
  end
  return path
end

function M.normalize(path)
  if not path or path == "" then
    return nil
  end

  local expanded = vim.fn.expand(path)
  local normalized = vim.fs.normalize(vim.fn.fnamemodify(expanded, ":p"))
  return trim_trailing_slash(normalized)
end

function M.is_under(path, root)
  path = M.normalize(path)
  root = M.normalize(root)
  if not path or not root then
    return false
  end

  return path == root or vim.startswith(path, root .. "/")
end

-- Nearest ancestor of `path` holding an .envrc (a direnv/devshell root), or nil.
function M.env_root(path)
  path = M.normalize(path)
  return path and vim.fs.root(path, ".envrc") or nil
end

-- Prepend `direnv exec <env_root>` so an env-sensitive tool runs inside the
-- sub-repo's devshell. Only applies under the machine-managed workspace;
-- elsewhere the argv is returned unchanged (with a nil root) so system tools
-- resolve normally.
function M.direnv_wrap(argv, path)
  local root = require("config.machine").is_managed(path) and M.env_root(path) or nil
  if not root then
    return argv, nil
  end
  return vim.list_extend({ "direnv", "exec", root }, argv), root
end

local function file_matches(file, key)
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then
    return false
  end
  for _, line in ipairs(lines) do
    if line:find(key, 1, true) then
      return true
    end
  end
  return false
end

-- Root for a workspace-aware language server. Returns the outermost ancestor
-- whose `marker` file declares a workspace (contains `key`, e.g. cargo
-- "[workspace]" or uv "[tool.uv.workspace]"), else the nearest `marker`, else
-- the nearest .git. This collapses workspace members into one client while
-- leaving standalone projects rooted at their own package.
function M.workspace_root(path, marker, key)
  path = M.normalize(path)
  if not path then
    return nil
  end

  local markers = vim.fs.find(marker, { path = path, upward = true, limit = math.huge })
  local nearest, workspace
  for _, file in ipairs(markers) do
    local dir = vim.fs.dirname(file)
    nearest = nearest or dir
    if file_matches(file, key) then
      workspace = dir
    end
  end

  return workspace or nearest or vim.fs.root(path, ".git")
end

return M
