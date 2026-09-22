-- Run: nvim --headless -u NONE -i NONE -l tests/nvim_lint.lua
-- Saving a managed python file runs mypy once, from the uv workspace root and
-- inside its devshell. Everything else saves without running anything.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")

-- Resolved, because a buffer name is: on macOS /tmp is a symlink to /private/tmp.
local workspace = vim.fn.tempname()
vim.fn.mkdir(workspace .. "/member", "p")
workspace = vim.uv.fs_realpath(workspace)
vim.fn.writefile({ "[tool.uv.workspace]" }, workspace .. "/pyproject.toml")
vim.fn.writefile({ "[project]" }, workspace .. "/member/pyproject.toml")

package.preload["machine"] = function()
  return {
    is_managed = function(path)
      return vim.startswith(path or "", workspace)
    end,
  }
end

local runs = {}
vim.system = function(cmd, opts)
  table.insert(runs, { cmd = cmd, opts = opts })
  return { wait = function() end }
end

for _, module in ipairs({ "config.machine", "config.projects", "config.lint" }) do
  package.loaded[module] = nil
end
for _ = 1, 2 do
  package.loaded["config.lint"] = nil
  require("config.lint").setup()
end
assert(#vim.api.nvim_get_autocmds({ group = "ConfigLint", event = "BufWritePost" }) == 1, "stacked lint autocmds")

local function save(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, path)
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })
end

save(workspace .. "/member/mod.py")
assert(#runs == 1, "a managed save did not run mypy exactly once")
assert(
  vim.deep_equal(vim.list_slice(runs[1].cmd, 1, 6), { "direnv", "exec", workspace, "uv", "run", "mypy" }),
  "mypy did not run through the workspace root's devshell"
)
assert(runs[1].opts.cwd == workspace, "mypy ran outside the workspace root")

save("/private/tmp/unrelated/mod.py")
assert(#runs == 1, "an unmanaged save ran mypy")

print("Lint policy checks passed")
