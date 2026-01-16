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

--- Get all source paths for ripgrep search
---@return table List of expanded source paths
local function get_source_paths()
	local config = require("telescope._extensions.ai_plans.config")
	local paths = {}

	for _, source_config in pairs(config.values.sources) do
		local expanded_path = ap_utils.expand_path(source_config.path)
		if ap_utils.is_directory(expanded_path) then
			table.insert(paths, expanded_path)
		end
	end

	return paths
end

--- Determine which source a file belongs to
---@param filepath string File path
---@return string|nil source_name
---@return table|nil source_config
local function get_source_for_file(filepath)
	local config = require("telescope._extensions.ai_plans.config")

	for source_name, source_config in pairs(config.values.sources) do
		local expanded_path = ap_utils.expand_path(source_config.path)
		if filepath:find(expanded_path, 1, true) then
			return source_name, source_config
		end
	end

	return nil, nil
end

--- Search file contents using ripgrep
---@param pattern string Search pattern
---@param opts table Options
---@return table Search results with {path, lnum, col, text, source, source_config}
M.search_content_rg = function(pattern, opts)
	opts = opts or {}
	local paths = get_source_paths()

	if #paths == 0 then
		return {}
	end

	local args = {
		"--vimgrep",
		"--type",
		"md",
		"--smart-case",
		"--max-count",
		tostring(opts.max_results or 1000),
		pattern,
	}

	-- Add all source paths
	for _, path in ipairs(paths) do
		table.insert(args, path)
	end

	local result = Job:new({
		command = "rg",
		args = args,
	}):sync()

	local matches = {}
	for _, line in ipairs(result or {}) do
		-- Parse vimgrep format: file:line:col:text
		local filepath, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
		if filepath and lnum then
			local source_name, source_config = get_source_for_file(filepath)
			table.insert(matches, {
				path = filepath,
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = text,
				source = source_name,
				source_config = source_config,
			})
		end
	end

	return matches
end

--- Fallback content search using Lua (when rg unavailable)
---@param pattern string Search pattern (Lua pattern)
---@param opts table Options
---@return table Search results with {path, lnum, col, text, source, source_config}
M.search_content_lua = function(pattern, opts)
	opts = opts or {}
	local files = M.collect_all_files(opts)
	local matches = {}
	local max_results = opts.max_results or 1000

	-- Convert to case-insensitive pattern if needed
	local search_pattern = pattern:lower()

	for _, file_entry in ipairs(files) do
		if #matches >= max_results then
			break
		end

		local file = io.open(file_entry.path, "r")
		if file then
			local lnum = 0
			for line in file:lines() do
				lnum = lnum + 1
				local lower_line = line:lower()
				local col = lower_line:find(search_pattern, 1, true)
				if col then
					table.insert(matches, {
						path = file_entry.path,
						lnum = lnum,
						col = col,
						text = line,
						source = file_entry.source,
						source_config = file_entry.source_config,
					})
					if #matches >= max_results then
						break
					end
				end
			end
			file:close()
		end
	end

	return matches
end

--- Search content using rg or fallback to Lua
---@param pattern string Search pattern
---@param opts table Options
---@return table Search results
M.search_content = function(pattern, opts)
	opts = opts or {}
	local config = require("telescope._extensions.ai_plans.config")

	if config.values.use_rg and ap_utils.has_rg() then
		return M.search_content_rg(pattern, opts)
	else
		return M.search_content_lua(pattern, opts)
	end
end

--- Create finder for grep results
---@param pattern string Search pattern
---@param opts table Options
---@return table Telescope finder
M.grep_finder = function(pattern, opts)
	opts = opts or {}
	local results = M.search_content(pattern, opts)
	local entry_maker = ap_make_entry.gen_from_grep(opts)

	return finders.new_table({
		results = results,
		entry_maker = entry_maker,
	})
end

return M
