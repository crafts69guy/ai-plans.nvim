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

--- Build bat command for grep preview with line highlighting
---@param filepath string Path to the file
---@param lnum number Line number to highlight
---@return table Command array for termopen previewer
local function build_bat_grep_command(filepath, lnum)
	local start_line = math.max(1, lnum - 10)
	return {
		"bat",
		"--style=plain,numbers", -- Show line numbers for context
		"--color=always",
		"--pager=never", -- No pager needed in preview
		"--highlight-line=" .. tostring(lnum), -- Highlight matched line
		"--line-range=" .. tostring(start_line) .. ":", -- Start from context
		"-l",
		"markdown",
		"--",
		filepath,
	}
end

--- Create bat-based grep previewer (better highlighting, no Telescope scroll)
---@return table Telescope termopen previewer
local function create_bat_grep_previewer()
	return previewers.new_termopen_previewer({
		title = "Preview (bat)",

		dyn_title = function(_, entry)
			local filename = entry.filename or vim.fn.fnamemodify(entry.path or entry.value, ":t")
			return entry.lnum and (filename .. ":" .. entry.lnum) or filename
		end,

		get_command = function(entry)
			local filepath = entry.path or entry.value
			local lnum = entry.lnum or 1
			return build_bat_grep_command(filepath, lnum)
		end,
	})
end

--- Create buffer-based grep previewer (scroll support, treesitter highlighting)
---@return table Telescope buffer previewer
local function create_buffer_grep_previewer()
	return previewers.new_buffer_previewer({
		title = "Preview",

		dyn_title = function(_, entry)
			local filename = entry.filename or vim.fn.fnamemodify(entry.path or entry.value, ":t")
			if entry.lnum then
				return filename .. ":" .. entry.lnum
			end
			return filename
		end,

		define_preview = function(self, entry, status)
			local filepath = entry.path or entry.value
			local lnum = entry.lnum or 1

			-- Read and display file with syntax highlighting
			conf.buffer_previewer_maker(filepath, self.state.bufnr, {
				bufname = self.state.bufname,
				winid = self.state.winid,
				callback = function(bufnr)
					-- Scroll to matched line and highlight it
					vim.schedule(function()
						if
							vim.api.nvim_buf_is_valid(bufnr)
							and self.state.winid
							and vim.api.nvim_win_is_valid(self.state.winid)
						then
							-- Set cursor to matched line
							local line_count = vim.api.nvim_buf_line_count(bufnr)
							local target_line = math.min(lnum, line_count)
							pcall(vim.api.nvim_win_set_cursor, self.state.winid, { target_line, 0 })

							-- Center the line in view
							vim.api.nvim_win_call(self.state.winid, function()
								vim.cmd("normal! zz")
							end)

							-- Highlight the matched line
							local ns = vim.api.nvim_create_namespace("ai_plans_grep_hl")
							vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
							if target_line <= line_count then
								vim.api.nvim_buf_add_highlight(bufnr, ns, "Visual", target_line - 1, 0, -1)
							end
						end
					end)
				end,
			})
		end,
	})
end

--- Create grep-specific previewer based on config
--- - use_bat = true: Bat preview with syntax highlighting and line highlight (no Telescope scroll)
--- - use_bat = false: Buffer preview with treesitter and full scroll support
---@param opts table|nil Options
---@return table Telescope previewer
M.grep_previewer = function(opts)
	opts = opts or {}
	local config = ap_config.get()

	-- Check if bat should be used and is available
	local use_bat = opts.use_bat
	if use_bat == nil then
		use_bat = config.use_bat
	end

	if use_bat and ap_utils.has_bat() then
		return create_bat_grep_previewer()
	end

	-- Fallback to buffer previewer with scroll support
	return create_buffer_grep_previewer()
end

return M
