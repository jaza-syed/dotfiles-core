-- Go buffer-local indentation and listchars policy.
vim.bo.expandtab = false
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4
vim.opt_local.listchars = {
  tab = "  ",
  trail = "·",
}
