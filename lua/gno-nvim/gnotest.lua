local job = require "plenary.job"
local utils = require "gno-nvim.utils"
local queries = require "gno-nvim.queries"

local M = {}

---@class GnoCmdOpts
---@field gnoroot? string
---@field global_args string[]

---@class GnoTestCtx
---@field is_unit? boolean
---@field file? string
---@field testcase? string
---@field label string
---@field dir string

---@return GnoTestCtx
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
      is_unit = is_unit,
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

local gnotest_buf_type = "gnotest"

---@class GnoTestCommandArgs
---@field args table<string>: List of command line args
---@field label string: Test run operation label
---@field cwd string: Current working dir to run a command.

---Call "gno test" with given parameters and display progress on UI.
---@param opts GnoTestCommandArgs: Command run option.
---@param gno_opts GnoCmdOpts: Global Gno command options.
local function call_gnotest(opts, gno_opts)
  local args = utils.array_concat({ "test", "-v" }, opts.args, gno_opts.global_args)
  vim.notify("GnoTest: " .. opts.label, vim.log.levels.INFO)

  local buf = utils.upsert_bottom_panel("GnoTest", gnotest_buf_type)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "$ gno " .. table.concat(args, " "),
  })

  job
    :new({
      command = "gno",
      args = args,
      cwd = opts.cwd,
      on_stdout = function (_, data)
        vim.schedule(function ()
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { data })
          utils.buf_scroll_to_bottom(buf)
        end)
      end,
      on_stderr = function (_, data)
        vim.schedule(function ()
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { data })
          utils.buf_scroll_to_bottom(buf)
        end)
      end,
      on_exit = function(_, exit_code)
        vim.schedule(function()
          if exit_code ~= 0 then
            vim.notify("GnoTest: FAIL - " .. opts.label, vim.log.levels.ERROR)
          else
            vim.notify("GnoTest: PASS - " .. opts.label, vim.log.levels.INFO)
          end
        end)
      end,
    }):start()
end

local test_all_key = "@TEST_ALL"

---Shows unit tests picker dialog.
---@param ctx GnoTestCtx
---@param gno_opts GnoCmdOpts
---@param opts table<string, any>
local function show_test_picker(ctx, gno_opts, opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

  local options = queries.find_test_cases(bufnr, row)
  if not options or #options == 0 then
      call_gnotest({
        label = ctx.label,
        cwd = ctx.dir,
        args = { ctx.file or "." },
      }, gno_opts)
    return
  end

  table.insert(options, test_all_key)
  vim.ui.select(options,
    {
        prompt = string.format("Select test in %s:", ctx.file),
        format_item = function(item)
          if item == test_all_key then
            return "<Run all tests>"
          end

          return item
        end
    },
    function(choice)
      if not choice then
        -- User selected nothing
        return
      end

      local label = ctx.label
      local args = { ctx.file or "." }

      if choice ~= test_all_key then
        label = choice
        -- Not sure if "gno run" supports regexps.
        args = utils.array_concat(args, { "-run", choice })
      end

      call_gnotest({
        label = label,
        cwd = ctx.dir,
        args = args,
      }, gno_opts)
    end
  )
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
    local ctx = get_test_context()
    cwd = ctx.dir
    verb = { ctx.file or "." }
    test_label = ctx.label

    if ctx.is_unit then
      show_test_picker(ctx, gno_opts, opts)
      return
    end
  end

  call_gnotest({
    label = test_label,
    cwd = cwd,
    args = verb,
  },gno_opts)
end

---@param opts GnoNvimCommandsOpts|nil?
function M.setup(opts)
  -- Setup highlight groups for unit test results
  vim.api.nvim_create_autocmd('ColorScheme', {
    pattern = '*',
    callback = function()
      vim.api.nvim_set_hl(0, 'GoTestSuccess', { fg = '#66cc66' })
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = gnotest_buf_type,
    callback = function(args)
      vim.api.nvim_buf_call(args.buf, function()
        vim.fn.matchadd('Comment', '^\\$ gno test .*')
        vim.fn.matchadd('GoTestSuccess', '^ok\\s.*')

        -- matchadd doesn't support regex groups and optionals.
        vim.fn.matchadd('ErrorMsg', '^FAIL:.*')
        vim.fn.matchadd('ErrorMsg', '^FAIL\\s.*')
        vim.fn.matchadd('ErrorMsg', '^FAIL$')
        vim.fn.matchadd('ErrorMsg', '^--- FAIL:.*')
        vim.fn.matchadd('ErrorMsg', '^[A-Za-z0-9_\\.]*: test pkg: failed:.*')

        -- gno.land/p/demo/uassert support.
        vim.fn.matchadd('ErrorMsg', '^uassert\\.[A-Za-z]*:.*')
        vim.fn.matchadd('ErrorMsg', '^should be .*')
      end)
    end,
  })
end

return M
