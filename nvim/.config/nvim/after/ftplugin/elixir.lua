-- Nvim ships no indent/elixir.vim, so indentation comes from the treesitter query.
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
