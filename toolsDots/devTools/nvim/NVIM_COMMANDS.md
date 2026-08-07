# Neovim Command Reference

This reference describes the commands and keymaps available from the current
`nvim` Neovim configuration, LazyVim, and the plugins loaded by it.

It was checked against the active Neovim runtime. Plugin updates can add or
remove commands, so use the discovery commands at the end when this file and
the runtime differ.

## Key notation

- `<leader>` is **Space**.
- `<C-x>` means hold Control and press `x`.
- `<S-x>` means hold Shift and press `x`.
- Normal mode is the default mode after pressing `Esc`.
- Visual mode begins after selecting text with `v`, `V`, or `<C-v>`.
- Commands beginning with `:` are entered from Normal mode.

## Essential Neovim commands

| Command | Purpose |
| --- | --- |
| `:w` | Save the current file. |
| `:q` | Close the current window. |
| `:wq` | Save and close. |
| `:q!` | Close without saving. |
| `:qa` | Close all windows. |
| `:qa!` | Force-close Neovim without saving. |
| `:e FILE` | Edit a file. |
| `:enew` | Open an empty buffer. |
| `:bd` | Delete the current buffer. |
| `:split FILE` | Open a horizontal split. |
| `:vsplit FILE` | Open a vertical split. |
| `:tabnew FILE` | Open a file in a new tab. |
| `:set OPTION?` | Display an option's current value. |
| `:checkhealth` | Run Neovim and plugin health checks. |

## File and project navigation

| Key | Purpose |
| --- | --- |
| `<leader><leader>` | Find files from the project root. |
| `<leader>ff` | Find files from the project root. |
| `<leader>fF` | Find files from the current directory. |
| `<leader>fg` | Find Git-tracked files. |
| `<leader>fr` | Open recent files. |
| `<leader>fR` | Open recent files from the current directory. |
| `<leader>fc` | Find a Neovim configuration file. |
| `<leader>fp` | Find files in installed plugin directories. |
| `<leader>fb` | Search open buffers. |
| `<leader>fB` | Search all buffers. |
| `<leader>e` | Toggle Neo-tree at the project root. |
| `<leader>E` | Toggle Neo-tree at the current directory. |
| `<leader>fe` | Toggle Neo-tree at the project root. |
| `<leader>fE` | Toggle Neo-tree at the current directory. |
| `<leader>,` | Switch buffers. |
| `H` | Move to the previous buffer. |
| `L` | Move to the next buffer. |
| `[b` / `]b` | Move to the previous/next buffer. |
| `[B` / `]B` | Reorder the current buffer left/right. |
| `gx` | Open the file path or URL under the cursor. |

Useful commands:

| Command | Purpose |
| --- | --- |
| `:Neotree` | Open or control Neo-tree. |
| `:Telescope` | Open Telescope or run a Telescope picker. |
| `:FzfLua` | Open an fzf-lua picker. |
| `:Explore` | Open Neovim's built-in file explorer. |
| `:Open PATH_OR_URL` | Open a path or URL with the macOS default application. |

## Buffer management

| Key | Purpose |
| --- | --- |
| `<leader>bp` | Pin or unpin the current buffer. |
| `<leader>bP` | Delete all non-pinned buffers. |
| `<leader>bl` | Delete buffers to the left. |
| `<leader>br` | Delete buffers to the right. |
| `<leader>bj` | Interactively pick a buffer. |
| `<leader>be` | Open the buffer explorer. |
| `<leader>.` | Toggle a scratch buffer. |
| `<leader>S` | Select a scratch buffer. |

## Search and replace

| Key | Purpose |
| --- | --- |
| `<leader>/` | Search text in the project root. |
| `<leader>sg` | Search text in the project root. |
| `<leader>sG` | Search text in the current directory. |
| `<leader>sw` | Search the word under the cursor in the project root. |
| `<leader>sW` | Search the word under the cursor in the current directory. |
| `<leader>sw` in Visual mode | Search the selection in the project root. |
| `<leader>sW` in Visual mode | Search the selection in the current directory. |
| `<leader>sr` | Search and replace with grug-far. |
| `<leader>sb` | Search lines in the current buffer. |
| `<leader>s/` | Search history. |
| `<leader>sc` | Command history. |
| `<leader>sR` | Resume the last picker. |
| `<leader>ss` | Go to a symbol in the current document. |
| `<leader>sS` | Go to a symbol in the workspace. |
| `<leader>sh` | Search help pages. |
| `<leader>sM` | Search manual pages. |
| `<leader>sk` | Search active keymaps. |
| `<leader>sC` | Search available commands. |
| `<leader>sa` | Search autocommands. |
| `<leader>sm` | Jump to a mark. |
| `<leader>sj` | Open the jump list. |
| `<leader>sl` | Open the location list. |
| `<leader>sq` | Open the quickfix list. |
| `<leader>sH` | Search highlight groups. |

Commands:

| Command | Purpose |
| --- | --- |
| `:GrugFar` | Open project search and replace. |
| `:GrugFarWithin` | Search and replace within the selected scope. |

## Git

| Key | Purpose |
| --- | --- |
| `<leader>gs` | Show Git status. |
| `<leader>gc` | Search repository commits. |
| `<leader>gl` | Search repository commits. |
| `<leader>gd` | Show changed files and diffs. |
| `<leader>ge` | Open the Git file explorer. |
| `<leader>gS` | Search Git stashes. |

## LSP and code intelligence

These mappings are most useful while an LSP server is attached to the buffer.

| Key | Purpose |
| --- | --- |
| `grn` | Rename the symbol under the cursor. |
| `grr` | Find references. |
| `gri` | Go to implementation. |
| `grt` | Go to type definition. |
| `gra` | Run a code action. |
| `grx` | Run a code lens. |
| `gO` | Show document symbols. |
| `<C-s>` in Insert/Visual mode | Show signature help. |
| `<leader>rs` | Restart the active LSP clients. |
| `<leader>cm` | Open Mason. |
| `<leader>cF` | Format injected languages. |

Commands:

| Command | Purpose |
| --- | --- |
| `:LspRestart` | Restart attached LSP clients. |
| `:LspInstall SERVER` | Install an LSP server through Mason. |
| `:LspUninstall SERVER` | Uninstall an LSP server. |
| `:Mason` | Open Mason's package manager UI. |
| `:MasonInstall PACKAGE` | Install one or more Mason packages. |
| `:MasonUninstall PACKAGE` | Uninstall Mason packages. |
| `:MasonUpdate` | Update Mason registries. |
| `:ConformInfo` | Show formatter information for the current buffer. |

## Diagnostics, quickfix, and todos

| Key | Purpose |
| --- | --- |
| `]d` / `[d` | Go to the next/previous diagnostic. |
| `]D` / `[D` | Go to the last/first diagnostic. |
| `<C-w>d` | Show diagnostics under the cursor. |
| `<leader>sd` | Search workspace diagnostics. |
| `<leader>sD` | Search diagnostics in the current buffer. |
| `]q` / `[q` | Go to the next/previous quickfix entry. |
| `]l` / `[l` | Go to the next/previous location-list entry. |
| `]t` / `[t` | Go to the next/previous TODO comment. |
| `<leader>st` | Search TODO comments. |
| `<leader>sT` | Search TODO, FIX, and FIXME comments. |

Commands:

| Command | Purpose |
| --- | --- |
| `:TodoTelescope` | Search TODO comments with a picker. |
| `:TodoTrouble` | Send TODO comments to Trouble if Trouble is enabled. |

Note: the repository currently disables the main Trouble plugin configuration,
so Trouble-specific views may not be available even if lazy command stubs exist.

## Editing, comments, and Treesitter

| Key | Mode | Purpose |
| --- | --- | --- |
| `gcc` | Normal | Toggle the current line comment. |
| `gc` + motion | Normal/Operator | Comment the selected motion. |
| `gc` | Visual | Toggle comments on the selection. |
| `[<Space>` | Normal | Add an empty line above. |
| `]<Space>` | Normal | Add an empty line below. |
| `<C-Space>` | Normal/Visual | Expand Treesitter selection. |
| `]n` / `[n` | Visual | Select next/previous syntax node. |
| `]N` / `[N` | Visual | Select next/previous sibling node. |
| `an` | Visual/Operator | Select the parent/outer syntax node. |
| `in` | Visual/Operator | Select the child/inner syntax node. |
| `R` | Visual/Operator | Treesitter search. |

Commands:

| Command | Purpose |
| --- | --- |
| `:Inspect` | Inspect highlights and extmarks under the cursor. |
| `:InspectTree` | Open the Treesitter syntax tree inspector. |
| `:EditQuery` | Edit the active Treesitter query. |
| `:TSInstall LANGUAGE` | Install a Treesitter parser. |
| `:TSUpdate` | Update installed Treesitter parsers. |
| `:TSUninstall LANGUAGE` | Uninstall a parser. |

## Flash navigation

| Key | Mode | Purpose |
| --- | --- | --- |
| `s` | Normal/Visual/Operator | Jump with Flash. |
| `S` | Normal/Visual/Operator | Flash Treesitter nodes. |
| `r` | Operator | Remote Flash. |
| `<C-s>` | Command line | Toggle Flash search. |

## Terminal

| Command | Purpose |
| --- | --- |
| `:ToggleTerm` | Toggle a terminal. Accepts size, direction, and terminal ID options. |
| `:TermNew` | Create a new terminal. |
| `:TermExec cmd="COMMAND"` | Execute a command in a terminal. |
| `:TermSelect` | Select an available terminal. |
| `:ToggleTermToggleAll` | Toggle all terminals. |
| `:ToggleTermSendCurrentLine` | Send the current line to a terminal. |
| `:ToggleTermSendVisualSelection` | Send selected text to a terminal. |

## Python virtual environments

| Key or command | Purpose |
| --- | --- |
| `,v` | Open the virtual-environment selector. This is comma then `v`; it does not use Leader. |
| `:VenvSelect` | Search for and activate a Python virtual environment. |
| `:VenvSelectLog` | Toggle the venv-selector log. |

The selector searches the configured pyenv root and project environments.

## Markdown

| Key or command | Purpose |
| --- | --- |
| `<leader>mp` | Toggle Markdown Preview. |
| `:MarkdownPreview` | Start browser-based Markdown Preview. |
| `:MarkdownPreviewStop` | Stop Markdown Preview. |
| `:MarkdownPreviewToggle` | Toggle Markdown Preview. |

`render-markdown.nvim` also renders Markdown formatting inside Neovim when a
Markdown buffer is open.

## AI and CodeCompanion

The active provider can be the local LLM or online Codex through ACP.

| Key | Mode | Purpose |
| --- | --- | --- |
| `<leader>ac` | Normal/Visual | Open an AI chat with the selected provider. |
| `<leader>ag` | Normal/Visual | Prompt for a coding-agent task. |
| `<leader>ai` | Normal/Visual | Run local-LLM inline assistance. |
| `<leader>aa` | Normal/Visual | Open the CodeCompanion actions palette. |
| `<leader>ap` | Normal/Visual | Select local LLM or online Codex. |
| `<leader>am` | Normal/Visual | Select an installed local model. |
| `<leader>aw` | Normal/Visual | Toggle the local tool-call repair wrapper. |

CodeCompanion commands:

| Command | Purpose |
| --- | --- |
| `:CodeCompanionChat` | Open or manage an AI chat buffer. |
| `:CodeCompanion` | Run the inline assistant. |
| `:CodeCompanionActions` | Open the actions palette. |
| `:CodeCompanionCmd PROMPT` | Ask the model to generate a command-line command. |
| `:CodeCompanionCLI` | Send a task to a configured CLI agent. |

Provider commands:

| Command | Purpose |
| --- | --- |
| `:AIProviderSelect` | Interactively select local LLM or Codex. |
| `:AIProviderStatus` | Show the active provider. |
| `:AIProviderUse local` | Use the local LLM for new chats. |
| `:AIProviderUse codex` | Use online Codex for new chats. |

Local-LLM commands available inside Neovim:

| Command | Purpose |
| --- | --- |
| `:LocalLLMStart` | Start the selected local model and wrapper if enabled. |
| `:LocalLLMStop` | Stop local LLM services. |
| `:LocalLLMStatus` | Show selected model and service status. |
| `:LocalLLMModelSelect` | Interactively choose an installed model. |
| `:LocalLLMModelStatus` | Show selected model information. |
| `:LocalLLMModelUse MODEL` | Select a model by ID and restart the service. |
| `:LocalLLMWrapperOn` | Enable and start the tool-call repair wrapper. |
| `:LocalLLMWrapperOff` | Disable the wrapper. |
| `:LocalLLMWrapperToggle` | Toggle wrapper mode. |
| `:LocalLLMWrapperStatus` | Show wrapper state. |

## Debugging with nvim-dap

Commands available from the active DAP runtime:

| Command | Purpose |
| --- | --- |
| `:DapContinue` | Start or continue debugging. |
| `:DapNew` | Start a new debug session. |
| `:DapPause` | Pause execution. |
| `:DapStepInto` | Step into a function. |
| `:DapStepOver` | Step over the current line. |
| `:DapStepOut` | Step out of the current function. |
| `:DapToggleBreakpoint` | Toggle a breakpoint on the current line. |
| `:DapClearBreakpoints` | Clear all breakpoints. |
| `:DapEval` | Evaluate the expression under the cursor. |
| `:DapToggleRepl` | Toggle the debugger REPL. |
| `:DapRestartFrame` | Restart the current stack frame. |
| `:DapDisconnect` | Disconnect the debugger. |
| `:DapTerminate` | Terminate the debug session. |
| `:DapShowLog` | Open the DAP log. |
| `:DapSetLogLevel LEVEL` | Set the DAP log level. |

## Sessions, notifications, appearance, and help

| Key | Purpose |
| --- | --- |
| `<leader>qs` | Restore a saved session. |
| `<leader>ql` | Restore the last session. |
| `<leader>qS` | Select a session. |
| `<leader>qd` | Stop persistence for the current session. |
| `<leader>n` | Show notification history. |
| `<leader>un` | Dismiss notifications. |
| `<leader>sn` | Open Noice commands. |
| `<leader>sna` | Show all Noice messages. |
| `<leader>snh` | Show Noice history. |
| `<leader>snl` | Show the last Noice message. |
| `<leader>snd` | Dismiss Noice messages. |
| `<leader>uC` | Select a colorscheme with preview. |
| `<leader>?` | Show buffer-local keymaps with which-key. |
| `<leader>:` | Search command history. |
| `<C-w><Space>` | Open the window-management which-key menu. |

Commands:

| Command | Purpose |
| --- | --- |
| `:Lazy` | Open the Lazy plugin manager. |
| `:Notifications` | Show notification history. |
| `:NotificationsClear` | Clear notification history. |
| `:Man TOPIC` | Open a system manual page. |

## Plugin and package maintenance

| Command | Purpose |
| --- | --- |
| `:Lazy` | Inspect, install, update, clean, or profile plugins. |
| `:Lazy check` | Check for plugin updates. |
| `:Lazy sync` | Synchronize installed plugins with the current specs and lockfile. |
| `:Mason` | Manage LSP servers, formatters, linters, and debuggers. |
| `:MasonLog` | Open the Mason log. |
| `:TSUpdate` | Update Treesitter parsers. |

For the deterministic setup used by this repository, run outside Neovim:

```bash
./install.sh --no-brew --nvim
```

## Runtime discovery commands

These commands are the authoritative way to inspect the currently running
Neovim instance:

| Command | Purpose |
| --- | --- |
| `<leader>sk` | Search active keymaps interactively. |
| `<leader>sC` | Search available commands interactively. |
| `:map` | List mappings in all common modes. |
| `:nmap` | List Normal-mode mappings. |
| `:vmap` | List Visual-mode mappings. |
| `:imap` | List Insert-mode mappings. |
| `:tmap` | List Terminal-mode mappings. |
| `:commands` | List user-defined commands. |
| `:Lazy` | Show installed plugins and their status. |
| `:scriptnames` | Show sourced runtime scripts. |
| `:checkhealth` | Run health checks. |
| `:verbose map KEY` | Show the mapping and file that last defined `KEY`. |
| `:verbose command NAME` | Show where a user command was defined. |

## Built-in help

Neovim includes far more built-in motions, operators, text objects, and Ex
commands than is useful to duplicate here. Use:

| Command | Purpose |
| --- | --- |
| `:help` | Open the main help index. |
| `:help USER-MANUAL` | Open the user manual. |
| `:help quickref` | Open Neovim's compact command reference. |
| `:help motion.txt` | Learn cursor motions. |
| `:help change.txt` | Learn editing operators. |
| `:help windows.txt` | Learn windows, tabs, and buffers. |
| `:help :COMMAND` | Read help for an Ex command. |
| `:help KEY` | Read help for a key or mapping notation. |
