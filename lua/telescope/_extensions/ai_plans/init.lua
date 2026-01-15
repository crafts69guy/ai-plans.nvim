-- ai-plans.nvim: Main picker module
-- Creates and manages the telescope picker for AI plan files

local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")

local ap_finders = require("telescope._extensions.ai_plans.finders")
local ap_config = require("telescope._extensions.ai_plans.config")
local ap_previewers = require("telescope._extensions.ai_plans.previewers")

local M = {}

--- Open the AI plans picker
---@param opts table|nil User options for this invocation
M.ai_plans = function(opts)
	opts = opts or {}

	-- Merge with config values
	local config_values = ap_config.get()
	opts = vim.tbl_deep_extend("force", config_values, opts)

	-- Apply theme if configured
	if opts.theme then
		local theme_func = require("telescope.themes")["get_" .. opts.theme]
		if theme_func then
			opts = theme_func(opts)
		end
	end

	-- Create the picker
	pickers
		.new(opts, {
			prompt_title = opts.prompt_title or "AI Plans",
			results_title = opts.results_title or "Plans",
			finder = ap_finders.finder(opts),
			sorter = conf.generic_sorter(opts),
			previewer = ap_previewers.previewer(opts),
			initial_mode = opts.initial_mode or "normal",
			attach_mappings = function(prompt_bufnr, map)
				-- Apply mappings from config
				if opts.mappings then
					for mode, mode_mappings in pairs(opts.mappings) do
						for key, action in pairs(mode_mappings) do
							if action then
								map(mode, key, action)
							end
						end
					end
				end

				-- Replace default select action
				local ap_actions = require("telescope._extensions.ai_plans.actions")
				actions.select_default:replace(function()
					ap_actions.open_file(prompt_bufnr)
				end)

				return true
			end,
		})
		:find()
end

return M
