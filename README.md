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
* `:GnoTest` - Run unit test.
    * `:GnoTest` - Test current directory or unit test file (if currently open).
    * `:GnoTest ./package` - Test a specific directory.

## Prerequisites

### NeoVim Plugins

* [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
* Optional:
    - [cmp-nvim-lsp](https://github.com/hrsh7th/cmp-nvim-lsp)

### Command-Line Tools

* [gnopls](https://github.com/gnolang/gnopls/) - Language server

## Installation

### Prerequisites

```bash
go install github.com/gnolang/gnopls@latest
```

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
> Please check https://neovim.io/doc/user/lsp.html#vim.lsp.config()

```lua
require('gno-nvim').setup({
    -- Path to gnopls server binary.
    cmd = { 'gnopls', 'serve' },

    -- Custom environment variables.
    cmd_env = {
       -- GNOROOT: 'your custom GNOROOT path', 
    },

    -- By default - integrate with nvim-cmp if installed.
    capabilities = require('cmp_nvim_lsp').default_capabilities()

    filetypes = { 'gno' },
    -- ...
})
```
