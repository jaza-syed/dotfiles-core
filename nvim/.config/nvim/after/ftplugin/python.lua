-- Python buffer-local policy: disable automatic hard wrapping.
-- Do not hard-wrap Python while typing. Some projects set max_line_length in
-- .editorconfig; Nvim maps that to 'textwidth', and the default 't'/'c'
-- formatoptions then insert line breaks automatically.
vim.bo.formatoptions = vim.bo.formatoptions:gsub("[tc]", "")
