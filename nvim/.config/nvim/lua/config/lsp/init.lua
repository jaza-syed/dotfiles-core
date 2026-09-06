-- Native Neovim LSP server configuration and attach policies.
local M = {}

local projects = require("config.projects")
local machine = require("config.machine")

-- Launch an env-sensitive server through `direnv exec <sub-repo>` so it uses
-- the sub-repo's devshell toolchain. No-ops outside the managed workspace.
local function direnv_cmd(argv)
  return function(dispatchers, config)
    local cmd = projects.direnv_wrap(argv, config.root_dir)
    return vim.lsp.rpc.start(cmd, dispatchers, {
      cwd = config.root_dir,
      env = config.cmd_env,
    })
  end
end

-- Launch a server through `mise exec` when the project declares a mise
-- toolchain, since there is no global mise config.
local function mise_cmd(argv)
  return function(dispatchers, config)
    local root = config.root_dir
    local cmd = argv
    if root and #vim.fs.find({ "mise.toml", ".mise.toml" }, { path = root, upward = true }) > 0 then
      cmd = vim.list_extend({ "mise", "exec", "--" }, argv)
    end
    return vim.lsp.rpc.start(cmd, dispatchers, {
      cwd = root,
      env = config.cmd_env,
    })
  end
end

-- Root a workspace-aware server at its cargo/uv workspace inside the managed
-- workspace, else fall back to the given markers.
local function workspace_root_dir(marker, key, fallback_markers)
  return function(bufnr, on_dir)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if machine.is_managed(name) then
      local root = projects.workspace_root(name, marker, key)
      if root then
        return on_dir(root)
      end
    end
    on_dir(vim.fs.root(bufnr, fallback_markers))
  end
end

local capabilities_cache = nil

function M.capabilities()
  if capabilities_cache then
    return capabilities_cache
  end

  capabilities_cache = vim.tbl_deep_extend(
    "force",
    vim.lsp.protocol.make_client_capabilities(),
    require("cmp_nvim_lsp").default_capabilities()
  )

  return capabilities_cache
end

local function suppress_ty_diagnostics(bufnr, group)
  vim.api.nvim_clear_autocmds({ group = group, event = "DiagnosticChanged", buffer = bufnr })
  local clearing = false

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    buffer = bufnr,
    callback = function()
      if clearing then
        return
      end

      local ty_namespaces = {}
      for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
        if diagnostic.source == "ty" then
          ty_namespaces[diagnostic.namespace] = true
        end
      end

      if next(ty_namespaces) then
        clearing = true
        for namespace_id in pairs(ty_namespaces) do
          vim.diagnostic.reset(namespace_id, bufnr)
        end
        clearing = false
      end
    end,
  })
end

local function setup_python(capabilities)
  -- ty: Python language features and completion (incl. namespace-aware
  -- auto-import) for all projects. Diagnostics are suppressed for managed
  -- projects (ruff + mypy handle those instead).
  vim.lsp.config("ty", {
    cmd = direnv_cmd({ "ty", "server" }),
    filetypes = { "python" },
    root_dir = workspace_root_dir("pyproject.toml", "[tool.uv.workspace]", { "pyproject.toml", "ty.toml", ".git" }),
    capabilities = capabilities,
  })
  vim.lsp.enable("ty")

  -- ruff: linting diagnostics for managed projects only, respects
  -- pyproject.toml automatically. Leaving on_dir uncalled elsewhere keeps the
  -- server from starting.
  vim.lsp.config("ruff", {
    cmd = direnv_cmd({ "ruff", "server" }),
    filetypes = { "python" },
    root_dir = function(bufnr, on_dir)
      local name = vim.api.nvim_buf_get_name(bufnr)
      if not machine.is_managed(name) then
        return
      end
      local root = projects.workspace_root(name, "pyproject.toml", "[tool.uv.workspace]")
      if root then
        on_dir(root)
      end
    end,
    capabilities = capabilities,
  })
  vim.lsp.enable("ruff")
end

local function setup_python_attach_policy()
  local group = vim.api.nvim_create_augroup("ConfigPythonLspPolicy", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end

      if client.name ~= "ty" or not machine.is_managed(client.root_dir or "") then
        return
      end

      -- Suppress ty diagnostics in managed projects (ruff + mypy own that).
      -- ty uses pull diagnostics in a different namespace than get_namespace() returns,
      -- so we detect the namespace by source name and clear reactively on DiagnosticChanged.
      suppress_ty_diagnostics(args.buf, group)
    end,
  })
  for _, client in ipairs(vim.lsp.get_clients({ name = "ty" })) do
    if machine.is_managed(client.root_dir or "") then
      for bufnr in pairs(client.attached_buffers) do
        suppress_ty_diagnostics(bufnr, group)
      end
    end
  end
end

local function setup_language_servers(capabilities)
  vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    capabilities = capabilities,
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        workspace = {
          checkThirdParty = false,
        },
        telemetry = {
          enable = false,
        },
      },
    },
  })
  vim.lsp.enable("lua_ls")

  vim.lsp.config("rust_analyzer", {
    before_init = function(params, config)
      require("config.machine").before_init(params, config)
    end,
    cmd = direnv_cmd({ "rust-analyzer" }),
    filetypes = { "rust" },
    root_dir = workspace_root_dir("Cargo.toml", "[workspace]", { "Cargo.toml", "rust-project.json", ".git" }),
    settings = {
      ["rust-analyzer"] = {},
    },
  })
  vim.lsp.enable("rust_analyzer")

  vim.lsp.config("gopls", {
    cmd = direnv_cmd({ "gopls" }),
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.work", "go.mod", ".git" },
    capabilities = capabilities,
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
        gofumpt = true,
      },
    },
  })
  vim.lsp.enable("gopls")

  vim.lsp.config("vtsls", {
    cmd = direnv_cmd({ "vtsls", "--stdio" }),
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    capabilities = capabilities,
  })
  vim.lsp.enable("vtsls")

  vim.lsp.config("hls", {
    cmd = direnv_cmd({ "haskell-language-server-wrapper", "--lsp" }),
    filetypes = { "haskell", "lhaskell" },
    root_markers = { "hie.yaml", "stack.yaml", "cabal.project", "package.yaml", ".git" },
    capabilities = capabilities,
    settings = {
      haskell = {},
    },
  })
  vim.lsp.enable("hls")

  vim.lsp.config("nixd", {
    cmd = direnv_cmd({ "nixd" }),
    filetypes = { "nix" },
    root_markers = { "flake.nix", "shell.nix", "default.nix", ".git" },
    capabilities = capabilities,
    settings = {
      nixd = {},
    },
  })
  vim.lsp.enable("nixd")

  vim.lsp.config("elmls", {
    before_init = function(params, config)
      require("config.machine").before_init(params, config)
    end,
    cmd = direnv_cmd({ "elm-language-server" }),
    filetypes = { "elm" },
    root_markers = { "elm.json", ".git" },
    capabilities = capabilities,
    settings = {
      elmLS = {
        elmReviewDiagnostics = "warning",
        onlyUpdateDiagnosticsOnSave = false,
      },
    },
  })
  vim.lsp.enable("elmls")

  vim.lsp.config("zls", {
    cmd = mise_cmd({ "zls" }),
    filetypes = { "zig", "zon" },
    root_markers = { "build.zig", "build.zig.zon", ".git" },
    capabilities = capabilities,
  })
  vim.lsp.enable("zls")
end

function M.setup()
  local capabilities = M.capabilities()
  setup_python(capabilities)
  setup_python_attach_policy()
  setup_language_servers(capabilities)
end

return M
