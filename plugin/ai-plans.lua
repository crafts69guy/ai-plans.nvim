-- ai-plans.nvim: Auto-setup
-- Creates the :AiPlans command for easy access

if vim.g.loaded_ai_plans then
	return
end
vim.g.loaded_ai_plans = true

-- Create user command
vim.api.nvim_create_user_command("AiPlans", function(opts)
	require("telescope").extensions.ai_plans.ai_plans(opts.fargs[1] and { source = opts.fargs[1] } or {})
end, {
	nargs = "?",
	desc = "Open AI Plans picker",
	complete = function()
		local ok, config = pcall(require, "telescope._extensions.ai_plans.config")
		if not ok then
			return {}
		end
		local sources = {}
		for name, _ in pairs(config.values.sources) do
			table.insert(sources, name)
		end
		return sources
	end,
})
