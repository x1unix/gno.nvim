# gno.nvim

Gno language support for NeoVim.

## Features

* Syntax highlighting (uses Go treesitter config).
* Integration with gnopls using LSP.
* Automatic format on save.
* Support for [cmp-nvim-lsp](https://github.com/hrsh7th/cmp-nvim-lsp) (optional).

### Commands

* `:GnoDoc` - Show documentation for a package. Optional second argument is package name.
* `:GnoFmt` - Format current file.
* `:GnoRoot` - Print current gnoroot.
* `:GnoTest` - Run unit test.
    * `:GnoTest` - Test current unit test file or package.
    * `:GnoTest ./package` - Test a specific directory.

## Prerequisites

### NeoVim Plugins

* [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
* Optional:
    - [cmp-nvim-lsp](https://github.com/hrsh7th/cmp-nvim-lsp)

### Command-Line Tools

* Gno Language Server:
    * [gnoverse/gnopls](https://github.com/gnoverse/gnopls) - Based on gopls.
    * [golang/gnopls](https://github.com/gnolang/gnopls/) - Unstable, not recommended.

## Installation

> [!IMPORTANT]
> Ensure that `gnopls` language server is installed and available in `$PATH`.

### vim-plug

```vim
" Prerequisites
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/plenary.nvim'

" The plugin
Plug 'x1unix/gno.nvim'
```

### lazy.nvim

```lua
{
    'x1unix/gno.nvim',
    requires = { 'neovim/nvim-lspconfig', 'nvim-lua/plenary.nvim' },
    config = function()
        require('gno-nvim').setup()
    end,
}
```

## Configuration

Here is a configuration example with defaults:

> [!NOTE]
> For LSP config, please check https://neovim.io/doc/user/lsp.html#vim.lsp.config()

```lua
require('gno-nvim').setup({
    -- Custom GNOROOT path. Can be string or function.
    --
    -- Passed into Gno commands and LSP server environment variable.
    --gnoroot = function()
    --    return os.getenv("GNOROOT")
    --end,

    -- LSP client config
    lsp = {
        -- Path to gnopls server binary.
        cmd = { 'gnopls', 'serve' },

        -- Custom environment variables.
        cmd_env = {
           -- GNOROOT: 'custom env variable', 
        },

        -- By default - integrate with nvim-cmp if installed.
        capabilities = require('cmp_nvim_lsp').default_capabilities()

        filetypes = { 'gno' },
        -- ...
    },
})
```

### Project-Specific GNOROOT

GNOROOT can be configured dynamically per-project.

> [!NOTE]
> GNOROOT for language server is set only once during LSP session startup.

Use `:GnoRoot` command to get current `GNOROOT`.

```lua
local utils = require("gno-nvim.utils")

local gno_fork_path = os.getenv("HOME") .. "/work/gno"

require('gno-nvim').setup({
  gnoroot = function ()
    local cwd = vim.fn.expand("%:p:h")
    if cwd == "" then
      cwd = vim.fn.getcwd()
    end

    -- If inside Gno work repo, use it as a GNOROOT.
    if utils.has_prefix(cwd, gno_fork_path) then
      return gno_fork_path
    end

    -- Use defaults
    return nil
  end,
})
```

