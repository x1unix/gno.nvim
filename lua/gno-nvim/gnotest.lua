local job = require "plenary.job"
local utils = require "gno-nvim.utils"

local M = {}

---@class GnoCmdOpts
---@field gnoroot? string
---@field global_args string[]

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

---@param opts table<string, any>
---@param gno_opts GnoCmdOpts
function M.run_command(opts, gno_opts)
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


return M
