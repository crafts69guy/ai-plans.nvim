-- ai-plans.nvim: Entry maker module
-- Formats file entries for telescope display

local entry_display = require("telescope.pickers.entry_display")
local ap_utils = require("telescope._extensions.ai_plans.utils")

local M = {}

--- Generate entry maker function for file entries
---@param opts table Options
---@return function Entry maker function
M.gen_from_file = function(opts)
	opts = opts or {}
	local config = require("telescope._extensions.ai_plans.config")
	local show_title = opts.show_title ~= nil and opts.show_title or config.values.show_title

	-- Create display layout with fixed widths for single-row rendering
	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = 10 }, -- Source name [Claude]
			{ width = 2 }, -- Source icon
			{ width = 50 }, -- Filename/Title (fixed width, truncated if needed)
			{ width = 16 }, -- Date
			{ width = 7 }, -- Size
		},
	})

	--- Format entry for display
	---@param entry table Entry to format
	---@return table Display items
	local make_display = function(entry)
		local source_name = entry.source_config and entry.source_config.display_name or entry.source or "Unknown"
		local source_icon = entry.source_config and entry.source_config.icon or ""
		local display_name = entry.title or entry.filename
		local mtime = ap_utils.format_time(entry.mtime or 0)
		local size = ap_utils.format_size(entry.size or 0)

		return displayer({
			{ "[" .. source_name .. "]", "TelescopeResultsComment" },
			{ source_icon, "TelescopeResultsSpecialComment" },
			{ display_name, "TelescopeResultsIdentifier" },
			{ mtime, "TelescopeResultsNumber" },
			{ size, "TelescopeResultsConstant" },
		})
	end

	--- Entry maker function
	---@param file_entry table Raw file entry from finder
	---@return table Telescope entry
	return function(file_entry)
		local path = file_entry.path
		local filename = vim.fn.fnamemodify(path, ":t")
		local mtime = ap_utils.get_mtime(path)
		local size = ap_utils.get_size(path)

		-- Try to extract title from markdown if enabled
		local title = nil
		if show_title then
			title = ap_utils.get_md_title(path)
		end

		return {
			value = path,
			path = path,
			filename = filename,
			display = make_display,
			ordinal = (title or filename) .. " " .. (file_entry.source or ""),
			source = file_entry.source,
			source_config = file_entry.source_config,
			mtime = mtime,
			size = size,
			title = title,
		}
	end
end

return M
