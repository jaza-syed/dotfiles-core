-- Run: nvim --headless -u NONE -i NONE -l tests/nvim_adapters.lua
-- Plugin compatibility adapters must rebuild from the pristine function on
-- every setup: no stacked wrappers, no stale closures kept across reloads.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")

local function reload(module)
  package.loaded[module] = nil
  return require(module)
end

-- cmp float placement wrapper
local pristine_calls = 0
local window_stub = {
  open = function(_, style)
    pristine_calls = pristine_calls + 1
    return style
  end,
}
local mapping = setmetatable({
  preset = {
    insert = function(t)
      return t
    end,
  },
}, {
  __call = function(_, f)
    return f
  end,
})
mapping.complete = function() end
mapping.select_next_item = function() end
mapping.select_prev_item = function() end
package.preload["cmp"] = function()
  return { setup = function() end, mapping = mapping, SelectBehavior = { Select = 1 } }
end
package.preload["cmp.config.context"] = function()
  return {}
end
package.preload["cmp.utils.window"] = function()
  return window_stub
end

local pristine_open = window_stub.open
for _ = 1, 2 do
  reload("config.completion").setup()
end
assert(window_stub._dotfiles_open == pristine_open, "cmp adapter lost the pristine open")
assert(window_stub.open ~= pristine_open, "cmp adapter did not install a wrapper")
window_stub.open(window_stub, { relative = "win" })
assert(pristine_calls == 1, "cmp wrapper stacked or skipped the pristine open")

-- difftastic splitright wrapper
local diff_calls = 0
local difftastic = {
  open = function(fail)
    diff_calls = diff_calls + 1
    assert(vim.o.splitright, "difftastic view did not open with splitright")
    if fail then
      error("boom")
    end
  end,
}
local diff_pristine = difftastic.open
vim.o.splitright = false
local diff_windows = require("config.diff_windows")
diff_windows.configure_difftastic(difftastic)
diff_windows.configure_difftastic(difftastic)
assert(difftastic._dotfiles_open == diff_pristine, "difftastic adapter lost the pristine open")
difftastic.open(false)
assert(diff_calls == 1, "difftastic wrapper stacked or skipped the pristine open")
assert(vim.o.splitright == false, "splitright not restored after success")
assert(not pcall(difftastic.open, true), "failure was swallowed")
assert(vim.o.splitright == false, "splitright not restored after failure")

-- mypy linter adapter
package.preload["lint"] = function()
  return { linters = {}, linters_by_ft = {} }
end
package.preload["lint.linters.mypy"] = function()
  return { cmd = "mypy", stdin = false, args = { "--strict" } }
end
for _ = 1, 2 do
  reload("config.lint").setup()
end
local lint = require("lint")
assert(type(lint.linters.mypy) == "function", "mypy adapter not installed")
local resolved = lint.linters.mypy()
assert(resolved.cmd == "uv" and resolved.stdin == false, "upstream mypy fields lost")
assert(vim.deep_equal(resolved.args, { "run", "mypy", "--strict" }), "mypy argv not rebuilt from upstream")

print("Adapter regression checks passed")
