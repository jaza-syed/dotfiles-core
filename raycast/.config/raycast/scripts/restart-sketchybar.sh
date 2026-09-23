#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Restart sketchybar
# @raycast.mode silent
# @raycast.packageName dotfiles

launchctl kickstart -k "gui/$(id -u)/org.nixos.sketchybar"
echo "Restarted sketchybar"
