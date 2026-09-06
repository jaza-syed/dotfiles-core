-- Theme startup, fallback detection, and colorscheme change hooks.
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("SettingsTheme", { clear = true })
  local function apply_colorscheme_overrides()
    require("config.ui").apply_lualine_theme()
  end

  -- Colorscheme: DOTFILES_THEME is propagated by the shell/tmux/WezTerm
  -- startup path and is the primary source of truth for Neovim. OSC 11 remains
  -- as a fallback for unusual launches where the environment was not provided.
  if not vim.env.DOTFILES_THEME or vim.env.DOTFILES_THEME == "" then
    vim.api.nvim_create_autocmd("UIEnter", {
      group = group,
      once = true,
      callback = function()
        require("colors").detect_and_apply()
      end,
    })
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = apply_colorscheme_overrides,
  })

  -- On config reload, preserve the active colorscheme; on startup, apply the
  -- propagated environment theme immediately so there is no light-theme flash.
  local colors = require("colors")
  local current_colorscheme = vim.g.colors_name
  if type(current_colorscheme) == "string" and current_colorscheme:match("^colors_") then
    colors.apply_theme(current_colorscheme)
  else
    colors.apply_env_or_default("light")
  end
end

return M
