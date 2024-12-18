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

  require("gno-nvim.commands").setup()
  require("gno-nvim.lsp").setup(config)
end

return M
