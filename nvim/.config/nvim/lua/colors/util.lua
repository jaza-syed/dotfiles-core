-- Shared color math helpers for theme modules.
local M = {}

local function hex_to_rgb(hex)
  if type(hex) ~= "string" then
    return nil
  end

  local clean = hex:gsub("#", "")
  if #clean ~= 6 then
    return nil
  end

  return tonumber(clean:sub(1, 2), 16), tonumber(clean:sub(3, 4), 16), tonumber(clean:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02X%02X%02X", r, g, b)
end

function M.blend_hex(fg, bg, alpha)
  local fr, fgc, fb = hex_to_rgb(fg)
  local br, bgc, bb = hex_to_rgb(bg)
  if not fr or not br then
    return bg
  end

  return rgb_to_hex(
    math.floor((alpha * fr) + ((1 - alpha) * br) + 0.5),
    math.floor((alpha * fgc) + ((1 - alpha) * bgc) + 0.5),
    math.floor((alpha * fb) + ((1 - alpha) * bb) + 0.5)
  )
end

local function srgb_channel_to_linear(channel)
  local c = channel / 255
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

function M.is_light_bg(hex)
  local r, g, b = hex_to_rgb(hex)
  if not r then
    return false
  end

  local luminance = 0.2126 * srgb_channel_to_linear(r)
    + 0.7152 * srgb_channel_to_linear(g)
    + 0.0722 * srgb_channel_to_linear(b)

  return luminance > 0.5
end

return M
