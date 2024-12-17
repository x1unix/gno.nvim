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

  gnoroot = vim.fn.system(gno_bin .. "env GNOROOT")
  gnoroot = vim.trim(gnoroot)
  return gnoroot
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

return M
