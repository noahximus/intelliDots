# myVSCode

Standalone VS Code installation and tracked extension set. Part of
`toolsDots/devTools` in `intelliDots`.

## Install

```bash
./install.sh
```

Installs VS Code (via Homebrew cask) and every extension listed in
`VSCodeExtensions` that isn't already present.

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --no-extensions
./install.sh --extensionsfile FILE|NAME
```

## VSCodeExtensions format

```
publisher.extension-id
publisher.extension-id # optional comment
```

Blank lines and comments are ignored.

## Uninstall

```bash
./uninstall.sh           # leaves VS Code and extensions in place
./uninstall.sh --brew    # also removes the visual-studio-code cask
```

Installed extensions are never removed automatically; uninstall them
individually from VS Code if desired.
