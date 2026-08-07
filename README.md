# intelliDots

A single, self-contained repository for personal macOS configuration -- shell,
Git, terminal, editor, and optional AI tooling. No other repository is
required.

## Layout

```
intelliDots/
  features.yaml            # master node registry: path + default options per node
  features-default.yaml    # selection: what a plain ./install.sh installs
  features-essential.yaml  # selection: every node, essential profile
  features-all.yaml        # selection: every node, full profile
  install.sh  uninstall.sh  status.sh  sync.sh  bootstrap.sh  ship.sh
  essentialDots/           # core shell, Git, macOS tools, general config
  toolsDots/
    devTools/
      iTerm/              # iTerm2 application, profiles, colors, preferences
      nvim/                # Neovim, LazyVim, plugins, editor tooling
      vsCode/              # VS Code application and tracked extensions
      tmux/                # tmux, its config, and the tpm plugin manager
      superfile/            # Superfile terminal file manager and themes
    aiTools/
      aiApps/              # ChatGPT, Claude, Claude Code (+ Gemini CLI, Antigravity)
      localLLM/            # llama.cpp runtime, models, wrapper
      opencode/            # OpenCode and optional local-model bridge
```

Each node under `essentialDots`/`toolsDots/*` is independently installable --
`cd` into it and run its own `install.sh`/`uninstall.sh` directly -- and owns
its own packages, files, state, and documentation.

## Quick start

```bash
./install.sh
```

With no `--file`, installs every node listed in `features-default.yaml`
(`essentialDots`, `iTerm`, `nvim`, `tmux`, `superfile`, `aiApps`) at the
essential profile. Pick a different selection file for a different set:

```bash
./install.sh --file features-essential.yaml   # every node, essential profile
./install.sh --file features-all.yaml         # every node, full profile
./install.sh --file features-essential.yaml --list   # preview the resolved plan
./install.sh --only toolsDots.aiTools.localLLM        # narrow within a selection
./install.sh --skip toolsDots.devTools.vsCode
./install.sh --dry-run
```

Write your own `features-*.yaml` for anything else -- it only needs a
`profile:` and a `nodes:` list of ids; see `features.yaml` (the master
registry) for the available ids, and the "features.yaml" section below for
the file format.

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

## `features.yaml` and selection files

Two tiers. `features.yaml` is the master registry -- every node's `path` and
default `options`, plus AI nodes' `nvim_integration` metadata:

```yaml
nodes:
  - id: essentialDots
    path: essentialDots
    options:
      macos-defaults: false
      pipx: false
  - id: toolsDots.aiTools.localLLM
    path: toolsDots/aiTools/localLLM
    options:
      with-local-llm: true
      with-turbo-fieldfare: false
    nvim_integration: codecompanion
    nvim_integration_path: "~/.local/share/local-llm/integrations/codecompanion.lua"
```

`install.sh` is never pointed at `features.yaml` directly -- it takes a
**selection file** via `--file` (`features-default.yaml` if omitted), which
just lists which node ids to install, in order, plus an optional top-level
`profile:` and per-node `options` overrides:

```yaml
profile: essential
nodes:
  - id: essentialDots
    options:
      macos-defaults: true
      pipx: true
  - id: toolsDots.aiTools.localLLM
```

Each id's `path` and default `options` still come from `features.yaml`; the
selection file only needs to override what it wants different. Nodes install
in the selection file's order, top-to-bottom. `uninstall.sh` reads
`features.yaml` directly rather than a selection file -- it defaults to
uninstalling every node, bottom-to-top. `nvim_integration*` fields are
descriptive only -- see below.

A node's effective `options` are `features.yaml`'s defaults, overridden
key-by-key by the selection file's own `options` for that node, overridden
again by a matching `--macos-defaults` / `--pipx` / `--with-turbo-fieldfare`
CLI flag for a single run. Each `true` key gets forwarded to that node's own
`install.sh` as `--<key>` -- this is what decides, for example, whether
`localLLM` installs the llama.cpp backend, TurboFieldfare, both, or neither.

```bash
./install.sh --only toolsDots.aiTools.localLLM --with-turbo-fieldfare
./install.sh --file features-essential.yaml --list   # preview without installing
```

## AI tools automatically customize Neovim (and skip cleanly without it)

Installing `localLLM` or `opencode` enables matching Neovim customization
-- CodeCompanion for `localLLM`, terminal keymaps for `opencode` -- with
no explicit wiring in `install.sh`. Each AI component stows a small Lua spec
to a well-known path under `~/.local/share`, and the corresponding `nvim`
plugin file checks for that file **at Neovim startup** (not at install time)
and loads it if present:

- `localLLM` -> `~/.local/share/local-llm/integrations/codecompanion.lua`,
  loaded by `nvim`'s `plugins/codecompanion.lua`.
- `opencode` -> `~/.local/share/opencode/integrations/nvim-toggleterm.lua`,
  loaded by `nvim`'s `plugins/opencode.lua`.

Because the check happens at Neovim startup rather than install time, install
order never matters, and installing either AI tool without `nvim` is always
safe: the stowed file just sits unused on disk. Installing `nvim` without
either AI tool is equally safe: both plugin files fall back to a default (or
to contributing nothing) with no errors and no dead keymaps.

`status.sh` reports whether each integration is currently active.

## Other commands

```bash
./status.sh                          # each node's presence + AI integration state
./uninstall.sh                       # uninstall every node, bottom-to-top
./uninstall.sh --only essentialDots
./sync.sh                            # git pull --ff-only, then re-run install.sh
./ship.sh --dry-run                  # commit + push this checkout to GitHub
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
