# tmux

Standalone tmux installation, configuration, and Tmux Plugin Manager (tpm)
setup. Part of `toolsDots/devTools` in `intelliDots`.

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.devTools.tmux
```

Or directly:

```bash
cd toolsDots/devTools/tmux
./install.sh
```

Installs tmux via Homebrew, stows the tracked `tmux.conf`, and clones (or
fast-forward updates) `tpm` into `~/.tmux/plugins/tpm`.

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --adopt
```

Inside tmux, press `prefix + I` to install plugins and `prefix + U` to update
them.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --brew    # also uninstall the tmux formula
./uninstall.sh --data    # also remove theme.conf and the tpm checkout
./uninstall.sh --dry-run
```
