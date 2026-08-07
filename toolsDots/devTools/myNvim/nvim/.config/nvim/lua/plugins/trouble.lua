-- trouble.lua
return {
	-- Configure Trouble plugin
	{
		"folke/trouble.nvim",
		opts = { use_diagnostic_signs = true },
	},

	-- Disable Trouble
	{ "folke/trouble.nvim", enabled = false },
}
