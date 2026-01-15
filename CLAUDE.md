# CLAUDE.md - AI Assistant Guide for ai-plans.nvim

This file provides context and instructions for AI assistants working on this Neovim plugin.

## Project Overview

**ai-plans.nvim** is a Telescope extension for Neovim that helps users browse, preview, and manage AI-generated markdown plan files (from Claude, ChatGPT, Gemini, etc.).

## Tech Stack

- **Language**: Lua (Neovim Lua API)
- **Framework**: Telescope.nvim extension
- **Dependencies**: telescope.nvim, plenary.nvim
- **Target**: Neovim >= 0.9.0

## Project Structure

```
ai-plans.nvim/
├── lua/telescope/_extensions/
│   ├── ai_plans.lua              # Extension entry point (registration)
│   └── ai_plans/
│       ├── init.lua              # Main picker logic
│       ├── actions.lua           # User actions (yank, delete, open, etc.)
│       ├── config.lua            # Configuration management
│       ├── finders.lua           # File discovery (fd/scandir)
│       ├── make_entry.lua        # Entry display formatting
│       └── utils.lua             # Utility functions
├── plugin/
│   └── ai-plans.lua              # Auto-setup, :AiPlans command
├── README.md                     # User documentation
├── CLAUDE.md                     # This file
└── .gitignore
```

## Key Files Explained

### `lua/telescope/_extensions/ai_plans.lua`

- Entry point for Telescope extension registration
- Exports: `ai_plans` (picker), `actions`, `finders`, `picker`
- Calls `telescope.register_extension()` with setup function

### `lua/telescope/_extensions/ai_plans/config.lua`

- Manages default configuration and user overrides
- Default sources: Claude (`~/.claude/plans/`)
- Handles mappings setup after actions module is loaded

### `lua/telescope/_extensions/ai_plans/actions.lua`

- Custom Telescope actions using `transform_mod`
- Key actions: `yank_paths`, `delete_files`, `open_file`, `refresh`
- Multi-select aware via `get_selected_entries()`

### `lua/telescope/_extensions/ai_plans/finders.lua`

- File discovery using `fd` (if available) or `plenary.scandir`
- Collects files from all configured sources
- Sorts by mtime/name/size based on config

### `lua/telescope/_extensions/ai_plans/make_entry.lua`

- Formats entries for Telescope display
- Shows: source icon, date, size, title/filename
- Extracts markdown titles for better UX

### `lua/telescope/_extensions/ai_plans/utils.lua`

- Tool detection (fd, rg, bat)
- Path utilities, file stats
- Markdown title extraction

## Common Development Tasks

### Adding a New Action

1. Add function to `actions.lua`:

```lua
M.new_action = function(prompt_bufnr)
  local entries = get_selected_entries(prompt_bufnr)
  -- Implementation
end
```

1. Add to default mappings in `config.lua`:

```lua
["n"] = {
  ["<key>"] = ap_actions.new_action,
}
```

### Adding a New Configuration Option

1. Add default value in `config.lua` defaults table
2. Use in relevant module via `config.values.option_name`
3. Document in README.md

### Adding a New Source Type

Sources are just paths with metadata. Add to config:

```lua
sources = {
  new_source = {
    path = "~/path/",
    pattern = "*.md",
    icon = "",
    display_name = "New Source",
  },
}
```

## Testing

### Manual Testing

```bash
# Check syntax
nvim --headless -c "luafile lua/telescope/_extensions/ai_plans.lua" -c "q"

# Test module loading
nvim --headless -c "lua require('telescope').load_extension('ai_plans')" -c "q"

# Open picker
nvim -c "Telescope ai_plans"
```

### In Neovim

```vim
:Telescope ai_plans
:AiPlans
:lua require("telescope").extensions.ai_plans.ai_plans()
```

## Code Style

- Use LuaDoc annotations (`---@param`, `---@return`)
- Local functions for internal helpers
- Module pattern: `local M = {} ... return M`
- Error handling with `pcall()` for external dependencies
- Notifications via `utils.notify()` with appropriate log levels

## Telescope Extension Patterns

### Registration Pattern

```lua
return telescope.register_extension({
  setup = config.setup,  -- Called with user opts
  exports = {
    picker_name = picker_function,
    actions = actions_module,
  },
})
```

### Action Pattern

```lua
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local transform_mod = require("telescope.actions.mt").transform_mod

local M = {}
M.action = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  -- Do something
  actions.close(prompt_bufnr)
end
return transform_mod(M)
```

### Finder Pattern

```lua
local finders = require("telescope.finders")
return finders.new_table({
  results = data,
  entry_maker = function(item)
    return {
      value = item,
      display = make_display,
      ordinal = searchable_string,
    }
  end,
})
```

## Important Notes

- The `vim` global is provided by Neovim runtime (ignore LSP warnings)
- Always use `vim.fn.expand()` for paths with `~`
- Use `vim.fn.fnameescape()` when passing paths to vim commands
- Multi-select uses `picker:get_multi_selection()`
- Refresh picker with `picker:refresh(new_finder, opts)`

## Related Resources

- [Telescope.nvim docs](https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md)
- [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope-file-browser.nvim](https://github.com/nvim-telescope/telescope-file-browser.nvim) - Reference implementation

## Local Development Setup

The plugin is configured in the user's Neovim at:
`~/.config/nvim/lua/plugins/ai-plans.lua`

Using `dir = "~/Developments/ai-plans.nvim"` for local development.
