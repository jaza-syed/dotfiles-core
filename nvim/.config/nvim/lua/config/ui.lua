-- UI options plus lualine theme and statusline configuration.
local M = {}

local blend_hex = require("colors.util").blend_hex

local function abbreviate_mode(mode)
  local ok, window_move = pcall(require, "config.window_move")
  if ok and window_move.is_active() then
    return "MOVE"
  end

  local initials = {}
  for word in mode:gmatch("[%w]+") do
    table.insert(initials, word:sub(1, 1))
  end
  return #initials > 0 and table.concat(initials) or mode
end

local function current_encoding()
  return vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
end

local function lsp_clients_for_current_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = bufnr })
    or vim.lsp.get_active_clients({ bufnr = bufnr })

  if #clients == 0 then
    return ""
  end

  local seen = {}
  local names = {}
  for _, client in ipairs(clients) do
    if client.name and client.name ~= "" and not seen[client.name] then
      seen[client.name] = true
      table.insert(names, client.name)
    end
  end

  table.sort(names)
  return table.concat(names, ",")
end

local function modified_indicator()
  return "●"
end

local measuring_statusline_filepath = false
local statusline_filepath_ellipsis = "…"

local function stl_escape(text)
  return text:gsub("%%", "%%%%")
end

local function display_width(text)
  return vim.fn.strdisplaywidth(text)
end

local function suffix_with_max_width(text, max_width)
  if max_width <= 0 then
    return ""
  end
  if display_width(text) <= max_width then
    return text
  end

  local char_count = vim.fn.strchars(text)
  for start = 1, char_count - 1 do
    local suffix = vim.fn.strcharpart(text, start)
    if display_width(suffix) <= max_width then
      return suffix
    end
  end

  return ""
end

local function trim_path_from_top(path, max_width)
  if max_width <= 0 then
    return ""
  end
  if display_width(path) <= max_width then
    return path
  end

  local ellipsis_width = display_width(statusline_filepath_ellipsis)
  if max_width <= ellipsis_width then
    return statusline_filepath_ellipsis
  end

  local sep = package.config:sub(1, 1)
  local prefix = statusline_filepath_ellipsis .. sep
  local segments = vim.split(path, sep, { plain = true })
  while segments[1] == "" do
    table.remove(segments, 1)
  end

  for start = 2, #segments do
    local candidate = prefix .. table.concat(vim.list_slice(segments, start), sep)
    if display_width(candidate) <= max_width then
      return candidate
    end
  end

  local filename = segments[#segments] or path
  return statusline_filepath_ellipsis .. suffix_with_max_width(filename, max_width - ellipsis_width)
end

local function component_padding_width(component)
  local padding = component and component.options and component.options.padding
  if padding == nil then
    return 2
  end
  if type(padding) == "number" then
    return padding * 2
  end
  if type(padding) == "table" then
    return (padding.left or 0) + (padding.right or 0)
  end

  return 0
end

local function statusline_width(component)
  if component and component.options and component.options.globalstatus then
    return vim.go.columns
  end

  return vim.fn.winwidth(0)
end

local function statusline_content_width(statusline)
  local ok, result = pcall(vim.api.nvim_eval_statusline, statusline, {
    maxwidth = 0,
    winid = vim.api.nvim_get_current_win(),
  })

  if ok and result and result.width then
    return result.width
  end

  return 0
end

local function available_filepath_width(component, is_focused)
  local total_width = statusline_width(component)
  local padding_width = component_padding_width(component)

  measuring_statusline_filepath = true
  local ok, statusline = pcall(function()
    return require("lualine").statusline(is_focused)
  end)
  measuring_statusline_filepath = false

  if not ok or not statusline then
    return math.max(0, total_width - padding_width)
  end

  return math.max(0, total_width - statusline_content_width(statusline) - padding_width)
end

local function statusline_filepath(component, is_focused)
  if measuring_statusline_filepath then
    return ""
  end

  local path = vim.fn.expand("%:~:.")
  if path == "" then
    path = "[No Name]"
  end

  return stl_escape(trim_path_from_top(path, available_filepath_width(component, is_focused)))
end

local linear_branch_prefixes = {
  feature = true,
  bugfix = true,
  refactor = true,
  hotfix = true,
}

local function shorten_linear_branch(branch)
  if not branch or branch == "" then
    return branch
  end

  local category, ticket = branch:match("^([^/]+)/([%a]+%-%d+)%-.+$")
  if not category then
    category, ticket = branch:match("^([^/]+)/.+%-([%a]+%-%d+)$")
  end

  if category and linear_branch_prefixes[category] and ticket then
    return string.format("%s/%s…", category, ticket)
  end

  return branch
end

local managed_tab_title_prefixes = {
  "Diffview",
  "Neogit",
}

local function is_managed_tab_title(tabname)
  if type(tabname) ~= "string" then
    return false
  end

  for _, prefix in ipairs(managed_tab_title_prefixes) do
    if tabname == prefix or vim.startswith(tabname, prefix .. " - ") then
      return true
    end
  end

  return false
end

local function clear_managed_tab_titles()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, tabname = pcall(vim.api.nvim_tabpage_get_var, tabpage, "tabname")
    if ok and is_managed_tab_title(tabname) then
      pcall(vim.api.nvim_tabpage_del_var, tabpage, "tabname")
    end
  end
end

local function is_debug_tab(tabpage)
  local ok, value = pcall(vim.api.nvim_tabpage_get_var, tabpage, "dotfiles_dap_debug_tab")
  return ok and value == true
end

local function is_diffview_tab(tabpage)
  local diffview_lib = package.loaded["diffview.lib"]
  if not diffview_lib or type(diffview_lib.tabpage_to_view) ~= "function" then
    return false
  end

  local ok, view = pcall(diffview_lib.tabpage_to_view, tabpage)
  return ok and view ~= nil
end

local function tabpage_has_filetype(tabpage, filetype)
  if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
    return false
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if vim.bo[bufnr].filetype == filetype then
      return true
    end
  end

  return false
end

local function tabpage_cwd(tabpage)
  if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
    local ok_tabnr, tabnr = pcall(vim.api.nvim_tabpage_get_number, tabpage)
    if ok_tabnr then
      local ok_winnr, winnr = pcall(vim.fn.tabpagewinnr, tabnr)
      if ok_winnr and type(winnr) == "number" and winnr > 0 then
        local ok_cwd, cwd = pcall(vim.fn.getcwd, winnr, tabnr)
        if ok_cwd and cwd and cwd ~= "" then
          return cwd
        end
      end

      local ok_cwd, cwd = pcall(vim.fn.getcwd, -1, tabnr)
      if ok_cwd and cwd and cwd ~= "" then
        return cwd
      end
    end
  end

  return vim.fn.getcwd()
end

local function cwd_leaf_for_tabpage(tabpage)
  local cwd = tabpage_cwd(tabpage)
  local leaf = vim.fn.fnamemodify(cwd, ":t")
  return leaf ~= "" and leaf or cwd
end

local function git_ui_title(label, tabpage)
  local leaf = cwd_leaf_for_tabpage(tabpage)
  if not leaf or leaf == "" then
    return label
  end

  return stl_escape(string.format("%s - %s", label, leaf))
end

local function git_ui_tab_label(default_label, tab)
  local tabpage = tab and tab.tabId
  if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
    return default_label
  end

  if is_debug_tab(tabpage) then
    return "Debug"
  end

  local ok, review = pcall(require, "review")
  local review_label = ok and review.tab_label and review.tab_label(tabpage)
  if review_label then
    -- The emoji stands in for the plugin's "Review" prefix, which costs nine
    -- characters of a label that has to fit tab_max_length.
    return stl_escape((review_label:gsub("^Review %- ", "🔍 ")))
  end

  if is_diffview_tab(tabpage) then
    return git_ui_title("Diffview", tabpage)
  end

  if tabpage_has_filetype(tabpage, "NeogitStatus") then
    return git_ui_title("Neogit", tabpage)
  end

  return default_label
end

function M.setup()
  -- Status line setup
  -- Use a global statusline so horizontal splits get a real WinSeparator border
  -- instead of each window's statusline doubling as the separator.
  vim.opt.laststatus = 3
  vim.opt.fillchars:append({
    diff = "╱",
    horiz = "─",
    horizup = "┴",
    horizdown = "┬",
    vert = "│",
    vertleft = "┤",
    vertright = "├",
    verthoriz = "┼",
  })

  -- Backup built-in statusline: lualine owns the active statusline, but keep
  -- the old setup here as a fallback reference in case lualine is removed.
  -- vim.opt.statusline = ""
  -- vim.opt.statusline:append("%#CursorColumn#")
  -- vim.opt.statusline:append("%#LineNr#")
  -- vim.opt.statusline:append(" %f")          -- File path
  -- vim.opt.statusline:append("%#CursorColumn#")
  -- vim.opt.statusline:append("%=")           -- Right align
  -- vim.opt.statusline:append(" %y")          -- File type
  -- vim.opt.statusline:append(" %{&fileencoding?&fileencoding:&encoding}")
  -- vim.opt.statusline:append("[%{&fileformat}]")
  -- vim.opt.statusline:append(" %p%%")        -- Percentage
  -- vim.opt.statusline:append(" %l:%c")       -- Line:column
end

function M.apply_lualine_theme()
  local c = require("colors").active
  if not c then
    return
  end

  clear_managed_tab_titles()

  local is_light = vim.o.background == "light"
  local middle_bg = blend_hex(c.bg_cur or c.bg, c.bg, 0.2)
  local inactive_bg = middle_bg
  local tabline_bg = middle_bg
  local active_tab = {
    fg = is_light and c.blue or c.bg,
    bg = is_light and (c.bg_def or c.bg_cur or c.bg_float) or c.blue,
    gui = "bold",
  }
  local inactive_tab = {
    fg = c.dim,
    bg = tabline_bg,
    gui = "bold",
  }
  local custom_theme = {
    normal = {
      a = {
        fg = is_light and c.green or c.bg,
        bg = is_light and c.bg_string or c.fg,
        gui = "bold",
      },
      b = { fg = c.fg, bg = c.gray },
      c = { fg = c.dim, bg = middle_bg },
    },
    insert = {
      a = {
        fg = is_light and c.green or c.bg,
        bg = is_light and c.bg_string or c.green,
        gui = "bold",
      },
    },
    visual = {
      a = {
        fg = is_light and c.magenta or c.bg,
        bg = is_light and c.bg_const or c.magenta,
        gui = "bold",
      },
    },
    replace = {
      a = {
        fg = is_light and c.red or c.bg,
        bg = is_light and c.bg_comment or c.red,
        gui = "bold",
      },
    },
    command = {
      a = {
        fg = is_light and c.blue or c.bg,
        bg = is_light and c.bg_def or c.wood,
        gui = "bold",
      },
    },
    inactive = {
      a = { fg = c.dim, bg = inactive_bg },
      b = { fg = c.dim, bg = inactive_bg },
      c = { fg = c.gray, bg = inactive_bg },
    },
  }

  local lualine = require("lualine")
  local config = lualine.get_config()

  config.options = config.options or {}
  config.options.globalstatus = true
  config.options.always_show_tabline = false
  config.options.theme = custom_theme
  config.sections.lualine_a = {
    {
      "mode",
      fmt = abbreviate_mode,
    },
  }
  config.sections.lualine_b = {
    {
      "branch",
      fmt = shorten_linear_branch,
    },
    "diff",
    "diagnostics",
  }
  config.sections.lualine_c = {
    {
      function()
        return "hjkl reorder · HJKL change level · 1-9 tab · Esc exit"
      end,
      cond = function()
        local ok, window_move = pcall(require, "config.window_move")
        return ok and window_move.is_active()
      end,
      color = { fg = c.blue, gui = "bold" },
    },
    {
      statusline_filepath,
    },
  }
  config.sections.lualine_x = {
    {
      lsp_clients_for_current_buffer,
      icon = "",
      cond = function()
        return lsp_clients_for_current_buffer() ~= ""
      end,
      color = { fg = c.blue, gui = "bold" },
    },
    {
      "encoding",
      show_bomb = false,
      cond = function()
        local encoding = current_encoding():lower()
        return encoding ~= "utf-8" and encoding ~= "utf8"
      end,
    },
    {
      "fileformat",
      cond = function()
        return vim.bo.fileformat == "dos"
      end,
    },
    {
      "filetype",
      icon_only = true,
    },
  }
  config.sections.lualine_y = {
    {
      modified_indicator,
      cond = function()
        return vim.bo.modified
      end,
      color = { fg = c.wood, gui = "bold" },
    },
  }
  config.inactive_sections.lualine_c = {
    {
      statusline_filepath,
    },
  }
  config.tabline = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      {
        "tabs",
        mode = 2,
        path = 0,
        max_length = function()
          return vim.o.columns
        end,
        -- Wide enough for a review label's two compared revisions.
        tab_max_length = 48,
        fmt = git_ui_tab_label,
        show_modified_status = true,
        symbols = {
          modified = modified_indicator(),
        },
        tabs_color = {
          active = active_tab,
          inactive = inactive_tab,
        },
      },
    },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  }
  config.winbar = {}
  config.inactive_winbar = {}

  lualine.setup(config)
end

return M
