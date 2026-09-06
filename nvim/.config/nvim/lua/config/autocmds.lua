-- Global autocmds that are not better expressed as filetype plugins.
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("SettingsAutocmds", { clear = true })
  local lsp_document_highlight_group = vim.api.nvim_create_augroup("SettingsLspDocumentHighlight", { clear = true })

  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = group,
    pattern = "*.json",
    command = "set ft=json syntax=javascript",
  })

  -- A new terminal starts ready to type. <C-\><C-n> for normal mode.
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      if vim.api.nvim_get_current_buf() == args.buf then
        vim.cmd("startinsert")
      end
    end,
  })

  -- Hide the colorcolumn/virtcolumn guide in non-editing UI buffers.
  local function update_colorcolumn_for_buffer()
    local special_buftypes = {
      help = true,
      nofile = true,
      prompt = true,
      quickfix = true,
      terminal = true,
    }
    local special_filetypes = {
      help = true,
      man = true,
      netrw = true,
      oil = true,
      qf = true,
    }

    local is_special = special_buftypes[vim.bo.buftype] or special_filetypes[vim.bo.filetype]
    local ok, saved_colorcolumn = pcall(vim.api.nvim_win_get_var, 0, "saved_colorcolumn")

    if is_special then
      if not ok then
        vim.w.saved_colorcolumn = vim.wo.colorcolumn ~= "" and vim.wo.colorcolumn
          or vim.w.virtcolumn_last_cc
          or vim.b.virtcolumn_last_cc
          or ""
      end
      vim.opt_local.colorcolumn = ""
    elseif ok then
      vim.opt_local.colorcolumn = saved_colorcolumn
      pcall(vim.api.nvim_win_del_var, 0, "saved_colorcolumn")
    end
  end

  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TermOpen", "WinEnter" }, {
    group = group,
    callback = update_colorcolumn_for_buffer,
  })

  -- Disable LSP semantic tokens -- treesitter + custom highlights handle
  -- coloring, and semantic tokens at priority 125 override diagnostic
  -- underline colors.
  local function apply_lsp_policy(client, bufnr)
    if not client then
      return
    end

    client.server_capabilities.semanticTokensProvider = nil

    if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, bufnr) then
      vim.api.nvim_clear_autocmds({ group = lsp_document_highlight_group, buffer = bufnr })

      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = lsp_document_highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
        group = lsp_document_highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      apply_lsp_policy(vim.lsp.get_client_by_id(args.data.client_id), args.buf)
    end,
  })
  for _, client in ipairs(vim.lsp.get_clients()) do
    for bufnr in pairs(client.attached_buffers) do
      apply_lsp_policy(client, bufnr)
    end
  end
end

return M
