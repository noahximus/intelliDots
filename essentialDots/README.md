# essentialDots

Core personal macOS dotfiles managed with GNU Stow. Part of `intelliDots`.
Application-specific iTerm, Neovim, VS Code, tmux, Superfile, local-LLM, and
OpenCode configuration live in their own `toolsDots` components.

## Scope

This component owns:

- Zsh and Powerlevel10k shell configuration
- Git configuration and global ignore rules
- AeroSpace, borders, and btop configuration
- Python/IPython configuration
- general scripts under `~/.local/bin`
- shared macOS defaults and bootstrap helpers

It deliberately does **not** install or configure iTerm2, Neovim/LazyVim, VS
Code, tmux, Superfile, local LLM services, or OpenCode -- those live under
`toolsDots`.

## Install

From the `intelliDots` root:

```bash
./install.sh --only essentialDots
```

Or directly:

```bash
cd essentialDots
./install.sh
```

## Essential-first package policy

The default installation uses `Brewfile-essential`:

```bash
./install.sh
./install.sh --essential
```

The expanded application list is opt-in:

```bash
./install.sh --full
```

Use a custom package manifest when needed:

```bash
./install.sh --brewfile /path/to/Brewfile
```

## Installer options

```text
--adopt              Let Stow adopt existing target files into this checkout.
--dry-run            Inspect stale links and simulate Stow.
--stow-only          Update links without installing runtimes or packages.
--no-brew            Skip Homebrew Bundle.
--essential          Select Brewfile-essential (default).
--full               Select the expanded Brewfile.
--brewfile FILE      Select another Brewfile.
--pipx               Install applications listed in Pipxfile.
--pipxfile FILE      Select another Pipxfile and run the pipx stage.
--macos-defaults     Apply the tracked macOS defaults.
```

Examples:

```bash
./install.sh --dry-run
./install.sh --stow-only
./install.sh --full --pipx --macos-defaults
./install.sh --no-brew --macos-defaults
```

VS Code and its extensions are a separate component: `toolsDots/devTools/vsCode`.

The macOS defaults profile also configures TG Pro for conservative monitoring:
TG Pro launches at login, shows the highest CPU temperature in Celsius, checks
for updates, keeps file logging off, and leaves fan control with macOS. It does
not store a TG Pro license, device-specific sensor data, or a custom fan curve.
Quit and reopen TG Pro after applying the defaults if it was already running.

## Stow packages and destinations

The installer manages these packages against `$HOME`:

```text
zsh local git python aerospace borders btop
```

The checkout location is recorded in
`${XDG_STATE_HOME:-~/.local/state}/essentialDots/stow-root`, allowing stale
links from an older checkout path to be migrated safely.

## Updates

From the `intelliDots` root:

```bash
./update.sh
```

The installer uses `brew bundle --no-upgrade`, skips already-installed casks,
installs configured Node and Python runtimes, updates Oh My Zsh and TPM with
fast-forward pulls, and restows managed files.

## Uninstall

Preview first:

```bash
./scripts/uninstall.sh --dry-run
```

Then uninstall configuration and packages owned by this component:

```bash
./scripts/uninstall.sh
```

Useful safeguards:

```bash
./scripts/uninstall.sh --keep-brew
./scripts/uninstall.sh --keep-data
./scripts/uninstall.sh --full       # when the expanded profile was installed
./scripts/uninstall.sh --pipx
```

The uninstaller does not modify iTerm2 preferences, Neovim data, VS Code
extensions, OpenCode, or local-LLM LaunchAgents, models, or logs. Those
resources belong to their own `toolsDots` components.

## Command reference

See [`keyMaps/ESSENTIALDOTS_COMMANDS.md`](keyMaps/ESSENTIALDOTS_COMMANDS.md)
for the core installer, maintenance, Stow, shell, and macOS commands.

## Project environment helpers

Create a Python project environment that activates automatically with direnv:

```bash
mkdir my-python-project && cd my-python-project
venv-here
```

Create a Node project that pins and automatically switches its NVM version:

```bash
mkdir my-node-project && cd my-node-project
node-here
```

Choose a specific Node version with `node-here --node 22.7.0`. The helper
creates `.nvmrc` and a managed `.envrc`, installs the version when necessary,
and runs `direnv allow`.
