-- Reloadable settings entry point for options, UI, keymaps, and hooks.
-- The module list and order live in config.reload's registry.
-- Reload with <leader>cr

-- Leader (also set in init.lua before lazy, repeated here for reload)
vim.g.mapleader = " "

require("config.reload").setup_kind("settings")
