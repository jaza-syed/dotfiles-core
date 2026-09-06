-- nvim-lint configuration and project-specific lint policies.
local M = {}

local projects = require("config.projects")
local machine = require("config.machine")

-- nvim-lint resolves a linter entry that is a function per invocation, so this
-- is where a per-buffer cmd/cwd/args can be chosen. The table fields themselves
-- must stay plain strings.
local function configure_mypy(lint)
  -- The pristine upstream definition, regardless of any adapter installed by an
  -- earlier setup. Rebuilding on every setup keeps reloads on current code.
  local base = require("lint.linters.mypy")

  -- Run from the workspace root so `uv run` resolves the right project, and
  -- through `direnv exec <root>` in managed projects so mypy uses the devshell.
  lint.linters.mypy = function()
    local name = vim.api.nvim_buf_get_name(0)
    local root = machine.is_managed(name) and projects.workspace_root(name, "pyproject.toml", "[tool.uv.workspace]")
      or nil
    local argv = root and { "exec", root, "uv", "run", "mypy" } or { "run", "mypy" }

    return vim.tbl_extend("force", base, {
      cmd = root and "direnv" or "uv",
      cwd = root or vim.fn.getcwd(),
      args = vim.list_extend(argv, base.args or {}),
    })
  end
end

function M.setup()
  local lint = require("lint")
  configure_mypy(lint)

  -- Don't run anything by default. Project policies opt into linters below.
  lint.linters_by_ft = { python = {} }

  local group = vim.api.nvim_create_augroup("ConfigLint", { clear = true })

  -- mypy: type checking diagnostics on save for managed projects via nvim-lint.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.py",
    callback = function()
      local bufname = vim.api.nvim_buf_get_name(0)
      if machine.is_managed(bufname) then
        lint.try_lint("mypy")
      end
    end,
  })
end

return M
