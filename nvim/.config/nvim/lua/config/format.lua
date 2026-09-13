-- conform.nvim configuration. Formatting runs on request, not on save.
local M = {}

local machine = require("config.machine")

function M.setup()
  require("conform").setup({
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format" },
      nix = { "nixfmt" },
      rust = { "rustfmt" },
      go = { "gofmt" },
      elm = { "elm_format" },
    },
  })
end

-- Formats a buffer with the machine's formatters when it names any, else the
-- filetype's, else the LSP server's.
function M.format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  require("conform").format({
    bufnr = bufnr,
    formatters = machine.formatters(bufnr),
    lsp_format = "fallback",
    async = true,
  }, function(err)
    if err then
      vim.notify(err, vim.log.levels.WARN)
    end
  end)
end

return M
