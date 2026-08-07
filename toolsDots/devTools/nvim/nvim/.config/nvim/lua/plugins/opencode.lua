-- OpenCode-specific toggleterm keymaps. This file only contributes anything
-- when opencode is installed (which stows the integration below); with no
-- opencode, this returns an empty spec and toggleterm.lua's base plugin
-- registration is unaffected -- no missing-binary errors, no dead keymaps.
local opencode_integration = vim.fn.expand("~/.local/share/opencode/integrations/nvim-toggleterm.lua")

if vim.fn.filereadable(opencode_integration) == 1 then
  local ok, spec = pcall(dofile, opencode_integration)
  if ok then
    return spec
  end
  vim.schedule(function()
    vim.notify("Could not load optional OpenCode integration: " .. tostring(spec), vim.log.levels.WARN)
  end)
end

return {}
