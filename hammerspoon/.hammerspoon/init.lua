local zsa_voyager_vendor_id = 0x3297
local zsa_voyager_product_id = 0x1977

local function usb_id(value)
  if type(value) == "number" then
    return value
  elseif type(value) == "string" then
    return tonumber(value) or tonumber(value:gsub("^0[xX]", ""), 16)
  end
end

local function text_contains(value, needle)
  return string.find(string.lower(tostring(value or "")), needle, 1, true) ~= nil
end

local function is_zsa_voyager(device)
  local product_name = device.productName or device.product or device.name
  local vendor_name = device.vendorName or device.manufacturer
  local vendor_id = usb_id(device.vendorID)
  local product_id = usb_id(device.productID)

  if vendor_id == zsa_voyager_vendor_id and product_id == zsa_voyager_product_id then
    return true
  end

  return text_contains(product_name, "voyager")
    and (
      vendor_id == zsa_voyager_vendor_id
      or product_id == zsa_voyager_product_id
      or text_contains(product_name, "zsa")
      or text_contains(vendor_name, "zsa")
    )
end

local function zsa_voyager_connected()
  for _, device in ipairs(hs.usb.attachedDevices() or {}) do
    if is_zsa_voyager(device) then
      return true
    end
  end

  return false
end

local ctrl_table = {
  send_escape = false,
}

-- Below threshold: escape key
-- Above threshold: modifier
-- Lower to bias to modifier, higher to bias to escape
local control_key_timer
local last_mods = {}

local function reset_control_state()
  ctrl_table["send_escape"] = false
  last_mods = {}

  if control_key_timer then
    control_key_timer:stop()
  end
end

control_key_timer = hs.timer.delayed.new(0.125, function()
  ctrl_table["send_escape"] = false
  -- log.i("timer fired")
  -- control_key_timer:stop()
end)

local function control_handler(evt)
  local new_mods = evt:getFlags()
  if last_mods["ctrl"] == new_mods["ctrl"] then
    return false
  end
  if not last_mods["ctrl"] then
    -- log.i("control pressed")
    last_mods = new_mods
    ctrl_table["send_escape"] = true
    -- log.i("starting timer")
    control_key_timer:start()
  else
    -- log.i("contrtol released")
    -- log.i(ctrl_table["send_escape"])
    if ctrl_table["send_escape"] then
      -- log.i("send escape key...")
      hs.eventtap.keyStroke({}, "ESCAPE")
    end
    last_mods = new_mods
    control_key_timer:stop()
  end
  return false
end

local control_tap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, control_handler)

local date_hotkey = hs.hotkey.new({"alt", "shift"}, "d", function()
  local date = os.date("%Y-%m-%d")
  hs.eventtap.keyStrokes(date)
end)

local keyboard_stuff_enabled = nil

local function set_keyboard_stuff_enabled(enabled)
  if keyboard_stuff_enabled == enabled then
    return
  end

  keyboard_stuff_enabled = enabled

  if enabled then
    control_tap:start()
    date_hotkey:enable()
  else
    reset_control_state()
    control_tap:stop()
    date_hotkey:disable()
  end
end

local function update_keyboard_stuff_for_voyager()
  -- Hammerspoon's keyboard event APIs do not expose the physical keyboard
  -- for each keypress, so suspend these keyboard handlers while the Voyager
  -- is attached.
  set_keyboard_stuff_enabled(not zsa_voyager_connected())
end

-- Keep this global so Hammerspoon does not garbage collect the watcher.
zsa_voyager_usb_watcher = hs.usb.watcher.new(update_keyboard_stuff_for_voyager)
zsa_voyager_usb_watcher:start()
update_keyboard_stuff_for_voyager()

screen_watcher = hs.screen.watcher.new(function()
  hs.execute("/opt/homebrew/bin/brew services restart sketchybar", true)
end)
screen_watcher:start()
