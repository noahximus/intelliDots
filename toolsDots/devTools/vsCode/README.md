# vsCode

Standalone VS Code installation and tracked extension set. Part of
`toolsDots/devTools` in `intelliDots`.

## Install

```bash
./install.sh
```

Installs VS Code (via Homebrew cask) and every extension listed under this
node's `extensions` in `features.yaml` (`toolsDots.devTools.vsCode`) that
isn't already present. Comment out (or delete) an extension's line there to
stop installing just that one -- nothing else to edit.

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --no-extensions
./install.sh --extensionsfile FILE|NAME   # use a flat file instead of features.yaml
```

## `--extensionsfile` format

```
publisher.extension-id
publisher.extension-id # optional comment
```

Blank lines and comments are ignored. This overrides features.yaml entirely
for the run; the default (no flag) reads features.yaml instead.

## Uninstall

```bash
./uninstall.sh           # leaves VS Code and extensions in place
./uninstall.sh --brew    # also removes the visual-studio-code cask
```

Installed extensions are never removed automatically; uninstall them
individually from VS Code if desired.
