-- nvim-cmp configuration and completion enablement policy.
local M = {}

-- cmp sizes the menu from the widest entry in each column, and clamps it to the
-- screen edge when it does not fit, so a varying width moves the left edge.
-- Padding every column to a constant keeps the total width, and the position,
-- fixed.
local COLUMN_WIDTHS = { abbr = 24, kind = 9, menu = 20 }

local function fixed(text, width)
  text = (text or ""):gsub("%s+", " ")
  text = vim.fn.strcharpart(text, 0, width)
  while vim.fn.strdisplaywidth(text) > width do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
end

-- Every cmp float goes through this one method. Two corrections: cmp positions
-- against the screen, so in a vertical split its windows spill into the
-- neighbouring one; and the docs window is placed against the menu, which now
-- sits above the cursor.
-- Private-API adapter: cmp.utils.window has no public positioning hook. The
-- pristine open is kept on the module and the wrapper is rebuilt over it on
-- every setup, so reloads install current code without stacking wrappers.
local function place_cmp_floats()
  local window = require("cmp.utils.window")
  window._dotfiles_open = window._dotfiles_open or window.open

  local open = window._dotfiles_open
  window.open = function(self, style)
    if style and style.relative == "editor" and style.width and style.col then
      local pos = vim.api.nvim_win_get_position(0)
      local right = pos[2] + vim.api.nvim_win_get_width(0)
      style.width = math.max(1, math.min(style.width, right - pos[2] - 1))
      style.col = math.max(pos[2], math.min(style.col, right - style.width - 1))

      -- screenpos counts the winbar row, which winline() omits.
      local sp = vim.fn.screenpos(0, vim.fn.line("."), vim.fn.col("."))
      local cursor_row = (sp.row > 0 and sp.row or pos[1] + vim.fn.winline()) - 1
      local ft = vim.bo[self:get_buffer()].filetype

      if ft == "cmp_docs" then
        -- One row for the cursor line and one for the border above the text.
        local below = cursor_row + 2
        style.height = math.max(1, math.min(style.height, vim.o.lines - below - 2))
        style.row = below
      elseif ft == "cmp_menu" and style.row < cursor_row then
        -- cmp ends the menu on the cursor line when it opens above it.
        style.height = math.max(1, math.min(style.height, cursor_row))
        style.row = cursor_row - style.height
      end
    end
    return open(self, style)
  end
end

function M.setup()
  local cmp = require("cmp")
  local context = require("cmp.config.context")

  place_cmp_floats()

  cmp.setup({
    enabled = function()
      if vim.api.nvim_get_mode().mode == "c" then
        return true
      end

      local ft = vim.bo.filetype
      if ft == "markdown" or ft == "text" then
        return false
      end

      return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
    end,
    window = {
      completion = {
        max_height = 10,
      },
      documentation = {
        border = "rounded",
      },
    },
    sources = {
      { name = "nvim_lsp" },
    },
    -- The menu takes the space above the cursor line and signature help takes
    -- the space below, so the two never overlap.
    view = {
      -- near_cursor reverses the list when the menu is above, putting the best
      -- match at the bottom, one <C-k> away.
      entries = { vertical_positioning = "above", selection_order = "near_cursor" },
    },
    formatting = {
      format = function(_, item)
        item.abbr = fixed(item.abbr, COLUMN_WIDTHS.abbr)
        item.kind = fixed(item.kind, COLUMN_WIDTHS.kind)
        item.menu = fixed(item.menu, COLUMN_WIDTHS.menu)
        return item
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      -- With near_cursor and the menu above, cmp counts "next" from the entry
      -- nearest the cursor, which is the bottom one, so the names are inverted
      -- against the direction on screen.
      ["<C-k>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
      ["<C-j>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<CR>"] = cmp.mapping(function(fallback)
        -- Only confirm a suggestion the user actively selected. Otherwise
        -- dismiss the menu and let Enter insert its normal newline.
        if cmp.get_active_entry() then
          cmp.confirm({ select = false })
        else
          cmp.close()
          fallback()
        end
      end, { "i", "s" }),
    }),
  })
end

return M
