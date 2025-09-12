# correctme.nvim

A Neovim plugin for grammar checking and text correction using multiple LLM providers.

## Features

- **Multi-provider support**: OpenAI GPT, Anthropic Claude, and Ollama
- **Interactive diff modes**: 
  - Buffer preview: Before/after comparison in a separate buffer
  - Inline preview: Gitsigns-style inline diff with virtual text
- **Smart caching**: Avoid redundant API calls for unchanged text
- **Real-time diagnostics**: Grammar issues displayed as vim diagnostics
- **Multiple rewrite styles**: Proofread, rephrase, professional, friendly, emojify, elaborate, shorten
- **Synonym suggestions**: Find alternative words for better expression

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "caddyglow/correctme.nvim",
  dependencies = {
    "lewis6991/gitsigns.nvim", -- Optional: for enhanced diff preview
  },
  config = function()
    require("correctme").setup({
      -- Optional configuration
      provider = "local-ollama", -- or "gpt-3.5", "gpt-4", "claude-haiku", "claude-sonnet"
    })
  end
}
```

### LazyVim Configuration

For LazyVim users, add this to your `lua/plugins/correctme.lua`:

```lua
return {
  -- "caddyglow/correctme.nvim",
  dir = "~/projects-caddy/correctme.nvim",
  lazy = true,
  config = function()
    require("correctme").setup({
      provider = "claude-haiku",
    })
    -- Add to your existing lualine config (or create one)
    local ok, lualine = pcall(require, "lualine")
    if ok then
      local config = lualine.get_config()
      table.insert(config.sections.lualine_x, 1, function()
        return require("correctme").statusline()
      end)
      lualine.setup(config)
    end
  end,
  keys = {
    { "<leader>ac", "<cmd>LLMStartChecking<cr>", desc = "Start LLM checking" },
    { "<leader>as", "<cmd>LLMStopChecking<cr>", desc = "Stop LLM checking" },
    { "<leader>ad", "<cmd>LLMCheckDocument<cr>", desc = "Check document once" },
    { "<leader>ai", "<cmd>LLMCheckDocumentDiff<cr>", desc = "Interactive document check" },
    { "<leader>ar", "<cmd>LLMRewrite<cr>", mode = "v", desc = "Rewrite selection" },
    { "<leader>ay", "<cmd>LLMSynonyms<cr>", desc = "Get synonyms" },
    { "<leader>aa", "<cmd>LLMAccept<cr>", desc = "Accept LLM suggestion" },
  },
}
```
[![test](./lua/correctme/diagnostics.lua) ]
## Quick Start

1. Set up your API keys (if not using Ollama):
   ```bash
   export OPENAI_API_KEY="your-key-here"
   export ANTHROPIC_API_KEY="your-key-here"
   ```

2. Check your document for grammar issues:
   ```vim
   :LLMCheckDocument
   ```

3. Use interactive diff mode for reviewing suggestions:
   ```vim
   :LLMCheckDocumentDiff
   ```

## Commands

- `:LLMCheckDocument` - Check entire document and show diagnostics
- `:LLMCheckDocumentDiff` - Interactive diff mode for reviewing suggestions
- `:LLMRewrite` - Rewrite selected text for better clarity
- `:LLMSynonyms` - Get synonyms for word under cursor
- `:LLMAccept` - Accept grammar suggestion at cursor

## Default Models

The plugin comes preconfigured with the following models:

- **local-ollama**: `llama3.2:3b` (default)
- **gpt-3.5**: `gpt-3.5-turbo`
- **gpt-4**: `gpt-4`
- **gpt-4o**: `gpt-4o`
- **claude-haiku**: `claude-3-5-haiku-20241022`
- **claude-sonnet**: `claude-sonnet-4-20250514`

## Configuration

```lua
require("correctme").setup({
  provider = "local-ollama", -- Default provider
  preview_mode = "inline", -- "buffer" or "inline" 
  providers = {
    ["local-ollama"] = {
      type = "ollama",
      model = "llama3.2:3b",
      base_url = "http://localhost:11434",
    },
    ["gpt-4"] = {
      type = "openai",
      model = "gpt-4",
      max_tokens = 2000,
    },
    -- Add more providers as needed
  },
  prompts = {
    proofreading = [[Custom proofreading prompt...]],
    rewrite = [[Custom rewrite prompt...]],
  },
})
```

### Preview Modes

- **Buffer Preview** (`preview_mode = "buffer"`): Shows before/after comparison in a separate buffer
- **Inline Preview** (`preview_mode = "inline"`): Shows changes directly in buffer using gitsigns-style virtual text

Toggle between modes: `:LLMTogglePreview`
Set mode explicitly: `:LLMSetPreview inline` or `:LLMSetPreview buffer`

## Key Bindings (Suggested)

```lua
vim.keymap.set('n', '<leader>cc', ':LLMCheckDocument<CR>')
vim.keymap.set('n', '<leader>cd', ':LLMCheckDocumentDiff<CR>')
vim.keymap.set('v', '<leader>cr', ':LLMRewrite<CR>')
vim.keymap.set('n', '<leader>cs', ':LLMSynonyms<CR>')
vim.keymap.set('n', '<leader>ca', ':LLMAccept<CR>')
```

## Interactive Diff Mode

When using `:LLMCheckDocumentDiff`, navigate through suggestions with:
- `y` - Accept current suggestion
- `n` - Skip current suggestion  
- `q` or `<Esc>` - Exit diff mode

## Requirements

- Neovim >= 0.8.0
- curl
- API access to your chosen LLM provider (OpenAI, Anthropic) or local Ollama setup
