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

---@class GnoNvimOpts : GnoNvimCommandsOpts
---
--- gno.nvim plugin config.
---
--- @field lsp? GnoNvimLSPConfig LSP client config for nvim-lspconfig.
--- @field gnoroot? string | fun(): string Custom path to GNOROOT. Can be a callbale function to use a different value per-project.

---@param opts GnoNvimOpts|nil
---@return GnoNvimLSPConfig|nil
local function lsp_config_from_opts(opts)
  if not opts then
    return nil
  end

  local lsp_cfg = opts.lsp or {}
  local gnoroot = utils.unwrap_lazy(opts.gnoroot)
  if gnoroot and gnoroot ~= "" then
    local env = lsp_cfg.cmd_env or {}
    env.GNOROOT = gnoroot
    lsp_cfg.cmd_env = env
  end

  return lsp_cfg
end

--- Enables LSP server and formatter.
---
--- See: https://neovim.io/doc/user/lsp.html#vim.lsp.config()
---
--- @param config? GnoNvimOpts
function M.setup(config)
  check_dependencies()

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.gno",
    command = "set filetype=gno",
  })

  vim.treesitter.language.register("go", "gno")
  vim.api.nvim_create_augroup("gno", { clear = true })

  require("gno-nvim.commands").setup(config)
  require("gno-nvim.lsp").setup(lsp_config_from_opts(config))
end

return M
