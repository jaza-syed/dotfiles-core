-- Run: nvim --headless -u NONE -i NONE -l tests/nvim_string_masks.lua
-- Set DOTFILES_PRINT_MASKS=1 to print actual marks instead of asserting.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")

-- The compiled python/nix/yaml parsers live in the user's data site dir. They
-- are only read; no plugin or language server is started.
local parser_dir = vim.env.DOTFILES_TS_PARSER_DIR or (vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:append(parser_dir)

local function has_parser(lang)
  return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) > 0
end

for _, lang in ipairs({ "python", "nix", "yaml" }) do
  if not has_parser(lang) then
    print("SKIP: missing treesitter parser for " .. lang .. " under " .. parser_dir)
    return
  end
end

local fixtures = {
  {
    filetype = "python",
    module = "config.python_strings",
    ns = "AlabasterPythonStringLeadingWhitespace",
    lines = {
      "def f():",
      '    s = """',
      "        line one",
      "          deeper",
      "",
      "        after blank",
      '    """',
      "    x = 1",
      "t = '''abc",
      "\ttabbed",
      "'''",
      'y = """x',
      '  z""" + "q"',
    },
    expected = {
      "3:0-8 AlabasterStringLeadingWhitespace 120",
      "4:0-10 AlabasterStringLeadingWhitespace 120",
      "6:0-8 AlabasterStringLeadingWhitespace 120",
      "7:0-4 AlabasterStringLeadingWhitespace 120",
      "10:0-1 AlabasterStringLeadingWhitespace 120",
      "13:0-2 AlabasterStringLeadingWhitespace 120",
    },
  },
  {
    filetype = "nix",
    module = "config.nix_strings",
    ns = "AlabasterNixStringLeadingWhitespace",
    lines = {
      "{",
      "  a = ''",
      "    line one",
      "      deeper ${x}",
      "",
      "    tail",
      "  '';",
      '  c = "line1',
      '    line2";',
      "  d = ''",
      "    x'' + \"y\";",
      "}",
    },
    expected = {
      "3:0-4 AlabasterStringLeadingWhitespace 120",
      "4:0-4 AlabasterStringLeadingWhitespace 120",
      "6:0-4 AlabasterStringLeadingWhitespace 120",
      "7:0-2 AlabasterStringLeadingWhitespace 120",
      "9:0-4 AlabasterStringLeadingWhitespace 120",
      "11:0-4 AlabasterStringLeadingWhitespace 120",
    },
  },
  {
    filetype = "yaml",
    module = "config.yaml_strings",
    ns = "AlabasterYamlStringLeadingWhitespace",
    lines = {
      "a: |",
      "  literal line",
      "    indented more",
      "",
      "  after blank",
      "b: >-",
      "  folded line",
      "  more",
      "c: |2",
      "    explicit indent",
      "d: value",
    },
    expected = {
      "2:0-2 AlabasterStringLeadingWhitespace 120",
      "3:0-4 AlabasterStringLeadingWhitespace 120",
      "5:0-2 AlabasterStringLeadingWhitespace 120",
      "7:0-2 AlabasterStringLeadingWhitespace 120",
      "8:0-2 AlabasterStringLeadingWhitespace 120",
      "10:0-4 AlabasterStringLeadingWhitespace 120",
    },
  },
}

local print_mode = vim.env.DOTFILES_PRINT_MASKS == "1"
local failed = false

local function collect_marks(buf, ns_name)
  local ns = vim.api.nvim_create_namespace(ns_name)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  local out = {}
  for _, mark in ipairs(marks) do
    local row, col, details = mark[2], mark[3], mark[4]
    table.insert(
      out,
      string.format("%d:%d-%d %s %d", row + 1, col, details.end_col, details.hl_group, details.priority)
    )
  end
  table.sort(out, function(x, y)
    local xr = tonumber(x:match("^(%d+)"))
    local yr = tonumber(y:match("^(%d+)"))
    if xr ~= yr then
      return xr < yr
    end
    return x < y
  end)
  return out
end

for _, fixture in ipairs(fixtures) do
  local mod = require(fixture.module)
  mod.setup()

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, fixture.lines)
  vim.bo[buf].filetype = fixture.filetype

  mod.refresh(buf)
  local actual = collect_marks(buf, fixture.ns)

  if print_mode then
    print("== " .. fixture.filetype)
    for _, line in ipairs(actual) do
      print(string.format("%q,", line))
    end
  elseif not vim.deep_equal(actual, fixture.expected) then
    failed = true
    print("FAIL " .. fixture.filetype .. ": expected")
    print("  " .. table.concat(fixture.expected, "\n  "))
    print("actual")
    print("  " .. table.concat(actual, "\n  "))
  end

  -- Refresh must clear and repaint rather than stack marks.
  if not print_mode then
    mod.refresh(buf)
    assert(vim.deep_equal(collect_marks(buf, fixture.ns), actual), fixture.filetype .. ": refresh stacked marks")
  end

  -- Pending deferred work must not repaint after teardown.
  if not print_mode and type(mod.teardown) == "function" then
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    mod.teardown()
    local ns = vim.api.nvim_create_namespace(fixture.ns)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.wait(120, function()
      return false
    end)
    assert(#collect_marks(buf, fixture.ns) == 0, fixture.filetype .. ": repainted after teardown")

    mod.setup()
    mod.refresh(buf)
    assert(vim.deep_equal(collect_marks(buf, fixture.ns), actual), fixture.filetype .. ": refresh after re-setup")
  end

  -- A deferred refresh scheduled before buffer deletion must stay harmless.
  vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.wait(120, function()
    return false
  end)
end

if print_mode then
  return
end

if failed then
  print("String mask fixture checks failed")
  vim.cmd("cquit 1")
end
print("String mask fixture checks passed")
