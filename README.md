# ai-plans.nvim

A Telescope extension for browsing, previewing, and managing AI-generated plan files (Claude, ChatGPT, etc.).

## Features

- **Fuzzy search** through all AI plan markdown files
- **Preview pane** with syntax highlighting
- **Multi-select** files with Tab
- **Yank paths** to clipboard
- **Delete files** with confirmation
- **Configurable sources** - add Claude, ChatGPT, Gemini, or any custom paths
- **Smart sorting** by modification time, name, or size
- **Markdown title extraction** - shows plan titles instead of filenames

## Requirements

- Neovim >= 0.9.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Optional (for better performance)

- [fd](https://github.com/sharkdp/fd) - faster file discovery
- [bat](https://github.com/sharkdp/bat) - better preview highlighting

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/ai-plans.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  keys = {
    { "<C-A-p>", "<cmd>Telescope ai_plans<cr>", desc = "AI Plans" },
  },
  opts = {
    sources = {
      claude = {
        path = "~/.claude/plans/",
        icon = "",
      },
    },
  },
  config = function(_, opts)
    require("telescope").setup({
      extensions = {
        ai_plans = opts,
      },
    })
    require("telescope").load_extension("ai_plans")
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/ai-plans.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("telescope").setup({
      extensions = {
        ai_plans = {
          sources = {
            claude = { path = "~/.claude/plans/", icon = "" },
          },
        },
      },
    })
    require("telescope").load_extension("ai_plans")
  end,
}
```

## Usage

### Commands

```vim
:Telescope ai_plans      " Open the picker
:AiPlans                 " Alternative command
:AiPlans claude          " Filter by source (if multiple configured)
```

### Default Keybindings

#### In Normal Mode (inside picker)

| Key            | Action                                    |
| -------------- | ----------------------------------------- |
| `<Tab>`        | Toggle selection and move to next         |
| `<S-Tab>`      | Toggle selection and move to previous     |
| `y`            | Yank selected file path(s) to clipboard   |
| `<BS>` or `d`  | Delete selected file(s) with confirmation |
| `<CR>`         | Open file in current window               |
| `o`            | Open file in horizontal split             |
| `v`            | Open file in vertical split               |
| `t`            | Open file in new tab                      |
| `<C-d>`        | Scroll preview down                       |
| `<C-u>`        | Scroll preview up                         |
| `r`            | Refresh the file list                     |
| `q` or `<Esc>` | Close picker                              |

#### In Insert Mode (inside picker)

| Key       | Action                                |
| --------- | ------------------------------------- |
| `<Tab>`   | Toggle selection and move to next     |
| `<S-Tab>` | Toggle selection and move to previous |
| `<C-d>`   | Scroll preview down                   |
| `<C-u>`   | Scroll preview up                     |
| `<CR>`    | Open file                             |

## Configuration

### Full Configuration Example

```lua
require("telescope").setup({
  extensions = {
    ai_plans = {
      -- AI source paths
      sources = {
        claude = {
          path = "~/.claude/plans/",
          pattern = "*.md",
          display_name = "Claude",
          icon = "",
        },
        chatgpt = {
          path = "~/Documents/ChatGPT/",
          pattern = "*.md",
          display_name = "ChatGPT",
          icon = "",
        },
        gemini = {
          path = "~/Documents/Gemini/",
          pattern = "*.md",
          display_name = "Gemini",
          icon = "",
        },
      },

      -- External tools (auto-detected)
      use_fd = true,   -- Use fd for faster file discovery
      use_bat = true,  -- Use bat for preview if available

      -- UI settings
      theme = "dropdown",  -- "dropdown", "ivy", "cursor", or nil
      initial_mode = "normal",
      layout_strategy = "horizontal",
      layout_config = {
        preview_width = 0.6,
        width = 0.9,
        height = 0.8,
      },

      -- Sorting
      sort_by = "mtime",  -- "mtime" (newest first), "name", "size"

      -- Display
      show_title = true,  -- Extract and show markdown titles

      -- Custom mappings (optional - extends defaults)
      mappings = {
        n = {
          ["<C-x>"] = function(prompt_bufnr)
            -- Custom action
          end,
        },
      },
    },
  },
})
```

### Adding Custom Sources

You can add any directory as a source:

```lua
sources = {
  -- Work projects
  work_plans = {
    path = "~/Work/plans/",
    icon = "",
    display_name = "Work",
  },
  -- Personal notes
  notes = {
    path = "~/Notes/ai-conversations/",
    icon = "",
    display_name = "Notes",
  },
}
```

## API

### Lua API

```lua
-- Open picker
require("telescope").extensions.ai_plans.ai_plans()

-- Open with custom options
require("telescope").extensions.ai_plans.ai_plans({
  sort_by = "name",
  theme = "ivy",
})

-- Access actions programmatically
local actions = require("telescope").extensions.ai_plans.actions
```

### Available Actions

```lua
local actions = require("telescope._extensions.ai_plans.actions")

actions.yank_paths(prompt_bufnr)           -- Yank paths to clipboard
actions.delete_files(prompt_bufnr)         -- Delete with confirmation
actions.toggle_selection_and_next(prompt_bufnr)
actions.toggle_selection_and_prev(prompt_bufnr)
actions.open_file(prompt_bufnr)            -- Open in current window
actions.open_in_split(prompt_bufnr)        -- Open in horizontal split
actions.open_in_vsplit(prompt_bufnr)       -- Open in vertical split
actions.open_in_tab(prompt_bufnr)          -- Open in new tab
actions.refresh(prompt_bufnr)              -- Refresh file list
```

## Integration with sidekick.nvim

If you use [sidekick.nvim](https://github.com/folke/sidekick.nvim), add a keybinding in the `<leader>a` group:

```lua
keys = {
  { "<leader>aP", "<cmd>Telescope ai_plans<cr>", desc = "Browse AI Plans" },
}
```

## Troubleshooting

### Plans not showing up

1. Check the source path exists: `:lua print(vim.fn.isdirectory(vim.fn.expand("~/.claude/plans/")))`
2. Verify there are `.md` files in the directory
3. Try with `warn_missing = true` in opts to see warnings

### Extension not loading

1. Ensure telescope.nvim is installed and working
2. Check `:Telescope` shows available pickers
3. Run `:lua require("telescope").load_extension("ai_plans")`

### Performance issues

- Install `fd` for faster file discovery
- Set `show_title = false` to skip markdown parsing

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
