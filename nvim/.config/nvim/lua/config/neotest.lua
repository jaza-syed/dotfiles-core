-- Neotest policies: run each test command inside its devshell, and rescan the
-- project for test files on demand.
local M = {}

-- A debugger run carries a DAP config rather than a command, so it keeps the
-- ambient toolchain.
local function wrap_command(spec, position_path)
  if not spec.command then
    return
  end

  local root = require("config.projects").direnv_root(spec.cwd or position_path)
  if not root then
    return
  end

  -- direnv exec loads the env without changing directory, so the spec's own
  -- cwd still decides where the tests run.
  spec.env = vim.tbl_extend("keep", spec.env or {}, { DIRENV_LOG_FORMAT = "" })
  if type(spec.command) == "string" then
    -- build_spec runs in a fast event context, where vim.fn.shellescape raises E5560.
    local quoted = "'" .. root:gsub("'", [['\'']]) .. "'"
    spec.command = ("direnv exec %s %s"):format(quoted, spec.command)
  else
    spec.command = vim.list_extend({ "direnv", "exec", root }, spec.command)
  end
end

-- The adapter, with its test commands run through `direnv exec <devshell>` so
-- the runner comes from the sub-repo. Unchanged outside the managed workspace.
function M.direnv_adapter(adapter)
  adapter._dotfiles_build_spec = adapter._dotfiles_build_spec or adapter.build_spec
  local build_spec = adapter._dotfiles_build_spec
  adapter.build_spec = function(args)
    local spec = build_spec(args)
    if type(spec) ~= "table" then
      return spec
    end
    local position_path = args.tree:data().path
    for _, one in ipairs(vim.islist(spec) and spec or { spec }) do
      wrap_command(one, position_path)
    end
    return spec
  end
  return adapter
end

-- Neotest picks up a test file only on BufAdd or BufWritePost, so a file
-- created outside Neovim needs an explicit rescan of the adapter roots.
M.consumers = {
  refresh = function(client)
    return {
      refresh = function()
        require("nio").run(function()
          for _, adapter_id in ipairs(client:get_adapters()) do
            local root = client:get_position(nil, { adapter = adapter_id })
            client:_update_positions(root:data().path, { adapter = adapter_id })
          end
        end)
      end,
    }
  end,
}

return M
