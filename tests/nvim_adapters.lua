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

-- neotest devshell adapter
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture .. "/pkg", "p")
vim.fn.writefile({ "use flake" }, fixture .. "/.envrc")
package.preload["machine"] = function()
  return {
    is_managed = function(path)
      return vim.startswith(path or "", fixture)
    end,
  }
end
reload("config.machine")
reload("config.projects")
local test_policy = reload("config.neotest")

local managed = fixture .. "/pkg/test_a.py"
local function tree_for(path)
  return {
    data = function()
      return { path = path }
    end,
  }
end
local spec_calls = 0
local argv_adapter = {
  build_spec = function(args)
    spec_calls = spec_calls + 1
    return { command = { "pytest", args.tree:data().path } }
  end,
}
local argv_pristine = argv_adapter.build_spec
for _ = 1, 2 do
  test_policy.direnv_adapter(argv_adapter)
end
assert(argv_adapter._dotfiles_build_spec == argv_pristine, "neotest adapter lost the pristine build_spec")
local argv_spec = argv_adapter.build_spec({ tree = tree_for(managed) })
assert(spec_calls == 1, "neotest wrapper stacked or skipped the pristine build_spec")
assert(
  vim.deep_equal(argv_spec.command, { "direnv", "exec", fixture, "pytest", managed }),
  "argv not wrapped in direnv"
)
assert(argv_spec.env.DIRENV_LOG_FORMAT == "", "direnv would log into the test output")

-- A shell-string command is wrapped in place, keeping its own quoting.
local string_adapter = test_policy.direnv_adapter({
  build_spec = function()
    return { command = "cargo nextest run -E 'test(/^a$/)'", cwd = fixture .. "/pkg" }
  end,
})
local string_spec = string_adapter.build_spec({ tree = tree_for(managed) })
assert(
  string_spec.command == "direnv exec " .. vim.fn.shellescape(fixture) .. " cargo nextest run -E 'test(/^a$/)'",
  "shell command not wrapped in direnv"
)

-- neotest builds a spec from a libuv callback, where vim.fn.expand and
-- vim.fn.shellescape raise E5560.
local fast_results
local timer = vim.uv.new_timer()
timer:start(0, 0, function()
  fast_results = {
    argv = { pcall(argv_adapter.build_spec, { tree = tree_for(managed) }) },
    string = { pcall(string_adapter.build_spec, { tree = tree_for(managed) }) },
  }
  timer:close()
end)
vim.wait(1000, function()
  return fast_results ~= nil
end)
assert(fast_results, "the fast event callback never ran")
for kind, result in pairs(fast_results) do
  assert(result[1], ("%s build_spec failed in a fast event context: %s"):format(kind, tostring(result[2])))
end
assert(
  vim.deep_equal(fast_results.argv[2].command, { "direnv", "exec", fixture, "pytest", managed }),
  "argv not wrapped in direnv in a fast event context"
)

-- A debugger run has a DAP config and no command to wrap.
local dap_adapter = test_policy.direnv_adapter({
  build_spec = function()
    return { strategy = { type = "python" } }
  end,
})
assert(dap_adapter.build_spec({ tree = tree_for(managed) }).command == nil, "debug spec gained a command")

local outside = "/private/tmp/unrelated/test_a.py"
assert(
  vim.deep_equal(argv_adapter.build_spec({ tree = tree_for(outside) }).command, { "pytest", outside }),
  "unmanaged test run went through direnv"
)

print("Adapter regression checks passed")
