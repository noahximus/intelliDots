return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"mfussenegger/nvim-dap",
		"mfussenegger/nvim-dap-python", --optional
		{ "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
	},
	lazy = false,
	opts = {
		settings = {
			search = {
				pyenv = {
					command = "$FD '/bin/python$' ${XDG_CONFIG_HOME:-$HOME/.config}/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
				},
			},
		},
	},
	keys = {
		{ ",v", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
	},
}
