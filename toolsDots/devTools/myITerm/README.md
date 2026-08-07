# myITerm

Standalone iTerm2 installation and preferences for macOS. Part of
`toolsDots/devTools` in `intelliDots`. This component does not depend on
`essentialDots` or any other intelliDots component.

## What it owns

- `iterm2/.config/iterm2/com.googlecode.iterm2.plist`, installed with GNU Stow
- GNU Stow, iTerm2, and the Meslo Powerlevel10k font in `Brewfile-essential`
- iTerm's custom preference-folder defaults
- older color schemes and JSON profiles under `assets/legacy` for manual import

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.devTools.myITerm
```

Or directly:

```bash
cd toolsDots/devTools/myITerm
./install.sh
```

The essential installation is the default. `--full` currently has the same
result and exists to keep the component interface consistent.

Useful options:

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --adopt
```

Restart iTerm2 after installation. It will load preferences from
`~/.config/iterm2`.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --brew       # also uninstall the iTerm2 cask
./uninstall.sh --dry-run
```

The legacy assets are reference files and are never imported automatically.
