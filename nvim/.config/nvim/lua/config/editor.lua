-- Editor integration orchestrator for LSP, linting, and completion.
-- The module list and order live in config.reload's registry.
local M = {}

function M.setup()
  require("config.reload").setup_kind("editor")
end

return M
