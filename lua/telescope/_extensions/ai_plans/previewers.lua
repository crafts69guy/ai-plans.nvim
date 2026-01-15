-- ai-plans.nvim: Previewer module
-- Provides bat-based markdown preview with fallback to default

local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local ap_utils = require("telescope._extensions.ai_plans.utils")
local ap_config = require("telescope._extensions.ai_plans.config")

local M = {}

--- Build bat command arguments for markdown preview
---@param filepath string Path to the file to preview
---@return table Command array for termopen previewer
local function build_bat_command(filepath)
	return {
		"bat",
		"--style=plain", -- Clean output without line numbers/borders
		"--color=always", -- Force ANSI colors for terminal
		"--pager=less -RS", -- Use less pager for scrolling support
		"-l",
		"markdown", -- Explicit language for syntax highlighting
		"--",
		filepath,
	}
end

--- Create bat-based terminal previewer for markdown files
---@return table Telescope termopen previewer
local function create_bat_previewer()
	return previewers.new_termopen_previewer({
		title = "Preview (bat)",

		-- Dynamic title showing the filename
		dyn_title = function(_, entry)
			return entry.filename or vim.fn.fnamemodify(entry.path or entry.value, ":t")
		end,

		-- Build the bat command for each entry
		get_command = function(entry, status)
			local filepath = entry.path or entry.value
			return build_bat_command(filepath)
		end,
	})
end

--- Get the appropriate previewer based on config and tool availability
---@param opts table|nil Options passed to the picker
---@return table Telescope previewer
M.previewer = function(opts)
	opts = opts or {}
	local config = ap_config.get()

	-- Check if bat should be used and is available
	local use_bat = opts.use_bat
	if use_bat == nil then
		use_bat = config.use_bat
	end

	if use_bat and ap_utils.has_bat() then
		return create_bat_previewer()
	end

	-- Fallback to default file previewer
	return conf.file_previewer(opts)
end

return M
