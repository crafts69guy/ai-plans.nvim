-- ai-plans.nvim: Telescope Extension Entry Point
-- Browse, preview, and manage AI-generated plan files

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("ai-plans.nvim requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local ap_config = require("telescope._extensions.ai_plans.config")
local ap_actions = require("telescope._extensions.ai_plans.actions")
local ap_finders = require("telescope._extensions.ai_plans.finders")
local ap_picker = require("telescope._extensions.ai_plans.init")
local ap_zen = require("telescope._extensions.ai_plans.zen")

--- Main entry point for the ai_plans picker
---@param opts table|nil User options
local ai_plans = function(opts)
	opts = opts or {}

	-- Apply theme from config if set
	local defaults = (function()
		if ap_config.values.theme then
			local theme_func = require("telescope.themes")["get_" .. ap_config.values.theme]
			if theme_func then
				return theme_func(ap_config.values)
			end
		end
		return vim.deepcopy(ap_config.values)
	end)()

	-- Merge user options
	local popts = vim.tbl_deep_extend("force", defaults, opts)

	-- Call the picker
	ap_picker.ai_plans(popts)
end

--- Entry point for grep/content search picker
---@param opts table|nil User options
local grep = function(opts)
	opts = opts or {}

	-- Apply theme from config if set
	local defaults = (function()
		if ap_config.values.theme then
			local theme_func = require("telescope.themes")["get_" .. ap_config.values.theme]
			if theme_func then
				return theme_func(ap_config.values)
			end
		end
		return vim.deepcopy(ap_config.values)
	end)()

	-- Merge user options
	local popts = vim.tbl_deep_extend("force", defaults, opts)

	-- Call the grep picker
	ap_picker.grep(popts)
end

return telescope.register_extension({
	setup = ap_config.setup,
	exports = {
		ai_plans = ai_plans,
		grep = grep,
		actions = ap_actions,
		finders = ap_finders,
		picker = ap_picker,
		zen = ap_zen,
	},
})
