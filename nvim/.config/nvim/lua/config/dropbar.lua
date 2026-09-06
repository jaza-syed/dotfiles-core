-- Dropbar breadcrumbs: project-context source, path abbreviations, and menu
-- navigation. Configured once from the plugin spec and restart-only: dropbar
-- wires its sources at setup, so this module is not in the reload registry.
-- Path policy re-requires config.projects and config.machine at call time,
-- so it still follows a reload.
local M = {}

local function current_dropbar_menu()
  return require("dropbar.utils").menu.get_current()
end

local function expand_dropbar_menu_entry()
  local menu = current_dropbar_menu()
  if not menu or not menu.win or not vim.api.nvim_win_is_valid(menu.win) then
    return
  end

  local row = vim.api.nvim_win_get_cursor(menu.win)[1]
  local entry = menu.entries and menu.entries[row]
  local expander = entry and entry.components and entry.components[1]
  if expander and expander.on_click then
    menu:click_on(expander, nil, 1, "l")
  end
end

local function close_dropbar_menu_level()
  local menu = current_dropbar_menu()
  if menu and menu.prev_menu then
    menu:close(false)
  end
end

local function path_is_uri(path)
  return type(path) == "string" and path:match("^%a[%w+.-]*://") ~= nil
end

local function shorten_nix_store_hashes(path)
  if not path or path == "" then
    return path
  end

  return (
    path:gsub("(/nix/store/)([0-9a-z]+)-", function(prefix, hash)
      if #hash > 12 then
        return prefix .. hash:sub(1, 6) .. "…-"
      end
      return prefix .. hash .. "-"
    end)
  )
end

local function display_absolute_path(path)
  return shorten_nix_store_hashes(vim.fn.fnamemodify(path, ":~"))
end

local function cwd_for_win(win)
  local projects = require("config.projects")
  if win and vim.api.nvim_win_is_valid(win) then
    local ok, cwd = pcall(vim.api.nvim_win_call, win, function()
      return vim.fn.getcwd(0, 0)
    end)
    if ok and cwd and cwd ~= "" then
      return projects.normalize(cwd)
    end
  end

  return projects.normalize(vim.fn.getcwd())
end

local function project_title_for_cwd(cwd)
  local title = require("config.machine").project_title(cwd)
  if title then
    return shorten_nix_store_hashes(title)
  end

  return display_absolute_path(cwd)
end

local function abbreviate_nix_store_path_symbols(symbols)
  for _, symbol in ipairs(symbols) do
    if symbol.name then
      symbol.name = symbol.name:gsub("^([0-9a-z]+)-", function(hash)
        if #hash > 12 then
          return hash:sub(1, 6) .. "…-"
        end
        return hash .. "-"
      end)
    end
  end

  return symbols
end

local function path_source_with_abbreviations()
  local path_source = require("dropbar.sources").path
  return {
    get_symbols = function(buf, win, cursor)
      local symbols = abbreviate_nix_store_path_symbols(path_source.get_symbols(buf, win, cursor))
      return require("config.machine").abbrev_path_symbols(buf, symbols)
    end,
  }
end

local function project_context_source()
  local symbol = require("dropbar.bar").dropbar_symbol_t
  return {
    get_symbols = function(buf, win, _)
      local cwd = cwd_for_win(win)
      return {
        symbol:new({
          icon = project_title_for_cwd(cwd),
          icon_hl = "DotfilesWinbarProjectTitle",
          name = "",
          name_hl = "DotfilesWinbarProjectPath",
          on_click = false,
        }),
      }
    end,
  }
end

local function dropbar_enabled(buf, win, _)
  buf = vim._resolve_bufnr(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  if vim.fn.win_gettype(win) ~= "" or vim.wo[win].winbar ~= "" or vim.bo[buf].filetype == "help" then
    return false
  end

  local buftype = vim.bo[buf].buftype
  if buftype ~= "" and buftype ~= "terminal" then
    return false
  end

  local bufname = vim.api.nvim_buf_get_name(buf)
  local stat = bufname ~= "" and not path_is_uri(bufname) and vim.uv.fs_stat(bufname) or nil
  if stat and stat.size > 1024 * 1024 then
    return false
  end

  return true
end

local function configured_sources(buf, _)
  local sources = require("dropbar.sources")
  local utils = require("dropbar.utils")
  local context_source = project_context_source()
  local path_source = path_source_with_abbreviations()

  if vim.bo[buf].filetype == "markdown" then
    return {
      context_source,
      path_source,
      sources.markdown,
    }
  end

  if vim.bo[buf].buftype == "terminal" then
    return {
      context_source,
      sources.terminal,
    }
  end

  return {
    context_source,
    path_source,
    utils.source.fallback({
      sources.lsp,
      sources.treesitter,
    }),
  }
end

function M.setup()
  require("dropbar").setup({
    icons = {
      kinds = {
        dir_icon = function(_)
          return ""
        end,
      },
    },
    bar = {
      enable = dropbar_enabled,
      sources = configured_sources,
      -- Keep the project/file prefix stable; let crowded breadcrumbs clip
      -- at the right edge instead of truncating the identifying context.
      truncate = false,
    },
    menu = {
      -- Don't move/replace the source window while browsing a dropbar menu.
      -- Only jump/open the selected entry when pressing <CR> or clicking it.
      preview = false,
      keymaps = {
        h = close_dropbar_menu_level,
        l = expand_dropbar_menu_entry,
        ["<Left>"] = close_dropbar_menu_level,
        ["<Right>"] = expand_dropbar_menu_entry,
      },
    },
  })
end

return M
