-- No-op defaults over the optional per-machine "machine" module that the
-- machine repo links onto the runtimepath at ~/.config/nvim-local.
local ok, machine = pcall(require, "machine")
if not ok then
  machine = {}
end

local M = {}

-- Root of the machine-managed workspace, or nil.
M.workspace_root = machine.workspace_root

function M.is_managed(path)
  if machine.is_managed then
    return machine.is_managed(path)
  end
  return false
end

function M.before_init(params, config)
  if machine.before_init then
    machine.before_init(params, config)
  end
end

function M.abbrev_path_symbols(buf, symbols)
  if machine.abbrev_path_symbols then
    return machine.abbrev_path_symbols(buf, symbols)
  end
  return symbols
end

-- Dropbar title for a cwd, or nil to fall back to the absolute path.
function M.project_title(cwd)
  if machine.project_title then
    return machine.project_title(cwd)
  end
  return nil
end

return M
