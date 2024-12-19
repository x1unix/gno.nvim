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

local function get_test_context()
  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    -- No file open, use work dir as root
    return {
      dir = vim.fn.getcwd(),
      label = vim.fn.getcwd(),
    }
  end

  local is_unit = utils.is_unit_test_file(current_file)
  local is_golden = utils.is_golden_test_file(current_file)
  local dirname = vim.fn.fnamemodify(current_file, ":h")
  if is_unit or is_golden then
    return {
      file = vim.fn.fnamemodify(current_file, ":t"),
      label = vim.fn.fnamemodify(current_file, ":."),
      dir = dirname,
    }
  end

  return {
    dir = dirname,
    label = vim.fn.fnamemodify(dirname, ":."),
  }
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

---@param opts table<string, any>
---@param gno_opts GnoCmdOpts
local function gnotest(opts, gno_opts)
  local cwd
  local verb
  local test_label

  if opts.args ~= "" then
    cwd = vim.fn.getcwd()
    verb = { opts.fargs }
    test_label = verb
  else
    -- TODO: prompt which test to run if inside unit test.
    local ctx = get_test_context()
    cwd = ctx.dir
    verb = { ctx.file or "." }
    test_label = ctx.label
  end

  vim.notify("GnoTest: " .. test_label, vim.log.levels.INFO)
  local args = { "test", "-v", table.unpack(verb), table.unpack(gno_opts.global_args) }
  local buf = utils.upsert_bottom_panel("GnoTest", "plaintext")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "$ gno " .. table.concat(args, " "),
  })

  job
    :new({
      command = "gno",
      args = args,
      cwd = cwd,
      on_stdout = function (_, data)
        vim.schedule(function ()
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { data })
        end)
      end,
      on_stderr = function (_, data)
        vim.schedule(function ()
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { data })
        end)
      end,
      on_exit = function(j, exit_code)
        vim.schedule(function()
          if exit_code ~= 0 then
            vim.notify("GnoTest: FAIL - " .. test_label, vim.log.levels.ERROR)
          else
            vim.notify("GnoTest: PASS - " .. test_label, vim.log.levels.INFO)
          end
        end)
      end,
    }):start()
end

---@class GnoNvimCommandsOpts
---@field gnoroot string|fun():string|nil Optional custom root dir

---@class GnoCmdOpts
---@field gnoroot? string
---@field global_args string[]

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
  vim.api.nvim_create_user_command(
    "GnoFmt", gnofmt,
    { desc = "Format current Gno file" }
  )

  vim.api.nvim_create_user_command(
    "GnoDoc", wrap_cmd_handler(gnodoc, opts),
    { desc ="Show documentation for a specified package. By default shows documentation for current open directory." , nargs = "*" }
  )

  vim.api.nvim_create_user_command(
    "GnoTest", vim.schedule_wrap(wrap_cmd_handler(gnotest, opts)),
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

