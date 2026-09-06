-- Ordered lifecycle registry for the reloadable settings modules.
-- config.editor and settings.lua derive their setup sequences from it and
-- M.reload derives invalidation, so startup and reload cannot drift.
local M = {}

-- kind "editor": set up by config.editor before settings run.
-- kind "settings": set up by settings.lua, in registry order.
-- kind "helper": no setup; invalidated on reload so callers get new code.
-- optional: the module may be absent.
M.registry = {
  { module = "config.lsp", kind = "editor" },
  { module = "config.lsp.global_symbols", kind = "helper" },
  { module = "config.lint", kind = "editor" },
  { module = "config.completion", kind = "editor" },
  { module = "config.signature", kind = "editor" },
  { module = "config.pickers", kind = "helper" },
  { module = "config.options", kind = "settings" },
  { module = "config.ui", kind = "settings" },
  { module = "config.keymaps", kind = "settings" },
  { module = "config.window_move", kind = "helper" },
  { module = "config.markdown", kind = "settings" },
  { module = "config.python_strings", kind = "settings" },
  { module = "config.nix_strings", kind = "settings" },
  { module = "config.yaml_strings", kind = "settings" },
  { module = "config.string_masks", kind = "helper" },
  { module = "config.autocmds", kind = "settings" },
  { module = "config.diff_windows", kind = "settings" },
  { module = "config.theme", kind = "settings" },
  { module = "config.dap", kind = "settings" },
  { module = "config.projects", kind = "helper" },
  { module = "config.machine", kind = "helper" },
  { module = "machine", kind = "settings", optional = true },
}

function M.setup_kind(kind)
  for _, entry in ipairs(M.registry) do
    if entry.kind == kind then
      local ok, mod = pcall(require, entry.module)
      if ok and type(mod.setup) == "function" then
        mod.setup()
      elseif not entry.optional then
        error(ok and (entry.module .. " has no setup()") or mod, 0)
      end
    end
  end
end

function M.reload()
  local modules = { "settings", "config.editor" }
  for _, entry in ipairs(M.registry) do
    table.insert(modules, entry.module)
  end

  for _, module in ipairs(modules) do
    local loaded = package.loaded[module]
    if type(loaded) == "table" and type(loaded.teardown) == "function" then
      loaded.teardown()
    end
    package.loaded[module] = nil
  end

  require("config.editor").setup()
  require("settings")
end

return M
