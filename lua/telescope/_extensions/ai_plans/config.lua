-- ai-plans.nvim: Configuration module
-- Manages plugin settings and default mappings

local config = {}

-- Default configuration values
local defaults = {
	-- AI source paths (expandable by users)
	sources = {
		claude = {
			path = "~/.claude/plans/",
			pattern = "*.md",
			display_name = "Claude",
			icon = "",
		},
	},

	-- External tool preferences
	use_fd = true, -- Use fd if available for file discovery
	use_bat = true, -- Use bat for preview if available
	use_rg = true, -- Use ripgrep for content search if available

	-- UI settings
	theme = nil, -- "dropdown", "ivy", "cursor", or nil for default
	initial_mode = "normal",
	layout_strategy = "horizontal",
	layout_config = {
		preview_width = 0.6,
		width = 0.9,
		height = 0.8,
	},

	-- Preview settings
	preview = {
		filesize_limit = 1, -- MB
		highlight = true,
		treesitter = true,
	},

	-- Sorting
	sorting_strategy = "descending", -- newest first
	sort_by = "mtime", -- "mtime", "name", "size"

	-- Show markdown title in entry display
	show_title = true,

	-- Grep picker settings
	grep_initial_mode = "insert", -- Initial mode for grep picker

	-- Zen popup settings
	zen = {
		enabled = true, -- Use zen popup by default for opening files
		width_ratio = 0.8, -- Popup width as ratio of editor width
		height_ratio = 0.8, -- Popup height as ratio of editor height
		border = "rounded", -- Border style
		title = true, -- Show filename in title
		title_pos = "center", -- Title position: "left", "center", "right"
		close_on_escape = true, -- Close with <Esc> in normal mode
		close_on_q = true, -- Close with q in normal mode
		prompt_save = true, -- Prompt to save if modified when closing
		use_zen_mode = true, -- Use zen-mode.nvim if available
		wo = { -- Window options for zen popup
			wrap = true,
			linebreak = true,
			number = false,
			relativenumber = false,
			signcolumn = "no",
			cursorline = false,
			foldcolumn = "0",
		},
	},
}

-- Current configuration values (will be merged with user opts)
config.values = vim.deepcopy(defaults)

--- Setup function called by telescope.load_extension
---@param opts table|nil User configuration options
config.setup = function(opts)
	opts = opts or {}

	-- Deep merge user options with defaults
	config.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)

	-- Setup default mappings after we have actions available
	config.setup_mappings()
end

--- Setup default key mappings
config.setup_mappings = function()
	local actions = require("telescope.actions")
	local ok, ap_actions = pcall(require, "telescope._extensions.ai_plans.actions")

	if not ok then
		return
	end

	-- Default mappings if not provided by user
	if not config.values.mappings then
		config.values.mappings = {}
	end

	local default_mappings = {
		["i"] = {
			["<Tab>"] = ap_actions.toggle_selection_and_next,
			["<S-Tab>"] = ap_actions.toggle_selection_and_prev,
			["<C-d>"] = actions.preview_scrolling_down,
			["<C-u>"] = actions.preview_scrolling_up,
			["<CR>"] = ap_actions.smart_open,
		},
		["n"] = {
			["<Tab>"] = ap_actions.toggle_selection_and_next,
			["<S-Tab>"] = ap_actions.toggle_selection_and_prev,
			["y"] = ap_actions.yank_paths,
			["Y"] = ap_actions.yank_content,
			["<BS>"] = ap_actions.delete_files,
			["d"] = ap_actions.delete_files,
			["<C-d>"] = actions.preview_scrolling_down,
			["<C-u>"] = actions.preview_scrolling_up,
			["<CR>"] = ap_actions.smart_open,
			["q"] = actions.close,
			["<Esc>"] = actions.close,
			["o"] = ap_actions.open_in_split,
			["v"] = ap_actions.open_in_vsplit,
			["t"] = ap_actions.open_in_tab,
			["r"] = ap_actions.refresh,
			["z"] = ap_actions.open_in_zen, -- Explicit zen open
			["e"] = ap_actions.open_file, -- Explicit regular edit
		},
	}

	-- Merge default mappings with user mappings (user takes precedence)
	for mode, mappings in pairs(default_mappings) do
		if not config.values.mappings[mode] then
			config.values.mappings[mode] = {}
		end
		for key, action in pairs(mappings) do
			if config.values.mappings[mode][key] == nil then
				config.values.mappings[mode][key] = action
			end
		end
	end
end

--- Get current configuration
---@return table Current configuration values
config.get = function()
	return config.values
end

return config
