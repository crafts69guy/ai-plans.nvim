-- ai-plans.nvim: Utility functions
-- Tool detection, path handling, and helper functions

local M = {}

-- Cache tool availability checks
local tool_cache = {}

--- Check if an executable is available
---@param name string Executable name
---@return boolean
M.has_executable = function(name)
	if tool_cache[name] == nil then
		tool_cache[name] = vim.fn.executable(name) == 1
	end
	return tool_cache[name]
end

--- Check for fd availability
---@return boolean
M.has_fd = function()
	return M.has_executable("fd")
end

--- Check for rg availability
---@return boolean
M.has_rg = function()
	return M.has_executable("rg")
end

--- Check for bat availability
---@return boolean
M.has_bat = function()
	return M.has_executable("bat")
end

--- Expand path (handle ~ and environment variables)
---@param path string Path to expand
---@return string Expanded path
M.expand_path = function(path)
	return vim.fn.expand(path)
end

--- Get file modification time
---@param path string File path
---@return number Modification time in seconds since epoch
M.get_mtime = function(path)
	local stat = vim.loop.fs_stat(path)
	return stat and stat.mtime.sec or 0
end

--- Get file size
---@param path string File path
---@return number File size in bytes
M.get_size = function(path)
	local stat = vim.loop.fs_stat(path)
	return stat and stat.size or 0
end

--- Format file size for display
---@param bytes number File size in bytes
---@return string Formatted size string
M.format_size = function(bytes)
	if bytes < 1024 then
		return string.format("%dB", bytes)
	elseif bytes < 1024 * 1024 then
		return string.format("%.1fK", bytes / 1024)
	else
		return string.format("%.1fM", bytes / (1024 * 1024))
	end
end

--- Format timestamp for display
---@param timestamp number Unix timestamp
---@return string Formatted date string
M.format_time = function(timestamp)
	if timestamp == 0 then
		return "Unknown"
	end
	return os.date("%Y-%m-%d %H:%M", timestamp)
end

--- Parse first heading or meaningful line from markdown file
---@param path string File path
---@return string|nil Title or nil if not found
M.get_md_title = function(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local line_count = 0
	local max_lines = 20 -- Only scan first 20 lines

	for line in file:lines() do
		line_count = line_count + 1
		if line_count > max_lines then
			break
		end

		-- Match markdown heading (# Title)
		local title = line:match("^#%s+(.+)$")
		if title then
			file:close()
			-- Clean up the title (remove trailing #s if any)
			title = title:gsub("%s*#+%s*$", "")
			return title:sub(1, 60) -- Truncate long titles
		end
	end

	file:close()
	return nil
end

--- Notify helper with plugin prefix
---@param msg string Message to display
---@param level number|nil Log level (vim.log.levels.*)
M.notify = function(msg, level)
	vim.notify("[ai-plans] " .. msg, level or vim.log.levels.INFO)
end

--- Check if path exists and is a directory
---@param path string Path to check
---@return boolean
M.is_directory = function(path)
	return vim.fn.isdirectory(path) == 1
end

--- Check if path exists and is a file
---@param path string Path to check
---@return boolean
M.is_file = function(path)
	return vim.fn.filereadable(path) == 1
end

--- Safe pcall wrapper that logs errors
---@param fn function Function to call
---@param ... any Arguments to pass
---@return any Result or nil on error
M.safe_call = function(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		M.notify("Error: " .. tostring(result), vim.log.levels.ERROR)
		return nil
	end
	return result
end

return M
