-- Telescope picker facade plus custom picker implementations.
local M = {}

local function builtin()
  return require("telescope.builtin")
end

local function telescope_config()
  return require("telescope.config").values
end

local function actions()
  return require("telescope.actions")
end

local function action_state()
  return require("telescope.actions.state")
end

local function normalize_path(path)
  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(path)
  end
  return vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
end

local function join_path(root, path)
  if path == "." or path == "" then
    return root
  end
  if path:sub(1, 1) == "/" then
    return path
  end
  return root:gsub("/+$", "") .. "/" .. path
end

local function file_entry_path(entry)
  if not entry then
    return nil
  end

  local path = entry.path or entry.filename
  if not path and type(entry.value) == "string" then
    path = entry.value
  end

  if type(path) ~= "string" or path == "" then
    return nil
  end

  return path
end

local function marked_file_paths(prompt_bufnr)
  local picker = action_state().get_current_picker(prompt_bufnr)
  local entries = picker:get_multi_selection()

  local paths = {}
  local seen = {}
  for _, entry in ipairs(entries) do
    local path = file_entry_path(entry)
    if path and not seen[path] then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  return paths
end

local function grep_marked_files(prompt_bufnr, opts)
  local paths = marked_file_paths(prompt_bufnr)
  if #paths == 0 then
    vim.notify("No files marked", vim.log.levels.WARN)
    return
  end

  actions().close(prompt_bufnr)
  vim.schedule(function()
    M.live_grep({
      cwd = opts.cwd,
      search_dirs = paths,
      prompt_title = string.format(
        "Live grep %d marked file%s (<C-g> fuzzy refine, <C-/> help)",
        #paths,
        #paths == 1 and "" or "s"
      ),
    })
  end)
end

local function attach_file_grep_mapping(opts)
  local previous_attach = opts.attach_mappings
  opts.attach_mappings = function(prompt_bufnr, map)
    local keep = true
    if previous_attach then
      keep = previous_attach(prompt_bufnr, map)
    end

    map({ "i", "n" }, "<C-f>", function()
      grep_marked_files(prompt_bufnr, opts)
    end, { desc = "Grep marked files" })

    return keep
  end
end

function M.files(opts)
  opts = vim.tbl_extend("force", { hidden = true }, opts or {})
  opts.prompt_title = opts.prompt_title or "Find files (<C-f> grep marked, <C-/> help)"
  attach_file_grep_mapping(opts)
  builtin().find_files(opts)
end

function M.git_files(opts)
  opts = opts or {}
  local ok = pcall(builtin().git_files, opts)
  if not ok then
    M.files(opts)
  end
end

function M.buffers(opts)
  builtin().buffers(opts or {})
end

function M.live_grep(opts)
  opts = vim.tbl_extend("force", {
    prompt_title = "Live grep args (<C-g> fuzzy refine, <C-/> help)",
    hidden = true,
  }, opts or {})

  local ok, telescope = pcall(require, "telescope")
  local extension = ok and telescope.extensions and telescope.extensions.live_grep_args
  if extension and extension.live_grep_args then
    extension.live_grep_args(opts)
    return
  end

  local previous_attach = opts.attach_mappings
  opts.attach_mappings = function(prompt_bufnr, map)
    local keep = true
    if previous_attach then
      keep = previous_attach(prompt_bufnr, map)
    end

    map({ "i", "n" }, "<C-g>", actions().to_fuzzy_refine, { desc = "Fuzzy refine results" })
    return keep
  end

  builtin().live_grep(opts)
end

function M.current_buffer(opts)
  builtin().current_buffer_fuzzy_find(opts or {})
end

function M.builtin(opts)
  builtin().builtin(opts or {})
end

function M.commands(opts)
  builtin().commands(opts or {})
end

local function systemlist_in_cwd(cmd, cwd)
  if vim.system then
    local result = vim.system({ "sh", "-c", cmd }, { cwd = cwd, text = true }):wait()
    if result.code ~= 0 then
      return {}
    end
    return vim.split(vim.trim(result.stdout or ""), "\n", { plain = true, trimempty = true })
  end

  local previous_cwd = vim.fn.getcwd()
  local ok_chdir = pcall(vim.fn.chdir, cwd)
  local results = vim.fn.systemlist(cmd)
  if ok_chdir then
    pcall(vim.fn.chdir, previous_cwd)
  end

  if vim.v.shell_error ~= 0 then
    return {}
  end
  return results
end

local function directory_entries(cwd)
  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = "fd --color=never --type directory --exclude .git --exclude .jj --strip-cwd-prefix"
  elseif vim.fn.executable("fdfind") == 1 then
    cmd = "fdfind --color=never --type directory --exclude .git --exclude .jj --strip-cwd-prefix"
  else
    cmd = [[find . -type d -not -path . -not -path '*/.git/*' -not -path '*/.jj/*' | sed 's#^\./##']]
  end

  local results = systemlist_in_cwd(cmd, cwd)
  table.insert(results, 1, ".")
  return results
end

function M.live_grep_dir(opts)
  opts = opts or {}
  local cwd = normalize_path(opts.cwd or vim.fn.getcwd())
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = telescope_config()
  local telescope_actions = actions()
  local state = action_state()

  pickers
    .new(opts, {
      prompt_title = "Grep directory (<C-/> help)",
      finder = finders.new_table({
        results = directory_entries(cwd),
        entry_maker = function(entry)
          local path = normalize_path(join_path(cwd, entry))
          return {
            value = path,
            ordinal = entry,
            display = entry,
            path = path,
          }
        end,
      }),
      sorter = conf.file_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        telescope_actions.select_default:replace(function()
          local selection = state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)
          if selection and selection.path then
            M.live_grep({ cwd = selection.path })
          end
        end)
        return true
      end,
    })
    :find()
end

local function command_history_entries()
  local entries = {}
  for index = vim.fn.histnr(":"), 1, -1 do
    local command = vim.fn.histget(":", index)
    if command and command ~= "" then
      table.insert(entries, {
        index = index,
        command = command,
      })
    end
  end
  return entries
end

local function command_history_finder()
  return require("telescope.finders").new_table({
    results = command_history_entries(),
    entry_maker = function(entry)
      return {
        value = entry,
        ordinal = entry.command,
        display = string.format("%5d  %s", entry.index, entry.command),
      }
    end,
  })
end

local function run_command(command)
  local ok, err = pcall(vim.cmd, command)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

function M.command_history(opts)
  opts = opts or {}
  local pickers = require("telescope.pickers")
  local conf = telescope_config()
  local telescope_actions = actions()
  local state = action_state()

  pickers
    .new(opts, {
      prompt_title = "Command history (<C-/> help)",
      finder = command_history_finder(),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        telescope_actions.select_default:replace(function()
          local selection = state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)
          if selection and selection.value and selection.value.command then
            vim.schedule(function()
              run_command(selection.value.command)
            end)
          end
        end)

        local function edit_command()
          local selection = state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)
          if selection and selection.value and selection.value.command then
            vim.schedule(function()
              vim.api.nvim_feedkeys(":" .. selection.value.command, "n", false)
            end)
          end
        end

        local function delete_command()
          local selection = state.get_selected_entry()
          if not selection or not selection.value then
            return
          end

          vim.fn.histdel(":", selection.value.index)
          local picker = state.get_current_picker(prompt_bufnr)
          picker:refresh(command_history_finder(), { reset_prompt = false })
        end

        map({ "i", "n" }, "<C-e>", edit_command, { desc = "Edit command" })
        map({ "i", "n" }, "<C-x>", delete_command, { desc = "Delete command" })
        return true
      end,
    })
    :find()
end

local function workspace_symbol_opts(opts, toggle, toggle_desc)
  opts = opts or {}
  local previous_attach = opts.attach_mappings
  opts.attach_mappings = function(prompt_bufnr, map)
    local keep = true
    if previous_attach then
      keep = previous_attach(prompt_bufnr, map)
    end

    local function toggle_symbols()
      local query = action_state().get_current_line()
      actions().close(prompt_bufnr)
      vim.schedule(function()
        local next_opts = vim.tbl_extend("force", opts, {
          query = query,
          default_text = query,
        })
        next_opts.attach_mappings = nil
        next_opts.prompt_title = nil
        toggle(next_opts)
      end)
    end

    map({ "i", "n" }, "<C-g>", toggle_symbols, { desc = toggle_desc })
    return keep
  end
  return opts
end

function M.workspace_symbols(opts)
  opts = workspace_symbol_opts(opts or {}, M.workspace_symbols_static, "Local fuzzy refine results")
  opts.prompt_title = opts.prompt_title or "Workspace symbols (live, <C-g> local refine, <C-/> help)"
  builtin().lsp_dynamic_workspace_symbols(opts)
end

function M.workspace_symbols_static(opts)
  opts = workspace_symbol_opts(opts or {}, M.workspace_symbols, "Search symbols again")
  opts.prompt_title = opts.prompt_title or "Workspace symbols (local, <C-g> search again, <C-/> help)"
  builtin().lsp_workspace_symbols(opts)
end

function M.global_symbols(opts)
  require("config.lsp.global_symbols").live_global_symbols(opts or {})
end

function M.zoxide(opts)
  opts = opts or {}
  require("telescope").extensions.zoxide.list(opts)
end

return M
