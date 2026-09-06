-- Nix multiline-string whitespace highlighting via extmarks. Unlike Python and
-- YAML, only the common content indent is masked: Nix indented strings keep
-- indentation beyond the shared margin as string content.
local function is_closing_delimiter_line(node, text)
  local rest = text:match("^[ \t]*(.*)$") or text
  if node:type() == "indented_string_expression" then
    return rest == "''"
  end
  return rest == '"'
end

local function common_content_indent(node, lines, first_row, end_row, end_col)
  local common_indent = nil

  for i, line in ipairs(lines) do
    local row = first_row + i - 1
    local text = line
    if row == end_row then
      text = text:sub(1, math.min(#text, end_col))
    end

    if not (row == end_row and is_closing_delimiter_line(node, text)) then
      local indent = text:match("^[ \t]*") or ""
      local rest = text:sub(#indent + 1)
      if rest:find("[^ \t]") then
        common_indent = math.min(common_indent or #indent, #indent)
      end
    end
  end

  return common_indent
end

return require("config.string_masks").new({
  filetype = "nix",
  ns = "AlabasterNixStringLeadingWhitespace",
  augroup = "AlabasterNixStringWhitespace",
  query = [[
    [
      (string_expression)
      (indented_string_expression)
    ] @string
  ]],
  mask_col = common_content_indent,
})
