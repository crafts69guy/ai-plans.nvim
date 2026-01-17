-- ai-plans.nvim: Zen popup module
-- Distraction-free floating window for editing AI plan files

local ap_utils = require("telescope._extensions.ai_plans.utils")

local M = {}

-- State tracking for zen window
local zen_state = {
	bufnr = nil,
	winid = nil,
	original_winid = nil,
	autocmd_group = nil,
}

--- Calculate window dimensions from ratios
---@param opts table Configuration options with width_ratio and height_ratio
---@return table { width, height, row, col }
local function calculate_dimensions(opts)
	local width_ratio = opts.width_ratio or 0.8
	local height_ratio = opts.height_ratio or 0.8

	local editor_width = vim.o.columns
	local editor_height = vim.o.lines - vim.o.cmdheight

	local width = math.floor(editor_width * width_ratio)
	local height = math.floor(editor_height * height_ratio)

	-- Center the window
	local row = math.floor((editor_height - height) / 2)
	local col = math.floor((editor_width - width) / 2)

	return {
		width = width,
		height = height,
		row = row,
		col = col,
	}
end

--- Build nvim_open_win options
---@param filepath string Path to the file being opened
---@param opts table Configuration options
---@return table Window options for nvim_open_win
local function create_float_opts(filepath, opts)
	local dims = calculate_dimensions(opts)

	local float_opts = {
		relative = "editor",
		width = dims.width,
		height = dims.height,
		row = dims.row,
		col = dims.col,
		style = "minimal",
		border = opts.border or "rounded",
	}

	-- Add title with filename if enabled
	if opts.title ~= false then
		local filename = vim.fn.fnamemodify(filepath, ":t")
		float_opts.title = " " .. filename .. " "
		float_opts.title_pos = opts.title_pos or "center"
	end

	return float_opts
end

--- Apply window options for zen mode
---@param winid number Window ID
---@param opts table Configuration options
local function apply_window_options(winid, opts)
	local wo = opts.wo or {}

	-- Default zen window options
	local default_wo = {
		wrap = true,
		linebreak = true,
		number = false,
		relativenumber = false,
		signcolumn = "no",
		cursorline = false,
		foldcolumn = "0",
	}

	-- Merge with user options
	local final_wo = vim.tbl_extend("force", default_wo, wo)

	-- Apply options
	for option, value in pairs(final_wo) do
		vim.api.nvim_set_option_value(option, value, { win = winid })
	end
end

--- Prompt user to save changes if buffer is modified
---@param bufnr number Buffer number
---@return boolean true if should proceed with close, false if cancelled
local function prompt_save_changes(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return true
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")

	-- Show save dialog
	local choice = vim.fn.confirm(string.format('Save changes to "%s"?', filename), "&Yes\n&No\n&Cancel", 1, "Question")

	if choice == 1 then
		-- Yes: save and close
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("write")
		end)
		return true
	elseif choice == 2 then
		-- No: discard changes and close
		vim.bo[bufnr].modified = false
		return true
	else
		-- Cancel: don't close
		return false
	end
end

--- Setup keymaps for zen window
---@param bufnr number Buffer number
---@param opts table Configuration options
local function setup_keymaps(bufnr, opts)
	local keymap_opts = { buffer = bufnr, noremap = true, silent = true }

	-- Close on q (normal mode)
	if opts.close_on_q ~= false then
		vim.keymap.set("n", "q", function()
			M.close()
		end, keymap_opts)
	end

	-- Close on <Esc> (normal mode)
	if opts.close_on_escape ~= false then
		vim.keymap.set("n", "<Esc>", function()
			M.close()
		end, keymap_opts)
	end
end

--- Cleanup zen state and autocmds
local function cleanup()
	-- Clear autocmds
	if zen_state.autocmd_group then
		pcall(vim.api.nvim_del_augroup_by_id, zen_state.autocmd_group)
	end

	-- Restore focus to original window if it still exists
	if zen_state.original_winid and vim.api.nvim_win_is_valid(zen_state.original_winid) then
		pcall(vim.api.nvim_set_current_win, zen_state.original_winid)
	end

	-- Reset state
	zen_state = {
		bufnr = nil,
		winid = nil,
		original_winid = nil,
		autocmd_group = nil,
	}
end

--- Try to activate zen-mode.nvim if available and enabled
---@param opts table Configuration options
local function try_activate_zen_mode(opts)
	if opts.use_zen_mode == false then
		return
	end

	local ok, zen_mode = pcall(require, "zen-mode")
	if ok and zen_mode then
		-- zen-mode.nvim is available, but it works on the current window
		-- We need to be in the floating window first
		pcall(function()
			zen_mode.open()
		end)
	end
end

--- Check if zen window is currently open
---@return boolean
M.is_open = function()
	return zen_state.winid ~= nil and vim.api.nvim_win_is_valid(zen_state.winid)
end

--- Close the zen popup window
M.close = function()
	if not M.is_open() then
		return
	end

	local config = require("telescope._extensions.ai_plans.config")
	local opts = config.values.zen or {}

	-- Prompt to save changes if enabled
	if opts.prompt_save ~= false and zen_state.bufnr then
		local should_close = prompt_save_changes(zen_state.bufnr)
		if not should_close then
			return
		end
	end

	-- Close the window
	if zen_state.winid and vim.api.nvim_win_is_valid(zen_state.winid) then
		pcall(vim.api.nvim_win_close, zen_state.winid, true)
	end

	cleanup()
end

--- Open a file in the zen popup
---@param filepath string Path to the file to open
---@param opts table|nil Configuration options
M.open = function(filepath, opts)
	-- Close existing zen window if open
	if M.is_open() then
		M.close()
	end

	local config = require("telescope._extensions.ai_plans.config")
	opts = vim.tbl_deep_extend("force", config.values.zen or {}, opts or {})

	-- Store original window
	zen_state.original_winid = vim.api.nvim_get_current_win()

	-- Expand path
	filepath = vim.fn.expand(filepath)

	-- Create float options
	local float_opts = create_float_opts(filepath, opts)

	-- Create the floating window with a scratch buffer first
	local scratch_buf = vim.api.nvim_create_buf(false, true)
	zen_state.winid = vim.api.nvim_open_win(scratch_buf, true, float_opts)

	-- Now edit the file in this window
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))
	zen_state.bufnr = vim.api.nvim_get_current_buf()

	-- Clean up scratch buffer if different
	if scratch_buf ~= zen_state.bufnr and vim.api.nvim_buf_is_valid(scratch_buf) then
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end

	-- Apply window options
	apply_window_options(zen_state.winid, opts)

	-- Setup keymaps
	setup_keymaps(zen_state.bufnr, opts)

	-- Create autocmd group for cleanup
	zen_state.autocmd_group = vim.api.nvim_create_augroup("AiPlansZen", { clear = true })

	-- Handle window close (external close or :q)
	vim.api.nvim_create_autocmd("WinClosed", {
		group = zen_state.autocmd_group,
		pattern = tostring(zen_state.winid),
		callback = function()
			cleanup()
		end,
	})

	-- Handle window resize
	vim.api.nvim_create_autocmd("VimResized", {
		group = zen_state.autocmd_group,
		callback = function()
			if M.is_open() then
				local new_dims = calculate_dimensions(opts)
				vim.api.nvim_win_set_config(zen_state.winid, {
					relative = "editor",
					width = new_dims.width,
					height = new_dims.height,
					row = new_dims.row,
					col = new_dims.col,
				})
			end
		end,
	})

	-- Try to activate zen-mode.nvim if available
	try_activate_zen_mode(opts)

	ap_utils.notify("Opened in zen mode (q or <Esc> to close)")
end

--- Try to enable render-markdown.nvim for the buffer
---@param bufnr number Buffer number
---@return boolean success True if render-markdown was enabled
local function try_enable_render_markdown(bufnr)
	local ok, render_md = pcall(require, "render-markdown")
	if ok and render_md then
		-- render-markdown.nvim should auto-attach to markdown buffers
		-- but we can ensure it's enabled
		pcall(function()
			render_md.enable()
		end)
		return true
	end
	return false
end

--- Open a file in zen preview (read-only, rendered like Obsidian)
---@param filepath string Path to the file
---@param opts table|nil Configuration options
M.preview = function(filepath, opts)
	-- Close existing zen window if open
	if M.is_open() then
		M.close()
	end

	local config = require("telescope._extensions.ai_plans.config")
	opts = vim.tbl_deep_extend("force", config.values.zen or {}, opts or {})

	-- Store original window
	zen_state.original_winid = vim.api.nvim_get_current_win()

	-- Expand path
	filepath = vim.fn.expand(filepath)

	-- Create float options
	local float_opts = create_float_opts(filepath, opts)

	-- Add "Preview" indicator to title
	if float_opts.title then
		float_opts.title = " " .. vim.fn.fnamemodify(filepath, ":t") .. " [Preview] "
	end

	-- Create the floating window with a scratch buffer first
	local scratch_buf = vim.api.nvim_create_buf(false, true)
	zen_state.winid = vim.api.nvim_open_win(scratch_buf, true, float_opts)

	-- Now edit the file in this window
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))
	zen_state.bufnr = vim.api.nvim_get_current_buf()

	-- Clean up scratch buffer if different
	if scratch_buf ~= zen_state.bufnr and vim.api.nvim_buf_is_valid(scratch_buf) then
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end

	-- Set buffer as read-only
	vim.bo[zen_state.bufnr].modifiable = false
	vim.bo[zen_state.bufnr].readonly = true

	-- Apply window options
	apply_window_options(zen_state.winid, opts)

	-- Setup keymaps (close only, no save prompt needed)
	local keymap_opts = { buffer = zen_state.bufnr, noremap = true, silent = true }

	-- Close on q (normal mode)
	vim.keymap.set("n", "q", function()
		-- Bypass save prompt for preview mode
		if zen_state.winid and vim.api.nvim_win_is_valid(zen_state.winid) then
			pcall(vim.api.nvim_win_close, zen_state.winid, true)
		end
		cleanup()
	end, keymap_opts)

	-- Close on <Esc> (normal mode)
	vim.keymap.set("n", "<Esc>", function()
		if zen_state.winid and vim.api.nvim_win_is_valid(zen_state.winid) then
			pcall(vim.api.nvim_win_close, zen_state.winid, true)
		end
		cleanup()
	end, keymap_opts)

	-- Create autocmd group for cleanup
	zen_state.autocmd_group = vim.api.nvim_create_augroup("AiPlansZenPreview", { clear = true })

	-- Handle window close (external close or :q)
	vim.api.nvim_create_autocmd("WinClosed", {
		group = zen_state.autocmd_group,
		pattern = tostring(zen_state.winid),
		callback = function()
			cleanup()
		end,
	})

	-- Handle window resize
	vim.api.nvim_create_autocmd("VimResized", {
		group = zen_state.autocmd_group,
		callback = function()
			if M.is_open() then
				local new_dims = calculate_dimensions(opts)
				vim.api.nvim_win_set_config(zen_state.winid, {
					relative = "editor",
					width = new_dims.width,
					height = new_dims.height,
					row = new_dims.row,
					col = new_dims.col,
				})
			end
		end,
	})

	-- Try to enable render-markdown.nvim for nice rendering
	vim.schedule(function()
		if M.is_open() and zen_state.bufnr and vim.api.nvim_buf_is_valid(zen_state.bufnr) then
			try_enable_render_markdown(zen_state.bufnr)
		end
	end)

	ap_utils.notify("Preview mode (read-only, q or <Esc> to close)")
end

--- Open a file in the zen popup at a specific line
---@param filepath string Path to the file to open
---@param lnum number|nil Line number (1-based)
---@param col number|nil Column number (1-based)
---@param opts table|nil Configuration options
M.open_at_line = function(filepath, lnum, col, opts)
	-- Open the file first
	M.open(filepath, opts)

	-- Set cursor position if we have a valid line number
	if lnum and lnum > 0 and M.is_open() then
		vim.schedule(function()
			if M.is_open() then
				local line = math.max(1, lnum)
				local column = math.max(0, (col or 1) - 1)

				-- Get buffer line count to ensure we don't go past end
				local line_count = vim.api.nvim_buf_line_count(zen_state.bufnr)
				line = math.min(line, line_count)

				pcall(vim.api.nvim_win_set_cursor, zen_state.winid, { line, column })

				-- Center the view on the cursor
				vim.api.nvim_win_call(zen_state.winid, function()
					vim.cmd("normal! zz")
				end)
			end
		end)
	end
end

return M
