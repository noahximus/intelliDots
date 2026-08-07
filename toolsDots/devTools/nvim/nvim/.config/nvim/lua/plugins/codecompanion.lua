local local_integration = vim.fn.expand("~/.local/share/local-llm/integrations/codecompanion.lua")

if vim.fn.filereadable(local_integration) == 1 then
  local ok, spec = pcall(dofile, local_integration)
  if ok then
    return spec
  end
  vim.schedule(function()
    vim.notify("Could not load optional local-LLM integration: " .. tostring(spec), vim.log.levels.WARN)
  end)
end

return {
  {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionActions",
      "CodeCompanionChat",
      "CodeCompanionCmd",
    },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat<cr>", mode = { "n", "v" }, desc = "AI: chat" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI: actions" },
    },
    opts = {
      adapters = {
        acp = {
          codex = function()
            return require("codecompanion.adapters").extend("codex", {
              defaults = { auth_method = "chat-gpt" },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = "codex" },
      },
      opts = { log_level = "ERROR" },
    },
  },
}
