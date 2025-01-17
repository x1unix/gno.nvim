local M = {}

local job = require "plenary.job"
local utils = require "gno-nvim.utils"

---@param opts table<string, any>
---@param gno_opts GnoCmdOpts
local function gnodoc(opts, gno_opts)
  -- Default: dirname of a current open file.
  local arg = opts.args ~= "" and opts.args or vim.fn.expand("%:p:h")
  local pkgname = opts.args ~= "" and opts.args or vim.fn.fnamemodify(arg, ":t")

  job
    :new({
      command = "gno",
      args = { "doc", arg, "-all", table.unpack(gno_opts.global_args) },
      on_exit = function(j, exit_code)
        if exit_code ~= 0 then
          vim.schedule(function()
            vim.notify("gnodoc returned an error: " .. table.concat(j:stderr_result(), "\n"), vim.log.levels.ERROR, { title = "gnodoc" })
          end)
          return
        end

        vim.schedule(function()
          local buf = utils.upsert_side_panel("GnoDoc", "gno")
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
        end)
      end,
    }):start()
end

---@param _opts table<string, any>
local function gnofmt(_opts)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.buf.format({
    bufnr = bufnr,
    async = false,
  })
end

---@param _opts table<string, any>
---@param gno_opts GnoCmdOpts
local function gnoroot(_opts, gno_opts)
  local msg = "GNOROOT: "
  print(vim.inspect(gno_opts.gnoroot))
  if gno_opts.gnoroot then
    msg = msg .. "Modified - " .. gno_opts.gnoroot
  else
    local r = utils.get_gnoroot()
    msg = msg .. "System - " .. r
  end

  vim.notify(msg, vim.log.levels.INFO)
end

---@class GnoNvimCommandsOpts
---@field gnoroot string|fun():string|nil Optional custom root dir

---Wrap command handler to pass global Gno args and other opts.
---@param handler fun(vim_cmd_opts: table, gno_cmd_opts: GnoCmdOpts)
---@param gno_opts GnoNvimCommandsOpts|nil
---@return fun(table)
local function wrap_cmd_handler(handler, gno_opts)
  return function(opts)
    local cmd_opts = {
      global_args = {},
    }

    if gno_opts then
      local r = utils.unwrap_lazy(gno_opts.gnoroot)
      if r and r ~= "" then
        cmd_opts.global_args = { "-root-dir", r }
        cmd_opts.gnoroot = r
      end
    end

    handler(opts, cmd_opts)
  end
end

---@param opts GnoNvimCommandsOpts|nil?
function M.setup(opts)
  local gnotest = require "gno-nvim.gnotest"

  vim.api.nvim_create_user_command(
    "GnoFmt", gnofmt,
    { desc = "Format current Gno file" }
  )

  vim.api.nvim_create_user_command(
    "GnoDoc", wrap_cmd_handler(gnodoc, opts),
    { desc ="Show documentation for a specified package. By default shows documentation for current open directory." , nargs = "*" }
  )

  vim.api.nvim_create_user_command(
    "GnoTest", vim.schedule_wrap(wrap_cmd_handler(gnotest.run_command, opts)),
    {
      desc = "Call gno test on package or currently open test file",
      nargs = "*",
    }
  )

  vim.api.nvim_create_user_command(
    "GnoRoot", vim.schedule_wrap(wrap_cmd_handler(gnoroot, opts)),
    {
      desc = "Print current GNOROOT",
      nargs = 0,
    }
  )
end

return M

