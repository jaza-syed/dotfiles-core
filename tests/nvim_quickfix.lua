-- Run from dotfiles with MINI_BRACKETED_ROOT pointing to a mini.bracketed checkout:
-- nvim --headless -u NONE -i NONE -l tests/nvim_quickfix.lua
vim.opt.rtp:prepend(assert(vim.env.MINI_BRACKETED_ROOT, "Set MINI_BRACKETED_ROOT"))
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")
vim.opt.shortmess:append("F")
local mini = require("mini.bracketed")
mini.setup({})
local original = mini.quickfix
local adapter = require("config.quickfix")
adapter.setup()
package.loaded["config.quickfix"] = nil
require("config.quickfix").setup()
assert(mini._dotfiles_quickfix == original, "reload stacked wrappers")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)
local items = {}
for i = 1, 4 do
  local path = root .. "/" .. i .. ".txt"
  vim.fn.writefile({ "one", "two" }, path)
  items[i] = { filename = path, lnum = 2, col = 1, text = tostring(i) }
end
local routed
package.loaded.review = {
  jump_quickfix_location = function(item)
    routed = tonumber(item.text)
    return true
  end,
}
local cases = 0
for _, direction in ipairs({ "first", "last", "forward", "backward" }) do
  for _, count in ipairs({ 1, 2, 7 }) do
    for _, wrap in ipairs({ true, false }) do
      for start = 1, 4 do
        vim.fn.setqflist({}, " ", { items = items, idx = start })
        original(direction, { n_times = count, wrap = wrap })
        local expected = vim.fn.getqflist({ idx = 0 }).idx
        vim.fn.setqflist({}, "a", { idx = start })
        routed = nil
        mini.quickfix(direction, { n_times = count, wrap = wrap })
        assert(routed == expected, direction .. " traversal differs")
        assert(vim.fn.getqflist({ idx = 0 }).idx == expected)
        cases = cases + 1
      end
    end
  end
end
vim.fn.setqflist({}, "a", { idx = 1 })
vim.b.minibracketed_config = { quickfix = { options = { n_times = 2, wrap = false } } }
mini.quickfix("forward")
assert(routed == 3, "buffer options ignored")
vim.b.minibracketed_config = nil
vim.g.minibracketed_disable = true
routed = nil
mini.quickfix("forward")
assert(routed == nil and vim.fn.getqflist({ idx = 0 }).idx == 3)
vim.g.minibracketed_disable = nil
package.loaded.review.jump_quickfix_location = function()
  return false
end
mini.quickfix("first")
assert(vim.api.nvim_buf_get_name(0) == root .. "/1.txt", "native fallback failed")
local thread_calls = 0
package.loaded.review.jump_quickfix_thread = function(session, thread)
  assert(session == "s" and thread == "t")
  thread_calls = thread_calls + 1
  return true
end
items[2].module = "review.nvim"
items[2].user_data = { session_id = "s", thread_id = "t" }
vim.fn.setqflist({}, " ", { items = items, idx = 1 })
mini.quickfix("forward")
assert(thread_calls == 1 and vim.fn.getqflist({ idx = 0 }).idx == 2)
vim.fn.delete(root, "rf")
print(cases .. " traversal cases passed; reload, options, disable, thread routing, and native fallback passed")
