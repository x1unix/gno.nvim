local M = {}

local job = require "plenary.job"
local utils = require "gno-nvim.utils"

local function gnodoc(opts)
  -- Default: dirname of a current open file.
  local arg = opts.args ~= "" and opts.args or vim.fn.expand("%:p:h")
  local pkgname = opts.args ~= "" and opts.args or vim.fn.fnamemodify(arg, ":t")

  job
    :new({
      command = "gno",
      args = { "doc", arg, "-all" },
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

local function gnofmt()
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

local function gnotest(opts)
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

  local buf = utils.upsert_bottom_panel("GnoTest", "plaintext")
  vim.notify("GnoTest: " .. test_label, vim.log.levels.INFO)

  job
    :new({
      command = "gno",
      args = { "test", "-v", table.unpack(verb) },
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
            vim.notify("gotest: PASS - " .. test_label, vim.log.levels.INFO)
          end
        end)
      end,
    }):start()
end

function M.setup()
  vim.api.nvim_create_user_command(
    "GnoFmt", gnofmt,
    { desc = "Show documentation for a specified package. By default shows documentation for current open directory." }
  )

  vim.api.nvim_create_user_command(
    "GnoDoc", gnodoc,
    { desc = "Format current Gno file", nargs = "*" }
  )

  vim.api.nvim_create_user_command(
    "GnoTest", vim.schedule_wrap(gnotest),
    {
      desc = "Call gno test on package or currently open test file",
      nargs = "*",
    }
  )
end

return M

