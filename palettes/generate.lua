#!/usr/bin/env luajit
-- Colorscheme generator: reads palette files from palettes/ and generates
-- config files for nvim, wezterm, tmux, shell fzf, AeroSpace, pi, and Typora.
--
-- Usage: luajit palettes/generate.lua
-- Or:    lua palettes/generate.lua
-- Or:    ./scripts/generate_colorscheme.sh

local script_dir = arg[0]:match("(.*/)")
local repo_root = script_dir .. "../"

-- Find all palette files (*.lua excluding this script)
local function find_palettes()
  local palettes = {}
  local handle = io.popen('ls "' .. script_dir .. '"*.lua 2>/dev/null')
  if not handle then return palettes end
  for path in handle:lines() do
    local name = path:match("([^/]+)%.lua$")
    if name ~= "generate" then
      table.insert(palettes, name)
    end
  end
  handle:close()
  return palettes
end

-- Load a palette file by name
local function load_palette(name)
  local path = script_dir .. name .. ".lua"
  local fn = loadfile(path)
  if not fn then
    error("Failed to load palette: " .. path)
  end
  return fn()
end

local function is_valid_hex(value)
  return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function hex_to_rgb(hex)
  if type(hex) ~= "string" then
    return nil
  end

  local clean = hex:gsub("#", "")
  if #clean ~= 6 then
    return nil
  end

  return tonumber(clean:sub(1, 2), 16),
         tonumber(clean:sub(3, 4), 16),
         tonumber(clean:sub(5, 6), 16)
end

local function srgb_channel_to_linear(channel)
  local c = channel / 255
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

local function is_light_palette(c)
  local r, g, b = hex_to_rgb(c and c.bg)
  if not r then
    return false
  end

  local luminance =
    0.2126 * srgb_channel_to_linear(r) +
    0.7152 * srgb_channel_to_linear(g) +
    0.0722 * srgb_channel_to_linear(b)

  return luminance > 0.5
end

local function pick(value, fallback)
  if value ~= nil then
    return value
  end
  return fallback
end

local function json_escape(str)
  return (str
    :gsub('\\', '\\\\')
    :gsub('"', '\\"')
    :gsub('\b', '\\b')
    :gsub('\f', '\\f')
    :gsub('\n', '\\n')
    :gsub('\r', '\\r')
    :gsub('\t', '\\t'))
end

local function is_array(tbl)
  local max = 0
  local count = 0
  for k in pairs(tbl) do
    if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
      return false
    end
    if k > max then
      max = k
    end
    count = count + 1
  end
  return max == count
end

local function json_encode(value, indent)
  indent = indent or ""
  local next_indent = indent .. "  "
  local t = type(value)

  if t == "nil" then
    return "null"
  elseif t == "string" then
    return '"' .. json_escape(value) .. '"'
  elseif t == "number" or t == "boolean" then
    return tostring(value)
  elseif t == "table" then
    if next(value) == nil then
      return "{}"
    end

    if is_array(value) then
      local parts = {}
      for i = 1, #value do
        table.insert(parts, next_indent .. json_encode(value[i], next_indent))
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
    end

    local keys = {}
    for k in pairs(value) do
      table.insert(keys, k)
    end
    table.sort(keys)

    local parts = {}
    for _, k in ipairs(keys) do
      table.insert(parts, string.format('%s"%s": %s', next_indent, json_escape(k), json_encode(value[k], next_indent)))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end

  error("Unsupported JSON value type: " .. t)
end

-- Write a file, creating parent directories as needed
local function write_file(path, content)
  -- Ensure parent directory exists
  local dir = path:match("(.*/)")
  if dir then
    os.execute('mkdir -p "' .. dir .. '"')
  end
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
  print("  wrote " .. path)
end

local REQUIRED_KEYS = {
  "bg", "fg", "bg_cur", "bg_float", "bg_vis",
  "comment", "red", "green", "blue", "teal", "wood", "magenta", "gray", "dim",
  "bright_magenta",
}

-- Light palettes need the tint keys: the tmux and typora emitters use them
-- without fallback.
local LIGHT_ONLY_KEYS = { "bg_string", "bg_comment", "bg_const", "bg_def" }

local function validate_palette(name, c, errors)
  local function fail(msg)
    table.insert(errors, name .. ": " .. msg)
  end

  if c.name ~= name then
    fail(string.format("name %q does not match the filename", tostring(c.name)))
  end

  for _, key in ipairs(REQUIRED_KEYS) do
    if c[key] == nil then
      fail("missing required key " .. key)
    end
  end

  if is_light_palette(c) then
    for _, key in ipairs(LIGHT_ONLY_KEYS) do
      if c[key] == nil then
        fail("light palette missing key " .. key)
      end
    end
  end

  for k, v in pairs(c) do
    if k ~= "name" and not is_valid_hex(v) then
      fail(string.format("key %s is not a #rrggbb hex: %s", k, tostring(v)))
    end
  end
end

-- Generate nvim palette copy (lua/colors/<name>.lua)
local function gen_nvim_palette(name, palette)
  local lines = {
    "-- GENERATED by palettes/generate.lua -- DO NOT EDIT",
    "return {",
  }
  -- Sort keys for deterministic output
  local keys = {}
  for k in pairs(palette) do
    table.insert(keys, k)
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = palette[k]
    if type(v) == "string" then
      table.insert(lines, string.format('  %s = "%s",', k, v))
    end
  end
  table.insert(lines, "}")
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

-- Generate nvim colorscheme entry point (colors/colors_<name>.lua)
local function gen_nvim_entry(name)
  return string.format(
    '-- GENERATED by palettes/generate.lua -- DO NOT EDIT\nrequire("colors").apply("%s")\n',
    name
  )
end

-- Generate the nvim background registry (lua/colors/registry.lua)
local function gen_nvim_registry(bg_owner)
  local hexes = {}
  for hex in pairs(bg_owner) do
    table.insert(hexes, hex)
  end
  table.sort(hexes)

  local lines = {
    "-- GENERATED by palettes/generate.lua -- DO NOT EDIT",
    "-- bg hex (lowercase, no #) -> palette name, for the OSC 11 fallback path.",
    "return {",
  }
  for _, hex in ipairs(hexes) do
    table.insert(lines, string.format('  ["%s"] = "%s",', hex, bg_owner[hex]))
  end
  table.insert(lines, "}")
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

local function gen_wezterm_tab_bar(name, c)
  if is_light_palette(c) then
    return {
      background = c.bg_float,
      active_tab = {
        bg_color = c.bg,
        fg_color = c.fg,
      },
      inactive_tab = {
        bg_color = c.bg_cur,
        fg_color = c.dim,
      },
      inactive_tab_hover = {
        bg_color = c.bg,
        fg_color = c.fg,
      },
      new_tab = {
        bg_color = c.bg_cur,
        fg_color = c.fg,
      },
      new_tab_hover = {
        bg_color = c.bg,
        fg_color = c.fg,
      },
      inactive_tab_edge = c.gray,
    }
  end

  return {
    background = c.bg,
    active_tab = {
      bg_color = c.bg_cur,
      fg_color = c.fg,
    },
    inactive_tab = {
      bg_color = c.bg_float,
      fg_color = c.dim,
    },
    inactive_tab_hover = {
      bg_color = c.bg_vis,
      fg_color = c.fg,
    },
    new_tab = {
      bg_color = c.bg_float,
      fg_color = c.fg,
    },
    new_tab_hover = {
      bg_color = c.bg_vis,
      fg_color = c.fg,
    },
    inactive_tab_edge = c.gray,
  }
end

local function gen_wezterm_window_frame(name, c)
  local light = is_light_palette(c)
  local strip_bg = light and c.bg_float or c.bg
  local border = light and c.gray or c.bg_cur
  local button_hover_bg = light and c.bg_cur or c.bg_float

  return {
    active_titlebar_bg = strip_bg,
    inactive_titlebar_bg = strip_bg,
    active_titlebar_fg = c.fg,
    inactive_titlebar_fg = c.dim,
    active_titlebar_border_bottom = border,
    inactive_titlebar_border_bottom = border,
    button_fg = c.dim,
    button_bg = strip_bg,
    button_hover_fg = c.fg,
    button_hover_bg = button_hover_bg,
  }
end

local function append_lua_table(lines, indent, tbl)
  local keys = {}
  for k in pairs(tbl) do
    table.insert(keys, k)
  end
  table.sort(keys)

  for _, k in ipairs(keys) do
    local v = tbl[k]
    if type(v) == "table" then
      table.insert(lines, string.format("%s%s = {", indent, k))
      append_lua_table(lines, indent .. "  ", v)
      table.insert(lines, indent .. "},")
    elseif type(v) == "string" then
      table.insert(lines, string.format('%s%s = "%s",', indent, k, v))
    elseif type(v) == "number" then
      table.insert(lines, string.format("%s%s = %s,", indent, k, v))
    elseif type(v) == "boolean" then
      table.insert(lines, string.format("%s%s = %s,", indent, k, tostring(v)))
    end
  end
end

-- Generate wezterm color config (colors_<name>.lua)
local function gen_wezterm(name, c)
  local lines = {
    "-- GENERATED by palettes/generate.lua -- DO NOT EDIT",
    "return {",
    "  colors = {",
    string.format('    background = "%s",', c.bg),
    string.format('    foreground = "%s",', c.fg),
    string.format('    cursor_bg = "%s",', c.fg),
    string.format('    cursor_fg = "%s",', c.bg),
    string.format('    selection_bg = "%s",', c.bg_vis),
    string.format('    selection_fg = "%s",', c.fg),
    "    ansi = {",
    string.format('      "%s", "%s", "%s", "%s",', c.bg, c.red, c.green, c.wood),
    string.format('      "%s", "%s", "%s", "%s",', c.blue, c.magenta, c.teal, c.fg),
    "    },",
    "    brights = {",
    string.format(
      '      "%s", "%s", "%s", "%s",',
      c.gray,
      c.bright_red or c.red,
      c.bright_green or c.green,
      c.bright_yellow or c.wood
    ),
    string.format(
      '      "%s", "%s", "%s", "%s",',
      c.bright_blue or c.blue,
      c.bright_magenta or c.magenta,
      c.bright_cyan or c.teal,
      c.dim
    ),
    "    },",
    "    tab_bar = {",
  }
  append_lua_table(lines, "      ", gen_wezterm_tab_bar(name, c))
  table.insert(lines, "    },")
  table.insert(lines, "  },")
  table.insert(lines, "  window_frame = {")
  append_lua_table(lines, "    ", gen_wezterm_window_frame(name, c))
  table.insert(lines, "  },")
  table.insert(lines, "}")
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

-- Generate tmux color config (colors-<name>.conf)
local function gen_tmux(name, c)
  local light = is_light_palette(c)
  local pane_border_fg = pick(c.pane_border_fg, c.gray)
  local pane_active_border_fg = pick(c.pane_active_border_fg, light and "#000000" or "#ffffff")
  local pane_label_active_fg = pick(c.pane_label_active_fg, light and c.blue or (c.bright_blue or c.blue))
  local pane_label_inactive_fg = pick(c.pane_label_inactive_fg, c.dim)
  local lines = {
    "# GENERATED by palettes/generate.lua -- DO NOT EDIT",
    "",
    "# Custom statusline tokens",
    string.format("set -g @statusline-bg-main '%s'", c.bg),
    string.format("set -g @statusline-bg-alt '%s'", light and c.bg_float or c.bg_vis),
    string.format("set -g @statusline-fg-main '%s'", c.fg),
    string.format("set -g @statusline-fg-muted '%s'", c.dim),
    string.format("set -g @pane-label-active-fg '%s'", pane_label_active_fg),
    string.format("set -g @pane-label-inactive-fg '%s'", pane_label_inactive_fg),
    string.format("set -g @statusline-window-inactive-bg '%s'", light and c.bg_float or c.bg_cur),
    string.format("set -g @statusline-window-inactive-fg '%s'", light and c.dim or c.fg),
  }

  if light then
    local light_lines = {
      string.format("set -g @statusline-prefix-bg '%s'", c.red),
      string.format("set -g @statusline-prefix-fg '%s'", c.bg),
      string.format("set -g @statusline-session-bg '%s'", c.bg_string),
      string.format("set -g @statusline-session-fg '%s'", c.green),
      string.format("set -g @statusline-visual-bg '%s'", c.bg_comment),
      string.format("set -g @statusline-visual-fg '%s'", c.wood),
      string.format("set -g @statusline-cpu-bg '%s'", c.bg_string),
      string.format("set -g @statusline-cpu-fg '%s'", c.green),
      string.format("set -g @statusline-ram-bg '%s'", c.bg_comment),
      string.format("set -g @statusline-ram-fg '%s'", c.wood),
      string.format("set -g @statusline-battery-bg '%s'", c.bg_const),
      string.format("set -g @statusline-battery-fg '%s'", c.magenta),
      string.format("set -g @statusline-network-bg '%s'", c.bg_def),
      string.format("set -g @statusline-network-fg '%s'", c.blue),
      string.format("set -g @statusline-time-bg '%s'", c.bg_def),
      string.format("set -g @statusline-time-fg '%s'", c.blue),
      string.format("set -g @statusline-window-active-bg '%s'", c.bg_def),
      string.format("set -g @statusline-window-active-fg '%s'", c.blue),
      string.format("set -g @statusline-window-flag-fg '%s'", c.red),
    }
    for _, line in ipairs(light_lines) do
      table.insert(lines, line)
    end
  else
    local dark_lines = {
      string.format("set -g @statusline-prefix-bg '%s'", c.red),
      string.format("set -g @statusline-prefix-fg '%s'", c.bg),
      string.format("set -g @statusline-session-bg '%s'", c.green),
      string.format("set -g @statusline-session-fg '%s'", c.bg),
      string.format("set -g @statusline-visual-bg '%s'", c.wood),
      string.format("set -g @statusline-visual-fg '%s'", c.bg),
      string.format("set -g @statusline-cpu-bg '%s'", c.green),
      string.format("set -g @statusline-cpu-fg '%s'", c.bg),
      string.format("set -g @statusline-ram-bg '%s'", c.wood),
      string.format("set -g @statusline-ram-fg '%s'", c.bg),
      string.format("set -g @statusline-battery-bg '%s'", c.magenta),
      string.format("set -g @statusline-battery-fg '%s'", c.bg),
      string.format("set -g @statusline-network-bg '%s'", c.blue),
      string.format("set -g @statusline-network-fg '%s'", c.bg),
      string.format("set -g @statusline-time-bg '%s'", c.teal),
      string.format("set -g @statusline-time-fg '%s'", c.bg),
      string.format("set -g @statusline-window-active-bg '%s'", c.blue),
      string.format("set -g @statusline-window-active-fg '%s'", c.bg),
      string.format("set -g @statusline-window-flag-fg '%s'", c.red),
    }
    for _, line in ipairs(dark_lines) do
      table.insert(lines, line)
    end
  end

  local copy_mode_position_style = light
    and string.format("bg=%s,fg=%s", c.bg_comment, c.wood)
    or "#{E:mode-style}"

  local tail_lines = {
    "",
    "# Copy mode",
    string.format('set -g copy-mode-position-style "%s"', copy_mode_position_style),
    "",
    "# Pane colors, borders, and status",
    string.format('set -g window-style "bg=%s,fg=%s"', c.bg, c.fg),
    string.format('set -g window-active-style "bg=%s,fg=%s"', c.bg, c.fg),
    string.format('set -g pane-border-style "fg=%s"', pane_border_fg),
    string.format('set -g pane-active-border-style "fg=%s"', pane_active_border_fg),
    string.format('set-option -g status-style "bg=%s,fg=%s"', c.bg, c.fg),
    "",
  }
  for _, line in ipairs(tail_lines) do
    table.insert(lines, line)
  end

  return table.concat(lines, "\n")
end

-- Generate shell fzf theme file (fzf-theme-<name>.sh)
local function gen_fzf(name, c)
  local base = is_light_palette(c) and "light" or "dark"
  local color_specs = {
    base,
    "fg:" .. c.fg,
    "bg:" .. c.bg,
    "list-fg:" .. c.fg,
    "list-bg:" .. c.bg,
    "preview-fg:" .. c.fg,
    "preview-bg:" .. c.bg_float,
    "input-bg:" .. c.bg,
    "hl:" .. c.comment,
    "current-fg:" .. c.fg,
    "current-bg:" .. c.bg_cur,
    "current-hl:" .. c.blue,
    "selected-fg:" .. c.fg,
    "selected-bg:" .. c.bg_cur,
    "selected-hl:" .. c.blue,
    "gutter:" .. c.bg,
    "info:" .. c.dim,
    "border:" .. c.gray,
    "separator:" .. c.gray,
    "scrollbar:" .. c.gray,
    "preview-scrollbar:" .. c.gray,
    "prompt:" .. c.blue,
    "pointer:" .. c.blue,
    "marker:" .. c.magenta,
    "spinner:" .. c.teal,
    "header:" .. c.comment,
    "query:" .. c.fg,
    "disabled:" .. c.dim,
    "ghost:" .. c.dim,
  }
  local fzf_opts = "--color=" .. table.concat(color_specs, ",")

  local lines = {
    "# GENERATED by palettes/generate.lua -- DO NOT EDIT",
    string.format("# fzf theme: %s", name),
    string.format("export FZF_DEFAULT_OPTS=%q", fzf_opts),
    string.format("export FZF_THEME_NAME=%q", name),
    "",
  }

  return table.concat(lines, "\n")
end

-- Generate AeroSpace/JankyBorders mode colors (mode-borders-<name>.sh)
local function gen_aerospace_mode_borders(name, c)
  local function argb(hex)
    return "0xff" .. hex:gsub("#", "")
  end

  local lines = {
    "# GENERATED by palettes/generate.lua -- DO NOT EDIT",
    "# AeroSpace/JankyBorders mode colors: " .. name,
    "BORDERS_MAIN_ACTIVE_COLOR=" .. argb(c.blue),
    "BORDERS_INACTIVE_COLOR=0x00000000",
    "BORDERS_SELECT_ACTIVE_COLOR=" .. argb(c.bright_magenta),
    "BORDERS_MOVE_ACTIVE_COLOR=" .. argb(c.red),
    "BORDERS_MAIN_WIDTH=6.0",
    "BORDERS_SELECT_WIDTH=8.0",
    "BORDERS_MOVE_WIDTH=8.0",
    "BORDERS_STYLE=round",
    "BORDERS_AX_FOCUS=on",
    "BORDERS_HIDPI=on",
    "",
  }
  return table.concat(lines, "\n")
end

-- Generate pi theme file (<name>.json)
local function gen_pi(name, c)
  local light = is_light_palette(c)
  local vars = {
    accent = pick(c.teal, c.blue),
    blue = c.blue,
    green = c.green,
    red = c.red,
    yellow = pick(c.wood, c.comment),
    magenta = c.magenta,
    cyan = pick(c.teal, c.blue),
    gray = pick(c.comment, c.gray),
    dimGray = c.dim,
    borderMuted = c.gray,
    selectedBg = pick(c.bg_vis, c.bg_cur),
    userMsgBg = pick(c.bg_cur, c.bg_float),
    customMsgBg = pick(c.bg_def, pick(c.bg_const, c.bg_float)),
    toolPendingBg = pick(c.bg_float, c.bg_cur),
    toolSuccessBg = pick(c.bg_string, pick(c.bg_float, c.bg_cur)),
    toolErrorBg = pick(c.bg_comment, pick(c.bg_float, c.bg_cur)),
    codeBlockBorder = pick(c.gray, c.dim),
    quote = pick(c.comment, c.dim),
    syntaxComment = pick(c.comment, c.dim),
  }

  local colors = {
    accent = "accent",
    border = "blue",
    borderAccent = "cyan",
    borderMuted = "borderMuted",
    success = "green",
    error = "red",
    warning = "yellow",
    muted = "gray",
    dim = "dimGray",
    text = "",
    thinkingText = "gray",

    selectedBg = "selectedBg",
    userMessageBg = "userMsgBg",
    userMessageText = "",
    customMessageBg = "customMsgBg",
    customMessageText = "",
    customMessageLabel = "magenta",
    toolPendingBg = "toolPendingBg",
    toolSuccessBg = "toolSuccessBg",
    toolErrorBg = "toolErrorBg",
    toolTitle = "",
    toolOutput = "gray",

    mdHeading = "yellow",
    mdLink = "blue",
    mdLinkUrl = "dimGray",
    mdCode = "accent",
    mdCodeBlock = "green",
    mdCodeBlockBorder = "codeBlockBorder",
    mdQuote = "quote",
    mdQuoteBorder = "quote",
    mdHr = "codeBlockBorder",
    mdListBullet = light and "green" or "accent",

    toolDiffAdded = "green",
    toolDiffRemoved = "red",
    toolDiffContext = "gray",

    syntaxComment = "syntaxComment",
    syntaxKeyword = "blue",
    syntaxFunction = "yellow",
    syntaxVariable = "cyan",
    syntaxString = "green",
    syntaxNumber = "magenta",
    syntaxType = "blue",
    syntaxOperator = "",
    syntaxPunctuation = "gray",

    thinkingOff = "borderMuted",
    thinkingMinimal = "dimGray",
    thinkingLow = "blue",
    thinkingMedium = "accent",
    thinkingHigh = "magenta",
    thinkingXhigh = "red",

    bashMode = "green",
  }

  local export = {
    pageBg = c.bg,
    cardBg = pick(c.bg_float, c.bg_cur),
    infoBg = pick(c.bg_comment, pick(c.bg_const, c.bg_cur)),
  }

  local theme = {
    ["$schema"] = "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
    name = name,
    vars = vars,
    colors = colors,
    export = export,
  }

  return json_encode(theme) .. "\n"
end

-- Generate Typora theme file (<name>.css) from typora.css.template
local function gen_typora(name, c, template)
  local light = is_light_palette(c)
  local code_bg = pick(c.bg_float, c.bg)
  local accent_bg = pick(c.bg_def, pick(c.bg_cur, c.bg))
  local active_file_bg = light and accent_bg or pick(c.bg_cur, c.bg)
  local active_file_fg = light and pick(c.blue, c.fg) or c.fg

  local values = {
    bg = c.bg,
    fg = c.fg,
    dim = c.dim,
    blue = c.blue,
    comment = c.comment,
    green = c.green,
    magenta = c.magenta,
    wood = c.wood,
    red = c.red,
    teal = c.teal,
    code_bg = code_bg,
    blockquote_bg = pick(c.bg_comment, code_bg),
    meta_bg = pick(c.bg_cur, c.bg),
    string_bg = pick(c.bg_string, code_bg),
    const_bg = pick(c.bg_const, code_bg),
    active_file_bg = active_file_bg,
    active_file_fg = active_file_fg,
    blue_or_fg = pick(c.blue, c.fg),
    item_hover_bg = pick(c.bg_cur, c.bg),
    select_bg = c.bg_vis,
    border = pick(c.gray, c.dim),
  }

  local css = template:gsub("%$%{([%w_]+)%}", function(key)
    return values[key] or error(name .. ": typora template placeholder has no value: " .. key)
  end)

  return "/* GENERATED by palettes/generate.lua -- DO NOT EDIT */\n" .. css
end

-- Main
local palettes = find_palettes()
if #palettes == 0 then
  io.stderr:write("No palette files found in " .. script_dir .. "\n")
  os.exit(1)
end

-- Load and validate every palette before writing anything.
local loaded = {}
local errors = {}
local bg_owner = {}
for _, name in ipairs(palettes) do
  local palette = load_palette(name)
  validate_palette(name, palette, errors)

  if is_valid_hex(palette.bg) then
    local hex = palette.bg:gsub("#", ""):lower()
    if bg_owner[hex] then
      table.insert(errors, string.format("%s: bg %s already used by %s", name, palette.bg, bg_owner[hex]))
    else
      bg_owner[hex] = name
    end
  end

  loaded[name] = palette
end

if #errors > 0 then
  io.stderr:write("Palette validation failed:\n  " .. table.concat(errors, "\n  ") .. "\n")
  os.exit(1)
end

local typora_template_file = assert(io.open(script_dir .. "typora.css.template", "r"))
local typora_template = typora_template_file:read("*a")
typora_template_file:close()

local manifest_path = repo_root .. "palettes/manifest.txt"
local written = {}
local function emit(rel_path, content)
  write_file(repo_root .. rel_path, content)
  table.insert(written, rel_path)
end

print("Generating colorscheme files...")
for _, name in ipairs(palettes) do
  print(string.format("\n[%s]", name))
  local palette = loaded[name]

  -- 1. Copy palette to nvim lua/colors/
  emit("nvim/.config/nvim/lua/colors/" .. name .. ".lua", gen_nvim_palette(name, palette))

  -- 2. Generate nvim colorscheme entry point
  emit("nvim/.config/nvim/colors/colors_" .. name .. ".lua", gen_nvim_entry(name))

  -- 3. Generate wezterm colors
  emit("wezterm/.config/wezterm/colors_" .. name .. ".lua", gen_wezterm(name, palette))

  -- 4. Generate tmux colors
  emit("tmux/.config/tmux/colors-" .. name .. ".conf", gen_tmux(name, palette))

  -- 5. Generate shell fzf theme
  emit("shell/.config/shell/fzf-theme-" .. name .. ".sh", gen_fzf(name, palette))

  -- 6. Generate AeroSpace/JankyBorders mode colors
  emit("aerospace/.config/aerospace/mode-borders-" .. name .. ".sh", gen_aerospace_mode_borders(name, palette))

  -- 7. Generate pi theme
  emit("pi/.pi/agent/themes/" .. name .. ".json", gen_pi(name, palette))

  -- 8. Generate Typora theme
  emit(
    "typora/Library/Application Support/abnerworks.Typora/themes/" .. name .. ".css",
    gen_typora(name, palette, typora_template)
  )
end

-- 9. Generate the nvim background registry for the OSC 11 fallback path
print("\n[registry]")
emit("nvim/.config/nvim/lua/colors/registry.lua", gen_nvim_registry(bg_owner))

-- Prune artifacts recorded by the previous run but no longer generated.
local current = {}
for _, rel in ipairs(written) do
  current[rel] = true
end
local old_manifest = io.open(manifest_path, "r")
if old_manifest then
  for rel in old_manifest:lines() do
    if rel ~= "" and not current[rel] and os.remove(repo_root .. rel) then
      print("  pruned " .. rel)
    end
  end
  old_manifest:close()
end

table.sort(written)
write_file(manifest_path, table.concat(written, "\n") .. "\n")

print("\nDone.")
