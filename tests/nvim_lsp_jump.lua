-- Run: nvim --headless -u NONE -i NONE -l tests/nvim_lsp_jump.lua
-- Picking a window for an LSP jump: a label opens there, hjkl before the label
-- splits the labelled window first, and anything else cancels.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")

-- Stands in for nvim-window-picker, which reads one key and returns nil for a
-- key that labels no window.
local labels = {}
package.preload["window-picker"] = function()
  return {
    pick_window = function()
      return labels[vim.fn.getcharstr()]
    end,
  }
end

local keymaps = require("config.keymaps")

local function press(keys)
  vim.api.nvim_feedkeys(keys, "t", false)
end

vim.cmd("vsplit")
vim.cmd("split")
local wins = vim.api.nvim_tabpage_list_wins(0)
assert(#wins == 3, "fixture needs three windows")
labels = { A = wins[1], B = wins[2], C = wins[3] }
local width, height = vim.api.nvim_win_get_width(wins[3]), vim.api.nvim_win_get_height(wins[3])

press("B")
assert(keymaps.pick_window_or_split() == wins[2], "a label did not return its window")

press("\27")
assert(keymaps.pick_window_or_split() == nil, "escape did not cancel")

press("q")
assert(keymaps.pick_window_or_split() == nil, "an unknown key did not cancel")

press("l\27")
assert(keymaps.pick_window_or_split() == nil, "escape after a split key did not cancel")
assert(#vim.api.nvim_tabpage_list_wins(0) == 3, "a cancelled pick still split a window")

press("lC")
local right = keymaps.pick_window_or_split()
assert(right and right ~= wins[3], "l did not open a new window")
assert(vim.api.nvim_win_get_position(right)[2] > vim.api.nvim_win_get_position(wins[3])[2], "l split to the left")
assert(vim.api.nvim_win_get_height(right) == height, "l split horizontally")
assert(vim.api.nvim_win_get_width(wins[3]) < width, "the picked window kept its width")
vim.api.nvim_win_close(right, true)

press("kC")
local above = keymaps.pick_window_or_split()
assert(above and above ~= wins[3], "k did not open a new window")
assert(vim.api.nvim_win_get_position(above)[1] < vim.api.nvim_win_get_position(wins[3])[1], "k split below")
vim.api.nvim_win_close(above, true)

press("jC")
local below = keymaps.pick_window_or_split()
assert(below and vim.api.nvim_win_get_position(below)[1] > vim.api.nvim_win_get_position(wins[3])[1], "j split above")
vim.api.nvim_win_close(below, true)

press("hC")
local left = keymaps.pick_window_or_split()
assert(
  left and vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(wins[3])[2],
  "h split to the right"
)

print("LSP jump window picker checks passed")
