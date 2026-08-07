# myOpenCode

Standalone OpenCode installation and configuration. Part of `toolsDots/aiTools`
in `intelliDots`. Normal hosted-provider use does not require `myLocalLLM`,
`essentialDots`, or another intelliDots component.

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.aiTools.myOpenCode
```

Or directly:

```bash
cd toolsDots/aiTools/myOpenCode
./install.sh
```

The essential package set is the default. `--full` currently produces the same
installation and is accepted for a consistent component interface.

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --adopt
```

The repository installs:

- OpenCode from its maintained Homebrew tap
- `~/.config/opencode/opencode.json`, a provider-neutral base configuration
- `~/.config/opencode/opencode-local.json`, an optional local endpoint setup
- `~/.config/opencode/tui.json`, selecting the terminal-aware `system` theme
- `~/.local/bin/opencode-online`, the hosted OpenAI/Codex helper
- `~/.local/bin/opencode-local`, an optional integration helper

## Online OpenAI and Codex

`opencode-online` is a small wrapper around OpenCode's native provider and
credential commands. It does not proxy requests, copy credentials, or change
OpenCode's model behavior.

### Prerequisites

- OpenCode installed by this repository
- An internet connection and browser
- A ChatGPT Plus or Pro subscription, or an OpenAI API key

Confirm that the helper and OpenCode are available:

```bash
command -v opencode
command -v opencode-online
opencode --version
```

### First-time ChatGPT setup

Start the connection flow:

```bash
opencode-online setup
```

The helper opens OpenCode's native OpenAI login flow. Select **ChatGPT
Plus/Pro**, complete the browser authorization using the desired ChatGPT
account, then return to the terminal.

Verify that OpenCode saved an OpenAI credential:

```bash
opencode-online status
```

If setup succeeded, the output lists OpenAI instead of reporting zero
credentials. Credentials are stored by OpenCode in the user's data directory,
normally `~/.local/share/opencode/auth.json`. They are never written to this
repository.

### Models and normal use

List models currently available from OpenAI:

```bash
opencode-online models
```

Launch OpenCode with its normal hosted-provider configuration:

```bash
opencode-online run
```

Inside OpenCode, use `/models` to select an available Codex model. The selected
model is managed by OpenCode and can change as the provider's available model
catalog changes.

Arguments following `run` are passed directly to OpenCode:

```bash
opencode-online run --help
opencode-online run /path/to/project
```

## Optional integrations

- `myNvim` automatically loads this project's stowed toggleterm keymaps
  (`<leader>aof/aoh/aob/aol/aoo`) when it detects this repository's installed
  integration file at `~/.local/share/opencode/integrations/nvim-toggleterm.lua`.
  Without `myOpenCode` installed, `myNvim`'s toggleterm plugin loads normally
  with no OpenCode-specific keymaps and no errors.

Neither `myNvim` nor this integration is required for the core `opencode-online`/
`opencode-local` workflow.

Running `opencode` directly is equivalent for normal hosted-provider use:

```bash
opencode
```

The base `opencode.json` remains provider-neutral so hosted OpenAI and optional
local-model workflows do not override each other.

### API-key alternative

Run `opencode-online setup`, select the manual API-key method instead of
ChatGPT Plus/Pro, and enter the key when OpenCode prompts. Do not place an API
key in `opencode.json` or commit it to Git.

### Sign out or change accounts

Use OpenCode's native logout command, then repeat setup:

```bash
opencode auth logout openai
opencode-online setup
```

### Troubleshooting

If `opencode-online` is missing, reinstall or restow this component and start
a new shell:

```bash
cd toolsDots/aiTools/myOpenCode   # from your intelliDots checkout
./install.sh
exec "$SHELL" -l
```

If status reports zero credentials, repeat `opencode-online setup` and finish
the browser authorization. If OpenAI models do not appear, refresh the model
catalog and check again:

```bash
opencode models --refresh
opencode-online models
```

## Optional local models

If `myLocalLLM` is also installed:

```bash
opencode-local run
opencode-local status
opencode-local models
opencode-local doctor
```

The helper checks for `local-llm` and reports a clear error when the
optional integration is unavailable. Installing this project never installs or
starts a local model runtime.

## Terminal transparency

The tracked `tui.json` selects OpenCode's built-in `system` theme. It inherits
the terminal's default background instead of drawing an opaque color, allowing
iTerm2 profile transparency and blur to remain visible behind the OpenCode TUI.

Restart OpenCode after changing this file. Selecting a fixed-background theme
with `/theme` may make the interface appear opaque again.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --dry-run
```

The OpenCode Homebrew package is retained so uninstalling configuration cannot
unexpectedly remove an application shared with other workflows.
