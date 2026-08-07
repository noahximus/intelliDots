# intelliDots

A single, self-contained repository for personal macOS configuration -- shell,
Git, terminal, editor, and optional AI tooling. No other repository is
required.

## Layout

```
intelliDots/
  features.yaml            # selection manifest read by install.sh
  install.sh  uninstall.sh  status.sh  update.sh  bootstrap.sh  publish-configs.sh
  install-essential.sh     # fixed choice: every node, essential profile
  install-everything.sh    # fixed choice: every node, full profile
  essentialDots/           # core shell, Git, tmux, macOS tools, general config
  toolsDots/
    devTools/
      myITerm/              # iTerm2 application, profiles, colors, preferences
      myNvim/                # Neovim, LazyVim, plugins, editor tooling
      myVSCode/              # VS Code application and tracked extensions
    aiTools/
      myLocalLLM/            # llama.cpp runtime, models, wrapper
      myOpenCode/            # OpenCode and optional local-model bridge
```

Each node under `essentialDots`/`toolsDots/*` is independently installable --
`cd` into it and run its own `install.sh`/`uninstall.sh` directly -- and owns
its own packages, files, state, and documentation.

## Quick start

```bash
./install.sh
```

Installs the nodes marked `default: true` in `features.yaml` (`essentialDots`,
`myITerm`, `myNvim`) at the essential profile. Optional nodes (`myVSCode`,
`myLocalLLM`, `myOpenCode`) are opt-in:

```bash
./install.sh --only toolsDots.aiTools.myLocalLLM
./install.sh --all                    # every node, not just the defaults
./install.sh --list                   # show every node and its default flag
./install.sh --skip toolsDots.devTools.myVSCode
./install.sh --dry-run
./install.sh --full
```

`install-essential.sh` and `install-everything.sh` are fixed-choice wrappers
(every node, no picking) -- use `install.sh` directly for anything more
selective.

### One-file fresh-Mac bootstrap

Download `bootstrap.sh`, then run it. It creates `~/Developer/myConfigs`,
saves a reusable copy of itself there, installs Apple's command-line tools,
Homebrew, GitHub CLI, and `yq` as needed, authenticates GitHub, clones (or
updates) `intelliDots`, and runs `install.sh --essential --macos-defaults`.

```bash
chmod +x "$HOME/Downloads/bootstrap.sh"
"$HOME/Downloads/bootstrap.sh"
./bootstrap.sh --full
./bootstrap.sh --dry-run
./bootstrap.sh --root "$HOME/Developer/myConfigs"
```

## `features.yaml`

An ordered list of installable nodes; each points at a directory relative to
this file, no repository URL, since everything is one checkout:

```yaml
nodes:
  - id: essentialDots
    path: essentialDots
    default: true
  - id: toolsDots.aiTools.myLocalLLM
    path: toolsDots/aiTools/myLocalLLM
    default: false
    nvim_integration: codecompanion
    nvim_integration_path: "~/.local/share/local-llm/integrations/codecompanion.lua"
```

`install.sh` installs nodes top-to-bottom; `uninstall.sh` uninstalls
bottom-to-top. `nvim_integration*` fields are descriptive only -- see below.

## AI tools automatically customize Neovim (and skip cleanly without it)

Installing `myLocalLLM` or `myOpenCode` enables matching Neovim customization
-- CodeCompanion for `myLocalLLM`, terminal keymaps for `myOpenCode` -- with
no explicit wiring in `install.sh`. Each AI component stows a small Lua spec
to a well-known path under `~/.local/share`, and the corresponding `myNvim`
plugin file checks for that file **at Neovim startup** (not at install time)
and loads it if present:

- `myLocalLLM` -> `~/.local/share/local-llm/integrations/codecompanion.lua`,
  loaded by `myNvim`'s `plugins/codecompanion.lua`.
- `myOpenCode` -> `~/.local/share/opencode/integrations/nvim-toggleterm.lua`,
  loaded by `myNvim`'s `plugins/opencode.lua`.

Because the check happens at Neovim startup rather than install time, install
order never matters, and installing either AI tool without `myNvim` is always
safe: the stowed file just sits unused on disk. Installing `myNvim` without
either AI tool is equally safe: both plugin files fall back to a default (or
to contributing nothing) with no errors and no dead keymaps.

`status.sh` reports whether each integration is currently active.

## Other commands

```bash
./status.sh                          # each node's presence + AI integration state
./uninstall.sh                       # uninstall every node, bottom-to-top
./uninstall.sh --only essentialDots
./update.sh                          # git pull --ff-only, then re-run install.sh
./publish-configs.sh --dry-run       # commit + push this checkout to GitHub
```

## Essential-first policy

The default requests the essential profile from every component:

```bash
./install.sh
./install.sh --essential
```

Expanded optional packages are explicit:

```bash
./install.sh --full
```

Components without a distinct full profile accept `--full` and install their
essential set regardless.
