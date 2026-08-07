return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = {
      "MarkdownPreview",
      "MarkdownPreviewStop",
      "MarkdownPreviewToggle",
    },
    ft = { "markdown" },
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
    },

    -- Use the plugin's prebuilt binary installer. Unlike npm/yarn installs, this
    -- keeps Lazy's Git checkout clean so future plugin updates are not blocked.
    build = function()
      vim.fn["mkdp#util#install"]()
    end,

    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
  },
}
