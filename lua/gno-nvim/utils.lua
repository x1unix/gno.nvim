local M = {}

M.plugin_name = "gno.nvim"

function M.safe_require(name)
  local status, mod = pcall(require, name)
  return mod, status
end

--- Write log message with plugin name prefix.
--- @param msg string
function M.log_write(msg, level)
  vim.notify(M.plugin_name .. ": " .. msg, level, { title = M.plugin_name })
end

--- Returns GNOROOT from exported environment variable or 'gno env' command.
--- @return string
function M.get_gnoroot()
  local gnoroot = os.getenv "GNOROOT"
  if gnoroot and gnoroot ~= "" then
    return gnoroot
  end

  local gno_bin = vim.fn.exepath "gno"
  if gno_bin == "" then
    print "Error: Can't find Gno"
    return ""
  end

  gnoroot = vim.fn.system(gno_bin .. " env GNOROOT")
  gnoroot = vim.trim(gnoroot)
  return gnoroot
end

--- If value is a function - returns function result.
--- Otherwise, returns a value.
---@generic T
---@param val T | fun(): T
function M.unwrap_lazy(val)
  if type(val) == "function" then
    return val()
  else
    return val
  end
end

--- Checks whether string has a prefix
--- @param str string
--- @param prefix string
--- @return boolean
function M.has_prefix(str, prefix)
    return str:sub(1, #prefix) == prefix
end

--- Checks whether string has a suffix
--- @param str string
--- @param suffix string
--- @return boolean
function M.has_suffix(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
end

--- Checks whether file path corresponds to a Gno golden test file.
--- @return boolean
function M.is_golden_test_file(fname)
  return M.has_suffix(fname, "_filetest.gno")
end

--- Checks whether file path corresponds to a Gno unit test file.
--- @return boolean
function M.is_unit_test_file(fname)
  return M.has_suffix(fname, "_test.gno")
end

local function find_buf_by_name(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- Neovim always appends 'cwd' to buffer name under the hood.
    if vim.api.nvim_buf_is_valid(buf) and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
 == name then
        return buf
    end
  end
  return nil
end

---@class PanelCreateParams
---@field cmd string # Command to spawn a panel
---@field size? number # Custom panel size
---@field syntax? string

--- Creates a new or returns existing vsplit panel below in a current tab.
---
--- If panel with the same name exists - it will be reused.
--- @param name string
--- @param params PanelCreateParams
function M.upsert_panel(name, params)
  -- Append unique suffix based on tab page to prevent collision.
  local id = name .. " [" .. vim.api.nvim_get_current_tabpage() .. "]"
  local buf = find_buf_by_name(id)

  if buf then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    return buf
  end

  vim.cmd("botright " .. params.cmd)
  local win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_name(buf, id)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  if params.syntax then
    vim.bo[buf].filetype = params.syntax
  end

  if params.size then
    vim.api.nvim_win_set_height(win, params.size)
  end

  vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = buf,
      callback = function()
          if #vim.api.nvim_list_wins() == 1 then
              vim.cmd("quit")
          end
      end,
  })
  return buf
end

---Scroll a buffer view to a bottom.
---@param bufnr number
function M.buf_scroll_to_bottom(bufnr)
  -- Copy from: https://github.com/MunifTanjim/nui.nvim/discussions/327
  vim.api.nvim_buf_call(bufnr, function()
    vim.api.nvim_win_set_cursor(0, { vim.fn.line('$'), 1 })
  end)
end

--- Creates a new or returns existing vsplit panel below in a current tab.
---
--- If panel with the same name exists - it will be reused.
--- @param name string
--- @param syntax string
function M.upsert_side_panel(name, syntax)
  return M.upsert_panel(name, {
      syntax = syntax,
      cmd = "vsplit"
    })
end

--- Creates a new or returns existing split panel below in a current tab.
---
--- If panel with the same name exists - it will be reused.
--- @param name string
--- @param syntax string
function M.upsert_bottom_panel(name, syntax)
  return M.upsert_panel(name, {
      syntax = syntax,
      cmd = "split",
      size = 11,
    })
end

--- Automatically finds gopls server in $PATH or $GOPATH.
---@return string, boolean
function M.locate_gnopls()
  local server_bin = "gnopls"
  local bin_path = vim.fn.exepath(server_bin)
  if bin_path and bin_path ~= "" then
    return bin_path, true
  end

  -- gopls might be installed, but $GOPATH/bin not in $PATH
  local gopath = os.getenv "GOPATH"
  if not gopath or gopath == "" then
    local go_bin = vim.fn.exepath "go"
    if not go_bin or go_bin ~= "" then
      return server_bin, false
    end

    gopath = vim.fn.system("go env GOPATH"):gsub("\n", "")
  end

  if not gopath or gopath == "" then
    return server_bin, false
  end

  -- check if server bin actually exists
  bin_path = gopath .. "/bin/" .. server_bin
  local f = io.open(bin_path, "r")
  if not f then
    return server_bin, false
  end

  f:close()
  return bin_path, true
end

---@param list table
---@param i number
---@param j number
local function array_swap(list, i, j)
  while (i < j) do
    list[i], list[j] = list[j], list[i]

    i = i + 1
    j = j - 1
  end
end

--- Shift array items. This is a mutable function!
---@param arr table
---@param offset number
function M.array_shift(arr, offset)
  local n = #arr
  if n == 0 then
    return
  end

  local shift = ((offset % n) + n) % n
  if shift == 0 then
    return
  end

  array_swap(arr, 1, n)
  array_swap(arr, 1, shift)
  array_swap(arr, shift + 1, n)
end

---Concat multiple arrays into one.
---@generic T
---@param ... T[]
---@return T[]
function M.array_concat(...)
  local result = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    for j = 1, #t do
      result[#result + 1] = t[j]
    end
  end

  return result
end

return M
