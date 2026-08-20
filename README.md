# intelliDots

A single, self-contained repository for personal macOS configuration -- shell,
Git, terminal, editor, and optional AI tooling. No other repository is
required.

## Layout

```
intelliDots/
  profiles/                # what to install: air, daily, everything
  tiers/                   # what each tier contains, as Brewfiles
  features.yaml            # node registry: tier + path + options per node
  install.sh  uninstall.sh  status.sh  sync.sh  bootstrap.sh  ship.sh
  essentialDots/           # core shell, Git, macOS tools, general config
  toolsDots/
    devTools/
      iTerm/               # iTerm2 application, profiles, colors, preferences
      nvim/                # Neovim, LazyVim, plugins, editor tooling
      vsCode/              # VS Code application and tracked extensions
      tmux/                # tmux, its config, and the tpm plugin manager
      superfile/           # Superfile terminal file manager and themes
    aiTools/
      aiApps/              # ChatGPT, Claude, Claude Code (+ Gemini CLI, Antigravity)
      localLLM/            # llama.cpp runtime, models, wrapper
      opencode/            # OpenCode and optional local-model bridge
```

Each node under `essentialDots`/`toolsDots/*` is independently installable --
`cd` into it and run its own `install.sh`/`uninstall.sh` directly -- and owns
its own files, state, and documentation. Packages are the exception: they are
declared centrally in `tiers/`, not per node, so running a node directly
installs its configuration only.

## Quick start

```bash
./install.sh
```

That installs the `daily` profile. Pick a different one for a different kind
of machine:

```bash
./install.sh --profile air          # not a development machine
./install.sh --profile everything   # every tier except optional
./install.sh --profile air --list   # preview the resolved plan
./install.sh --dry-run
```

| Profile | Tiers | Nodes | Packages |
| --- | --- | --- | --- |
| `air` | core, mac-essentials, ai-essentials | 3 | 33 |
| `daily` (default) | adds dev-essentials | 7 | 55 |
| `everything` | every tier but optional | 9 | 85 |

`air` is for a Mac you do not write code on: the desktop, the applications,
and the AI assistants, with no language runtimes, editors, or build tooling.

### One-file fresh-Mac bootstrap

Download `bootstrap.sh`, then run it. It creates `~/Developer/myConfigs`,
saves a reusable copy of itself there, installs Apple's command-line tools,
Homebrew, GitHub CLI, and `yq` as needed, authenticates GitHub, clones (or
updates) `intelliDots`, and runs `install.sh` with the chosen profile and
`--macos-defaults`.

```bash
chmod +x "$HOME/Downloads/bootstrap.sh"
"$HOME/Downloads/bootstrap.sh"           # daily, the default
"$HOME/Downloads/bootstrap.sh" --air
./bootstrap.sh --everything
./bootstrap.sh --dry-run
./bootstrap.sh --root "$HOME/Developer/myConfigs"
```

## Tiers and profiles

A **tier** is a set of packages and the nodes that go with them. There are
seven, on two axes -- domain (`mac`, `dev`, `ai`) and depth (`essentials`,
`extras`) -- plus `core`, which every profile installs:

| Tier | Holds |
| --- | --- |
| `core` | The shell config's own dependencies: stow, git, yq, jq, prompt, fzf, ripgrep... |
| `mac-essentials` | AeroSpace, borders, Stats, the everyday applications |
| `mac-extras` | Media and document conversion, extra browsers, work chat |
| `dev-essentials` | Editors, terminals, Git tooling, Python and Node toolchains |
| `dev-extras` | Database and API clients, CLI analysis tools |
| `ai-essentials` | Claude, Claude Code, ChatGPT, OpenCode |
| `ai-extras` | Local model runtimes, Gemini CLI, Antigravity |

Each tier is a Brewfile in `tiers/`. A **profile** in `profiles/` is just a
list of the tiers it wants:

```yaml
# profiles/air.yaml
tiers:
  - core
  - mac-essentials
  - ai-essentials

options:
  essentialDots:
    macos-defaults: true
    pipx: false
```

`install.sh` reads the profile, takes its tier list, and does two things with
it: merges those tiers' Brewfiles into one deduplicated `brew bundle` run,
and installs every node in `features.yaml` whose `tier` is in the list.

That single list is the point. A node and its packages are selected by one
decision, so they cannot disagree -- the editor cannot arrive without the
extensions that configure it.

Write your own profile by dropping a YAML file into `profiles/`; it needs
only a `tiers:` list. Select tiers directly, without a profile, when you want
a one-off combination:

```bash
./install.sh --tier core --tier mac-essentials
```

### features.yaml

`features.yaml` is the node registry: each node's `tier`, `path`, default
`options`, and (for the AI components) Neovim integration metadata.

```yaml
nodes:
  - id: toolsDots.aiTools.localLLM
    tier: ai-extras
    path: toolsDots/aiTools/localLLM
    options:
      with-local-llm: true
      with-turbo-fieldfare: false
    nvim_integration: codecompanion
    nvim_integration_path: "~/.local/share/local-llm/integrations/codecompanion.lua"
```

`options` are boolean flags forwarded to that node's own `install.sh` as
`--<key>` when the effective value is `true`. A profile's own `options` for a
node override these key-by-key; a matching CLI flag forces one on or off for
a single run on top of both:

```bash
./install.sh --no-macos-defaults    # install the profile, leave System Settings alone
./install.sh --no-pipx
./install.sh --with-turbo-fieldfare
./install.sh --no-turbo-fieldfare
```

`--no-<key>` beats everything, including `--<key>` in the same command and in
either order. Turning something off is the safe direction, so an explicit
refusal is never silently overridden.

Nodes install in the order they appear in `features.yaml`. `--only` and
`--skip` narrow a run further, but they narrow *within* the selected tiers --
`--only` cannot reach a node whose tier the profile did not select:

```bash
./install.sh --skip toolsDots.devTools.vsCode

# localLLM is ai-extras, so daily does not select it; name a profile that
# does, or select the tier directly.
./install.sh --profile everything --only toolsDots.aiTools.localLLM
./install.sh --tier ai-extras --only toolsDots.aiTools.localLLM --with-turbo-fieldfare
```

## The optional tier

`tiers/optional.Brewfile` is a catalogue, not a queue. Every line in it is
commented out and **no profile ever installs it**. It holds the choices that
are mutually exclusive or machine-specific -- Docker Desktop versus OrbStack,
Raycast versus Maccy, `uv`, the work-chat apps -- written down next to each
other with the tradeoff in a comment.

Install one by name:

```bash
./install.sh --pick orbstack
./install.sh --pick raycast --pick uv
```

`--pick` uncomments just that line into the merged Brewfile for one run and
leaves the file untouched. Because the file stays commented, an uninstall
never sweeps up something you picked deliberately.

## TG Pro is chosen by hardware, not by tier

TG Pro only makes sense on a Mac that has fans, so it is not in any tier.
`install.sh` adds it to the merged Brewfile when `mac-essentials` is selected
*and* the machine has fans, and `macos-defaults.sh` writes its preferences
under the same condition plus TG Pro actually being installed. Both read
`machine_has_fans()` from `essentialDots/scripts/lib/hardware.sh`, so they
cannot disagree.

Every Apple Silicon MacBook Air is fanless, so an Air skips it and Stats owns
the menu-bar temperature readout instead. `./install.sh --pick tg-pro` forces
the app on anyway; its fan-related preferences still will not be written on a
machine with no fans.

`./status.sh` reports the decision this machine gets.

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
./status.sh                          # tiers, node selection, integrations, TG Pro
./status.sh --profile air            # resolve against a different profile
./uninstall.sh                       # uninstall every node, bottom-to-top
./uninstall.sh --tier ai-essentials  # drop a whole tier
./uninstall.sh --only essentialDots
./sync.sh                            # git pull --ff-only, then re-run install.sh
./sync.sh --profile air              # arguments pass straight through
./ship.sh --dry-run                  # commit + push this checkout to GitHub
```

`--essential` and `--full` still work on `install.sh` and `bootstrap.sh` as
deprecated aliases for `--profile daily` and `--profile everything`. They
print a notice and will be removed.

## A note on bash

These scripts run on a fresh Mac, before `install.sh` has bootstrapped
Homebrew -- so `/usr/bin/env bash` is still macOS's system bash **3.2**.
Nothing here may use bash 4+ features: no `mapfile`/`readarray`, no
associative arrays, no `${var^^}`. Check changes with `/bin/bash -n`, not
just the Homebrew bash on your PATH.
