local utils = require "gno-nvim.utils"

local M = {}

local function check_dependencies()
  if not vim.treesitter.language.get_lang "go" then
    -- Check if go syntax is available and install it if possible
    local _, ok = utils.safe_require "nvim-treesitter"
    if not ok then
      utils.log_write(
        'Missing go language syntax, please install nvim-treesitter and run ":TSInstall go"',
        vim.log.levels.ERROR
      )
    else
      -- nvim-treesitter ':TSInstall' command is not available here yet
      utils.log_write 'Missing go language syntax, please run ":TSInstall go"'
    end
  end

  local deps = {
    plenary = "plenary.nvim",
    lspconfig = "nvim-lspconfig",
  }

  local missing = {}

  for mod, name in pairs(deps) do
    local ok, _ = pcall(require, mod)
    if not ok then
      table.insert(missing, name)
    end
  end

  if #missing > 0 then
    error("gno.nvim: missing dependencies: " .. table.concat(missing, ", "))
  end
end

local function register_gno_formatter()
  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.gno",
    callback = function(args)
      local job = require "plenary.job"
      local bufnr = vim.api.nvim_get_current_buf()

      -- unlike "args.file", contains full file path.
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Format code and refresh the buffer
      job
        :new({
          command = "gofumpt",
          writer = lines,
          on_exit = function(j, exit_code)
            if exit_code == 0 then
              vim.schedule(function()
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, j:result())
              end)
            else
              vim.schedule(function()
                utils.log_write("Error running gofumpt", vim.log.levels.ERROR)
              end)
            end
          end,
        })
        :sync()
    end,
  })
end

---@class GnoNvimLSPConfig
---
--- LSP server initialization config for nvim-lspconfig.
--- See: https://neovim.io/doc/user/lsp.html#vim.lsp.config()
---
---@field cmd? string[] # Custom command line to start LSP server.
---@field cmd_env? table # Custom environment variables for LSP server process.
---@field capabilities? string[] # Custom LSP client capabilities. By default, uses 'cmp-nvim-lsp' capabilities if installed.
---@field filetypes? string[] # Custom filetypes list.
---@field root_dir? fun(string): string # Custom function to locate root directory.
---@field settings? table # Custom settings passed to a language server.

---@param config GnoNvimLSPConfig
local function prefill_config_defaults(config)
  if not config.cmd then
    -- Automatically find gnopls if it's not in path.
    local gnopls_bin, ok = utils.locate_gnopls()
    if not ok then
      -- nvim-lspconfig swallows any thrown exceptions, can't panic here.
      vim.api.nvim_err_writeln(
        "Error: Cannot find "
          .. gnopls_bin
          .. " in $PATH or $GOPATH. Please run 'go install github.com/gnolang/gnopls@latest'"
      )
    end
    config.cmd = { gnopls_bin, "serve" }
  end

  if not config.capabilities then
    -- Enable autocompletion if cmp-nvim-lsp is installed.
    local cmp, ok = utils.safe_require "cmp_nvim_lsp"
    if ok then
      config.capabilities = cmp.default_capabilities()
    end
  end
end

---@param config? GnoNvimLSPConfig
local function install_lsp_config(config)
  local lspconfig = require "lspconfig"
  local lspconfigs = require "lspconfig.configs"

  if lspconfigs[utils.plugin_name] ~= nil then
    utils.log_write(
      "Another LSP configuration is already defined, skipping install",
      vim.log.levels.INFO
    )
    return
  end

  -- .cmd is populated by .on_new_config
  local util = require "lspconfig.util"
  local default_config = {
    filetypes = { "gno" },
    single_file_support = true,
    on_new_config = prefill_config_defaults,
    root_dir = function(fname)
      return util.root_pattern("gno.mod", "gno.sum", ".git")(fname)
    end,
  }

  local cmp, has_cmp = utils.safe_require "cmp_nvim_lsp"
  if has_cmp then
    default_config.capabilities = cmp.default_capabilities()
  end

  lspconfigs[utils.plugin_name] = {
    default_config = default_config,
    docs = {
      description = [[
https://github.com/gnolang/gnopls/

LSP server for Gnolang.
      ]],
    },
  }

  -- lspconfig will fail if config is nil
  if not config then
    config = {}
  end

  lspconfig[utils.plugin_name].setup(config)
end

--- Enables LSP server and formatter.
---
--- See: https://neovim.io/doc/user/lsp.html#vim.lsp.config()
---
--- @param config? GnoNvimLSPConfig
function M.setup(config)
  check_dependencies()

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.gno",
    command = "set filetype=gno",
  })

  vim.treesitter.language.register("go", "gno")
  vim.api.nvim_create_augroup("gno", { clear = true })

  register_gno_formatter()
  install_lsp_config(config)
end

return M
