-- YAML block-scalar whitespace highlighting via extmarks. The scalar header
-- line (`|`, `>`, chomping/indent indicators) is outside the masked rows.
return require("config.string_masks").new({
  filetype = "yaml",
  ns = "AlabasterYamlStringLeadingWhitespace",
  augroup = "AlabasterYamlStringWhitespace",
  query = [[
    (block_scalar) @string
  ]],
})
