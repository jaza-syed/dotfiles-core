-- Python multiline-string whitespace highlighting via extmarks.
return require("config.string_masks").new({
  filetype = "python",
  ns = "AlabasterPythonStringLeadingWhitespace",
  augroup = "AlabasterPythonStringWhitespace",
  query = [[
    (string) @string
  ]],
})
