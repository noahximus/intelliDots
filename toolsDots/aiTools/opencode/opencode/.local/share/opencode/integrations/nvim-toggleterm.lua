local function open_bottom(command)
    vim.cmd("botright new")
    vim.fn.termopen(command)
    vim.cmd("startinsert")
end

local function open_toggleterm(command, direction)
    vim.cmd(string.format('TermExec cmd="%s" direction=%s', command, direction))
end

local function choose_opencode(open_command)
    local choices = {
        { label = "Local models", command = "opencode-local run" },
        { label = "Online models (OpenAI/Codex)", command = "opencode-online run" },
    }

    vim.ui.select(choices, {
        prompt = "OpenCode provider:",
        format_item = function(choice)
            return choice.label
        end,
    }, function(choice)
        if choice then
            open_command(choice.command)
        end
    end)
end

return {
    "akinsho/toggleterm.nvim",
    keys = {
        {
            "<leader>aof",
            function()
                choose_opencode(function(command)
                    open_toggleterm(command, "float")
                end)
            end,
            desc = "AI: Choose OpenCode provider (float)",
        },
        {
            "<leader>aoh",
            function()
                choose_opencode(function(command)
                    open_toggleterm(command, "horizontal")
                end)
            end,
            desc = "AI: Choose OpenCode provider (horizontal)",
        },
        {
            "<leader>aob",
            function()
                choose_opencode(open_bottom)
            end,
            desc = "AI: Choose OpenCode provider (bottom split)",
        },
        {
            "<leader>aol",
            function()
                open_bottom("opencode-local run")
            end,
            desc = "AI: OpenCode local (bottom split)",
        },
        {
            "<leader>aoo",
            function()
                open_bottom("opencode-online run")
            end,
            desc = "AI: OpenCode online (bottom split)",
        },
    },
}
