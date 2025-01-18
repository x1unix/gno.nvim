local utils = require "gno-nvim.utils"

local M = {}

local lang_name = "go"

---@param val number
---@param min_val number
---@param max_val number
---@return boolean
local function is_in_range(val, min_val, max_val)
  return val >= min_val and val <= max_val
end

---@param node TSNode
local function get_node_lines(node)
  local start_row, _, end_row = node:range()
  return start_row + 1, end_row + 1
end

--- Check whether specified cursor row position is inside a node.
---@param node TSNode
---@param cursor_row_pos number
local function test_node_range(node, cursor_row_pos)
  if not node then
    return false
  end

  local fn_start, fn_end = get_node_lines(node)
  return is_in_range(cursor_row_pos, fn_start, fn_end)
end

---Returns a list of Gno test case functions found in a buffer.
---Function in which cursor is located appears at the top of a list.
---@param bufnr number: Vim buffer number
---@param cur_row number: Cursor row number, used to put a current function under cursor to a top.
---@return table<string> | nil
function M.find_test_cases(bufnr, cur_row)
  local ts = vim.treesitter
  local parser = ts.get_parser(bufnr, lang_name)
  if not parser then
    vim.notify("GnoTest: can't get list of tests as Treesitter parser is missing", vim.log.levels.WARN)
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  print(string.format("Cursor: %d", cur_row))

  local query = ts.query.get(lang_name, 'tests')
  if query == nil then
    vim.notify("GnoTest: failed to get tests Treesitter query", vim.log.levels.ERROR)
    return nil
  end

  -- Map capture indexes to names
  local groups = {}
  for i, label in pairs(query.captures) do
    groups[label] = i
  end

  local result = {}
  local hovered_func_index = -1

  for _, captures, _ in query:iter_matches(root, bufnr) do
    if next(captures) == nil then
      goto continue
    end

    local func_name_node = captures[groups["func_name"]]
    local func_node = captures[groups["func"]]
    local func_name = ts.get_node_text(func_name_node, bufnr)

    table.insert(result, func_name)
    if test_node_range(func_node, cur_row) then
      hovered_func_index = #result
    end

    ::continue::
  end

  -- If test case is under a cursor, put it at the top.
  if hovered_func_index > 1 then
    local shift = (hovered_func_index - 1) * -1
    utils.array_shift(result, shift)
  end

  return result
end


return M
