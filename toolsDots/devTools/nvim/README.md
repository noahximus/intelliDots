# nvim

Standalone Neovim and LazyVim configuration. Part of `toolsDots/devTools` in
`intelliDots`. It can be installed without `essentialDots`, `localLLM`, or
any other intelliDots component.

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.devTools.nvim
```

Or directly:

```bash
cd toolsDots/devTools/nvim
./install.sh
```

The default uses `Brewfile-essential`: GNU Stow, Neovim, Node, CMake, ripgrep,
fd, and fzf. Use `./install.sh --full` to additionally install Pandoc.

Options:

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --no-sync
./install.sh --adopt
```

The installer Stows `~/.config/nvim`, synchronizes plugins to
`lazy-lock.json`, and verifies Markdown Preview. See [NVIM_COMMANDS.md](NVIM_COMMANDS.md)
for the key and command reference.

The installer also installs `@agentclientprotocol/codex-acp` globally with npm
when `codex-acp` is missing, as long as `codex-acp` is listed in this node's
`extras` in `features.yaml` (`toolsDots.devTools.nvim`) -- comment out or
delete that line to skip it without touching this script. CodeCompanion uses
it with ChatGPT authentication for online Codex. `./install.sh --no-codex-acp`
always skips it regardless of that list.

After completing the Codex browser login when first prompted, select it inside
Neovim with `:AIProviderUse codex`; verify with `:AIProviderStatus`, then open a
chat with `:CodeCompanionChat`.

## Optional local LLM support

The default CodeCompanion setup uses online Codex through ACP. When
`~/.local/share/local-llm/integrations/codecompanion.lua` exists, it is
loaded automatically and provides local models, wrapper controls, and provider
selection. The file is owned by `localLLM`; neither project requires the
other.

## Optional OpenCode terminal integration

When `~/.local/share/opencode/integrations/nvim-toggleterm.lua` exists, the
toggleterm plugin automatically gains OpenCode keymaps
(`<leader>aof/aoh/aob/aol/aoo`) for launching `opencode-local`/`opencode-online`
in a floating, horizontal, or bottom split terminal. The file is owned by
`opencode`; without it, toggleterm loads normally with no OpenCode keymaps
and no errors.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --data      # also remove Neovim cache, state, and plugin data
./uninstall.sh --dry-run
```

Runtime data is retained unless `--data` is explicitly supplied.
