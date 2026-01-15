-- ai-plans.nvim: Finder module
-- File discovery using fd or native Lua scandir

local finders = require("telescope.finders")
local Job = require("plenary.job")
local Path = require("plenary.path")
local scan = require("plenary.scandir")

local ap_utils = require("telescope._extensions.ai_plans.utils")
local ap_make_entry = require("telescope._extensions.ai_plans.make_entry")

local M = {}

--- Build fd arguments for markdown file discovery
---@param opts table Options
---@return table fd command arguments
local function fd_args(opts)
	local args = {
		"--type",
		"f",
		"--extension",
		"md",
		"--absolute-path",
	}

	if opts.hidden then
		table.insert(args, "--hidden")
	end

	return args
end

--- Collect files from a single source using fd
---@param source_path string Path to scan
---@param opts table Options
---@return table List of file paths
local function collect_files_fd(source_path, opts)
	local args = fd_args(opts)
	local result = Job:new({
		command = "fd",
		args = args,
		cwd = source_path,
	}):sync()
	return result or {}
end

--- Collect files from a single source using plenary.scandir (fallback)
---@param source_path string Path to scan
---@param opts table Options
---@return table List of file paths
local function collect_files_scandir(source_path, opts)
	local files = scan.scan_dir(source_path, {
		hidden = opts.hidden or false,
		add_dirs = false,
		depth = opts.depth or 10,
		search_pattern = "%.md$",
	})
	return files or {}
end

--- Collect all plan files from configured sources
---@param opts table Options including config values
---@return table List of file entries with path, source, source_config
M.collect_all_files = function(opts)
	local config = require("telescope._extensions.ai_plans.config")
	local all_files = {}

	for source_name, source_config in pairs(config.values.sources) do
		local expanded_path = ap_utils.expand_path(source_config.path)

		-- Check if directory exists
		if ap_utils.is_directory(expanded_path) then
			local files
			if config.values.use_fd and ap_utils.has_fd() then
				files = collect_files_fd(expanded_path, opts)
			else
				files = collect_files_scandir(expanded_path, opts)
			end

			for _, file in ipairs(files) do
				-- Ensure absolute path
				local abs_path
				if Path:new(file):is_absolute() then
					abs_path = file
				else
					abs_path = Path:new(expanded_path, file):absolute()
				end

				table.insert(all_files, {
					path = abs_path,
					source = source_name,
					source_config = source_config,
				})
			end
		else
			-- Optionally warn about missing directories
			if opts.warn_missing then
				ap_utils.notify(
					string.format("Source '%s' directory not found: %s", source_name, expanded_path),
					vim.log.levels.WARN
				)
			end
		end
	end

	-- Sort files based on configuration
	local sort_by = opts.sort_by or config.values.sort_by or "mtime"

	if sort_by == "mtime" then
		table.sort(all_files, function(a, b)
			return ap_utils.get_mtime(a.path) > ap_utils.get_mtime(b.path)
		end)
	elseif sort_by == "name" then
		table.sort(all_files, function(a, b)
			return a.path < b.path
		end)
	elseif sort_by == "size" then
		table.sort(all_files, function(a, b)
			return ap_utils.get_size(a.path) > ap_utils.get_size(b.path)
		end)
	end

	return all_files
end

--- Create the main telescope finder
---@param opts table Options
---@return table Telescope finder
M.finder = function(opts)
	opts = opts or {}
	local files = M.collect_all_files(opts)
	local entry_maker = ap_make_entry.gen_from_file(opts)

	return finders.new_table({
		results = files,
		entry_maker = entry_maker,
	})
end

return M
