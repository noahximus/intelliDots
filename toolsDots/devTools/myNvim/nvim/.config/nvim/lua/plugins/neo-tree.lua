return {
	"nvim-neo-tree/neo-tree.nvim",
	opts = {
		filesystem = {
			filtered_items = {
				visible = true,
				show_hidden_count = true,
				-- hide_dotfiles = false,
				hide_gitignored = true,
				hide_by_name = {
					--".git",
				},
				never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
					--".DS_Store",
					--"thumbs.db"
					--"__pycache__"
				},
			},
		},
	},
}
