local utils = require "gno-nvim.utils"

local fn, health, api = vim.fn, vim.health, vim.api
local err = vim.version().minor >= 10 and health.error or health.report_error
local warn = vim.version().minor >= 10 and health.warn or health.report_warn
local ok = vim.version().minor >= 10 and health.ok or health.report_ok
local start = vim.version().minor >= 10 and health.start or health.report_start

local M = {}

---@param name string
---@param isCritical? boolean
---@return boolean
local function check_plugin(name, isCritical)
  local _, hasNvimCmp = utils.safe_require(name)
  if hasNvimCmp then
    ok(string.format("%s: installed", name))
    return true
  end

  if isCritical then
    err(string.format("%s: not installed", name))
    return false
  end

  warn(string.format("%s: not installed", name))
  return false
end

local function treesitter_lang_installed(lang)
  if vim.treesitter.get_parser then
    local success, parser = pcall(vim.treesitter.get_parser, nil, lang)
    return success and parser ~= nil
  end

  -- Pre 0.10 version
  if vim.treesitter.language and vim.treesitter.language.require_language then
    local success, result = pcall(vim.treesitter.language.require_language, lang, nil, true)
    return success and result ~= nil
  end

  return false
end

local function check_treesitter()
  local has_treesitter = check_plugin("nvim-treesitter")
  local has_language = treesitter_lang_installed("go")
  if has_language then
    ok("go syntax: installed")
    return
  end

  if has_treesitter then
    err("go syntax: not installed. Please run `:TSInstall go`")
  else
    err("go syntax: not installed. Please install nvim-treesitter and run `:TSInstall go`")
  end
end

function M.check()
  start('Binaries')
  local gnopls_bin, hasGnopls = utils.locate_gnopls()
  if hasGnopls then
    ok(string.format("gnopls: found at %s", gnopls_bin))
  else
    err("gnopls: not installed")
  end

  local gnobin = vim.fn.exepath("gno")
  if not gnobin or gnobin == "" then
    err("gno: not installed")
  else
    ok(string.format("gno: found at %s", gnobin))
  end

  start('Plugins')
  check_treesitter()
  check_plugin("lspconfig", true)
  check_plugin("plenary", true)
  check_plugin("cmp_nvim_lsp")
end

return M
