-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local function load_theme(name)
  local module_name = "colors_" .. name
  package.loaded[module_name] = nil

  local ok, theme = pcall(require, module_name)
  if not ok then
    wezterm.log_error("failed to load theme " .. name .. ": " .. tostring(theme))
    return nil
  end

  if type(theme) ~= "table" or type(theme.colors) ~= "table" or type(theme.window_frame) ~= "table" then
    wezterm.log_error("theme " .. name .. " is missing colors or window_frame")
    return nil
  end

  return theme
end

-- Theme modules provide window_frame colors, but we keep the UI title/tab font
-- size pinned here so switching themes doesn't affect chrome sizing.
local function with_ui_window_frame(window_frame)
  local merged = {}
  for key, value in pairs(window_frame or {}) do
    merged[key] = value
  end
  merged.font_size = 14.0
  return merged
end

-- This is where you actually apply your config choices.
-- or, changing the font size and color scheme.
config.font_size = 16
config.font = wezterm.font "Liga SFMono Nerd Font"
-- Colors: loaded from generated palette (see palettes/ and scripts/generate_colorscheme.sh)
local default_theme = load_theme("light")
if default_theme then
  config.colors = default_theme.colors
  config.window_frame = with_ui_window_frame(default_theme.window_frame)
end

-- Per-window theme IPC: write the active theme name to a file keyed by
-- window id so that new tabs/splits (which spawn fresh shells) can
-- discover it during shell init. See
-- ~/.config/shell/interactive.sh::resolve_theme_name for the reader.
local function theme_file_for(window_id)
  return '/tmp/wezterm-theme-' .. tostring(window_id)
end

-- Per-window theme switching via user-var escape (sent by `theme` shell function)
wezterm.on('user-var-changed', function(window, _, name, value)
  if name ~= 'THEME' then
    return
  end

  local theme = load_theme(value)
  if not theme then
    return
  end

  local overrides = window:get_config_overrides() or {}
  overrides.colors = theme.colors
  overrides.window_frame = with_ui_window_frame(theme.window_frame)
  window:set_config_overrides(overrides)

  local f = io.open(theme_file_for(window:window_id()), 'w')
  if f then
    f:write(value)
    f:close()
  end
end)

-- Only show tab bar if >1 tab
config.hide_tab_bar_if_only_one_tab = true

-- Hide title bar
config.window_decorations = "RESIZE"

-- Disable bell
config.audible_bell = "Disabled"

-- Don't change window size with font size change
config.adjust_window_size_when_changing_font_size = false

config.leader = { key = ';', mods = 'CTRL', timeout_milliseconds = 1000 }

-- Ctrl+Shift+O: highlight URLs on screen, type label to open in browser
config.keys = {
  {
    key = 'v',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 's',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.ActivateCommandPalette,
  },
  {
    key = 'o',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.QuickSelectArgs {
      label = 'open url',
      patterns = { 'https?://\\S+' },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.open_with(url)
      end),
    },
  },
}

-- Finally, return the configuration to wezterm:
return config
