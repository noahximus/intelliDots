local wrapper_url = "http://127.0.0.1:8090"
local backend_url = "http://127.0.0.1:8081"
-- TurboFieldfare shares local-llm's backend port by design (they are never
-- run at the same time, on purpose, so 8080 stays free for dev servers). The
-- turbo-fieldfare CLI itself refuses to start when the port is held by a
-- different backend, so ensure_turbo_fieldfare() below just defers to it.
local wrapper_state_file = vim.fn.expand("~/.config/local-llm/enabled")
local provider_state_file = vim.fn.stdpath("state") .. "/codecompanion-provider"
local provider_choices = {
  { id = "local", label = "Local LLM" },
  { id = "turbo", label = "TurboFieldfare (Gemma 4 26B)" },
  { id = "codex", label = "Online Codex (ChatGPT)" },
}

local function provider_label(id)
  for _, choice in ipairs(provider_choices) do
    if choice.id == id then
      return choice.label
    end
  end
  return "Local LLM"
end

local function load_provider()
  if vim.fn.filereadable(provider_state_file) == 1 then
    local lines = vim.fn.readfile(provider_state_file, "", 1)
    local provider = vim.trim(lines[1] or "")
    for _, choice in ipairs(provider_choices) do
      if choice.id == provider then
        return provider
      end
    end
  end
  return "local"
end

local active_provider = load_provider()

local function system_capture(command, timeout)
  local result = vim.system(command, { text = true }):wait(timeout or 60000)
  local output = vim.trim(result.stdout ~= "" and result.stdout or result.stderr or "")
  return result.code == 0, output
end

local function available_models()
  local ok, output = system_capture({ "local-llm", "model", "list", "--porcelain" })
  if not ok then
    vim.notify(output, vim.log.levels.ERROR)
    return {}
  end

  local models = {}
  for line in output:gmatch("[^\r\n]+") do
    local selected, id, path = line:match("^(%d)\t([^\t]+)\t(.+)$")
    if id then
      table.insert(models, {
        id = id,
        path = path,
        selected = selected == "1",
      })
    end
  end
  return models
end

local function wrapper_enabled()
  if vim.fn.filereadable(wrapper_state_file) ~= 1 then
    return true
  end
  local lines = vim.fn.readfile(wrapper_state_file, "", 1)
  local state = vim.trim((lines[1] or "on"):lower())
  return state == "on" or state == "enabled" or state == "1" or state == "true"
end

local function adapter_url()
  return wrapper_enabled() and wrapper_url or backend_url
end

local function stack_ready()
  local health_path = wrapper_enabled() and "/health" or "/v1/models"
  local ok = system_capture({ "curl", "-fsS", "--max-time", "1", adapter_url() .. health_path }, 3000)
  return ok
end

local function require_local_llm()
  if vim.fn.executable("local-llm") ~= 1 then
    vim.notify("local-llm is not installed; run the wrapper installer", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- local-llm now owns a persisted provider state (llama|turbo) shared with
-- the terminal CLI. Both ensure functions switch it explicitly on every
-- call -- cheap when already correct (the CLI short-circuits with "Provider
-- is already X") -- so CodeCompanion's picker can never silently drift out
-- of sync with whatever a terminal `local-llm provider use ...` last set.
local function ensure_stack()
  if not require_local_llm() then
    return false
  end
  local switched, switch_output = system_capture({ "local-llm", "provider", "use", "llama" }, 90000)
  if not switched then
    vim.notify(switch_output, vim.log.levels.ERROR)
    return false
  end
  if stack_ready() then
    return true
  end
  local mode = wrapper_enabled() and "with tool-call repair" or "with wrapper bypassed"
  vim.notify("Starting local LLM " .. mode .. "...", vim.log.levels.INFO)
  local ok, output = system_capture({ "local-llm", "start" }, 90000)
  vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  return ok and stack_ready()
end

local function ensure_turbo_fieldfare()
  if not require_local_llm() then
    return false
  end
  local switched, switch_output = system_capture({ "local-llm", "provider", "use", "turbo" }, 90000)
  if not switched then
    vim.notify(switch_output, vim.log.levels.ERROR)
    return false
  end
  local ready = system_capture({ "turbo-fieldfare", "status" }, 5000)
  if ready then
    return true
  end
  vim.notify("Starting TurboFieldfare (first load can take a while)...", vim.log.levels.INFO)
  -- Model load can be slow on a cold start; the CLI's own wait_ready caps at
  -- 60s, this just needs to outlast that plus process spawn overhead.
  -- Delegated through local-llm (not turbo-fieldfare directly) now that the
  -- provider switch above already guarantees local-llm will route here.
  local ok, output = system_capture({ "local-llm", "start" }, 120000)
  vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  return ok
end

-- "local" is a Lua reserved word, so these keys must use bracket syntax.
local provider_adapters = {
  ["local"] = "local_llm_repaired",
  turbo = "turbo_fieldfare",
  codex = "codex",
}

local provider_ensure = {
  ["local"] = ensure_stack,
  turbo = ensure_turbo_fieldfare,
}

local function open_chat(prompt)
  local adapter = provider_adapters[active_provider] or "local_llm_repaired"
  local ensure = provider_ensure[active_provider]
  if ensure and not ensure() then
    return
  end
  local args = { "adapter=" .. adapter }
  if prompt and prompt ~= "" then
    table.insert(args, prompt)
  end
  vim.api.nvim_cmd({ cmd = "CodeCompanionChat", args = args }, {})
end

local function open_agent()
  vim.ui.input({ prompt = provider_label(active_provider) .. " coding task: " }, function(prompt)
    if not prompt or vim.trim(prompt) == "" then
      return
    end
    if active_provider == "codex" then
      open_chat(prompt)
    else
      open_chat("@{agent} " .. prompt)
    end
  end)
end

local function use_provider(provider_id)
  local valid = false
  for _, choice in ipairs(provider_choices) do
    if choice.id == provider_id then
      valid = true
    end
  end
  if not valid then
    vim.notify("Unknown AI provider: " .. provider_id, vim.log.levels.ERROR)
    return
  end
  if provider_id == "codex" and vim.fn.executable("codex-acp") ~= 1 then
    vim.notify("codex-acp is not installed or is not on PATH", vim.log.levels.ERROR)
    return
  end
  active_provider = provider_id
  vim.fn.writefile({ provider_id }, provider_state_file)
  vim.notify("AI provider: " .. provider_label(provider_id) .. ". New chats will use this provider.", vim.log.levels.INFO)
end

local function select_provider()
  vim.ui.select(provider_choices, {
    prompt = "Select CodeCompanion provider",
    format_item = function(item)
      local marker = item.id == active_provider and "✓ " or "  "
      return marker .. item.label
    end,
  }, function(choice)
    if choice then
      use_provider(choice.id)
    end
  end)
end

local function use_model(model_id)
  vim.notify("Switching local LLM model to " .. model_id .. "...", vim.log.levels.INFO)
  local ok, output = system_capture({ "local-llm", "model", "use", model_id }, 120000)
  vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
end

local function select_model()
  vim.ui.select(available_models(), {
    prompt = "Select local model",
    format_item = function(item)
      return (item.selected and "* " or "  ") .. item.id
    end,
  }, function(choice)
    if choice then
      use_model(choice.id)
    end
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
      {
        "<leader>ac",
        function()
          open_chat()
        end,
        mode = { "n", "v" },
        desc = "AI: chat",
      },
      {
        "<leader>ag",
        open_agent,
        mode = { "n", "v" },
        desc = "AI: coding agent",
      },
      {
        "<leader>ai",
        function()
          if active_provider == "codex" then
            vim.notify("Codex ACP supports chat tasks; use <leader>ac or <leader>ag", vim.log.levels.INFO)
            return
          end
          local adapter = provider_adapters[active_provider] or "local_llm_repaired"
          local ensure = provider_ensure[active_provider]
          if not ensure or ensure() then
            vim.api.nvim_cmd({ cmd = "CodeCompanion", args = { "adapter=" .. adapter } }, {})
          end
        end,
        mode = { "n", "v" },
        desc = "AI: local model inline",
      },
      {
        "<leader>aa",
        "<cmd>CodeCompanionActions<cr>",
        mode = { "n", "v" },
        desc = "AI: actions",
      },
      {
        "<leader>ap",
        select_provider,
        mode = { "n", "v" },
        desc = "AI: select provider",
      },
      {
        "<leader>aw",
        function()
          local ok, output = system_capture({ "local-llm", "wrapper", "toggle" }, 90000)
          vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
        end,
        mode = { "n", "v" },
        desc = "AI: toggle local LLM tool wrapper",
      },
      {
        "<leader>am",
        select_model,
        mode = { "n", "v" },
        desc = "AI: select local LLM model",
      },
    },
    opts = {
      adapters = {
        acp = {
          codex = function()
            return require("codecompanion.adapters").extend("codex", {
              defaults = {
                auth_method = "chat-gpt",
              },
            })
          end,
        },
        http = {
          local_llm_repaired = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "local_llm_repaired",
              formatted_name = "Local LLM (tool repair)",
              env = {
                url = adapter_url,
                api_key = "local-no-key",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "local-llm" },
                temperature = { default = 0.1 },
                max_tokens = { default = 4096 },
              },
            })
          end,
          turbo_fieldfare = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "turbo_fieldfare",
              formatted_name = "TurboFieldfare (Gemma 4 26B)",
              env = {
                -- Same host:port as local_llm_repaired's backend_url: the two
                -- processes share the port on purpose and never run together.
                url = backend_url,
                api_key = "local-no-key",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "gemma-4-26b-a4b-it" },
                temperature = { default = 0.2 },
                max_tokens = { default = 4096 },
              },
            })
          end,
          opts = { show_model_choices = false },
        },
      },
      interactions = {
        chat = {
          adapter = "local_llm_repaired",
          tools = {
            file_search = {
              opts = {
                max_results = 2500,
              },
            },
          },
        },
        inline = { adapter = "local_llm_repaired" },
        cmd = { adapter = "local_llm_repaired" },
      },
      display = {
        chat = { show_settings = false },
        show_tools_processing = true,
      },
      opts = { log_level = "ERROR" },
      rules = {
        always = {
          description = "Personal and project instructions",
          parser = "codecompanion",
          files = {
            "~/.config/codecompanion/instructions.md",
            "AGENTS.md",
            ".github/copilot-instructions.md",
            ".codecompanion/instructions.md",
          },
        },
        opts = {
          chat = {
            autoload = "always",
            autoload_groups_in_prompt_library = true,
            enabled = true,
          },
        },
      },
    },
    init = function()
      vim.api.nvim_create_user_command("LocalLLMStart", function()
        local ok, output = system_capture({ "local-llm", "start" }, 90000)
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMStop", function()
        local ok, output = system_capture({ "local-llm", "stop" })
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMStatus", function()
        local ok, output = system_capture({ "local-llm", "status" })
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.WARN)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMWrapperOn", function()
        local ok, output = system_capture({ "local-llm", "wrapper", "on" }, 90000)
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMWrapperOff", function()
        local ok, output = system_capture({ "local-llm", "wrapper", "off" })
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMWrapperToggle", function()
        local ok, output = system_capture({ "local-llm", "wrapper", "toggle" }, 90000)
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMWrapperStatus", function()
        local ok, output = system_capture({ "local-llm", "wrapper", "status" })
        vim.notify("Local LLM wrapper: " .. output, ok and vim.log.levels.INFO or vim.log.levels.WARN)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMModelSelect", select_model, {})
      vim.api.nvim_create_user_command("LocalLLMModelStatus", function()
        local ok, output = system_capture({ "local-llm", "model", "status" })
        vim.notify(output, ok and vim.log.levels.INFO or vim.log.levels.WARN)
      end, {})
      vim.api.nvim_create_user_command("LocalLLMModelUse", function(opts)
        use_model(opts.args)
      end, {
        nargs = 1,
        complete = function()
          return vim.tbl_map(function(model)
            return model.id
          end, available_models())
        end,
      })
      vim.api.nvim_create_user_command("AIProviderSelect", select_provider, {})
      vim.api.nvim_create_user_command("AIProviderStatus", function()
        vim.notify("AI provider: " .. provider_label(active_provider), vim.log.levels.INFO)
      end, {})
      vim.api.nvim_create_user_command("AIProviderUse", function(opts)
        use_provider(opts.args)
      end, {
        nargs = 1,
        complete = function()
          return vim.tbl_map(function(choice)
            return choice.id
          end, provider_choices)
        end,
      })

      local progress_group = vim.api.nvim_create_augroup("CodeCompanionProgress", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        group = progress_group,
        pattern = {
          "CodeCompanionRequestStarted",
          "CodeCompanionRequestStreaming",
          "CodeCompanionRequestFinished",
        },
        callback = function(event)
          local data = event.data or {}
          local notification_id = "codecompanion-request-" .. tostring(data.id or "active")

          local adapter = data.adapter or {}
          local model_name = adapter.formatted_name or adapter.name or "LLM"

          if event.match == "CodeCompanionRequestStarted" then
            vim.notify("Waiting for " .. model_name .. "…", vim.log.levels.INFO, {
              id = notification_id,
              title = "CodeCompanion",
              icon = "󰚩",
              timeout = false,
            })
          elseif event.match == "CodeCompanionRequestStreaming" then
            vim.notify("Receiving a response from " .. model_name .. "…", vim.log.levels.INFO, {
              id = notification_id,
              title = "CodeCompanion",
              icon = "󰚩",
              timeout = false,
            })
          elseif event.match == "CodeCompanionRequestFinished" then
            local failed = data.status == "error"

            vim.notify(
              failed and "The request failed" or "Response received",
              failed and vim.log.levels.ERROR or vim.log.levels.INFO,
              {
                id = notification_id,
                title = "CodeCompanion",
                icon = failed and "󰅚" or "󰄬",
                timeout = 1800,
              }
            )
          end
        end,
      })
    end,
  },
}
