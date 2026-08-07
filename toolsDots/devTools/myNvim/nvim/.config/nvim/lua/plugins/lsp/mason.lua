return {
	"mason-org/mason.nvim",
	opts = {
		ensure_installed = {
			"prettier", -- prettier formatter
			"stylua", -- lua formatter
			"isort", -- python formatter
			"black", -- python formatter
			"pylint",
			"eslint_d",
		},
	},
}
