local utils = require "gno-nvim.utils"

local M = {}

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

function M.setup(config)
  -- Install formatter hook
  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.gno",
    callback = function ()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.lsp.buf.format({
        bufnr = bufnr,
        async = false,
      })
    end
  })

  install_lsp_config(config)
end

return M
