-- Keep mini.bracketed's traversal while opening review entries through Diffview.
local M = {}

function M.setup()
  local ok, bracketed = pcall(require, "mini.bracketed")
  if not ok then
    return
  end
  bracketed._dotfiles_quickfix = bracketed._dotfiles_quickfix or bracketed.quickfix
  local original = bracketed._dotfiles_quickfix

  bracketed.quickfix = function(direction, opts)
    local review = package.loaded.review
    if not review or vim.g.minibracketed_disable == true or vim.b.minibracketed_disable == true then
      return original(direction, opts)
    end
    if not vim.tbl_contains({ "first", "backward", "forward", "last" }, direction) then
      return original(direction, opts)
    end
    local list = vim.fn.getqflist({ items = 0, idx = 0 })
    local size = #list.items
    if size == 0 then
      return original(direction, opts)
    end
    local config = vim.tbl_deep_extend("force", bracketed.config, vim.b.minibracketed_config or {})
    local options =
      vim.tbl_deep_extend("force", { n_times = vim.v.count1, wrap = true }, config.quickfix.options, opts or {})
    local index = bracketed.advance({
      state = list.idx,
      start_edge = 0,
      end_edge = size + 1,
      next = function(i)
        if i and i < size then
          return i + 1
        end
      end,
      prev = function(i)
        if i and i > 1 then
          return i - 1
        end
      end,
    }, direction, options)
    local item = list.items[index]
    local data = item and type(item.user_data) == "table" and item.user_data or {}
    local handled = item
      and item.module == "review.nvim"
      and review.jump_quickfix_thread
      and review.jump_quickfix_thread(data.session_id, data.thread_id)
    if not handled and item and review.jump_quickfix_location then
      handled = review.jump_quickfix_location(item)
    end
    if handled then
      vim.fn.setqflist({}, "a", { idx = index })
      return
    end
    return original(direction, opts)
  end
end

return M
