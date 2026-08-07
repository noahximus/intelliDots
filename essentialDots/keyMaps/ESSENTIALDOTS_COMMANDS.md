# essentialDots command reference

## Install and update

```bash
./install.sh                         # essential packages (default)
./install.sh --full                  # expanded package set
./install.sh --dry-run               # simulate Stow and link migration
./install.sh --stow-only             # update links only
./install.sh --no-brew               # skip Homebrew
./install.sh --pipx                  # install Pipxfile applications
./install.sh --macos-defaults        # also apply macOS defaults
```

## Uninstall

```bash
./scripts/uninstall.sh --dry-run
./scripts/uninstall.sh
./scripts/uninstall.sh --keep-brew
./scripts/uninstall.sh --keep-data
./scripts/uninstall.sh --full
```

## GNU Stow

```bash
stow --dir="$PWD" --target="$HOME" --restow zsh local git python aerospace borders tmux btop superfile
stow --dir="$PWD" --target="$HOME" --delete PACKAGE
```

## Shell maintenance

```bash
reload
update-zsh-plugins
dotfiles-root
```

## Project environments

```bash
venv-here                    # create .venv and direnv activation
venv-here --python python3.12
node-here                    # create .nvmrc and direnv-driven NVM switching
node-here --node 22.7.0
```

## tmux

```bash
tmux
tmux source-file ~/.config/tmux/tmux.conf
```

Inside tmux, press `prefix + I` to install plugins and `prefix + U` to update
them.

## Other intelliDots components

The following are separate components under `intelliDots`, installed via the
top-level `install.sh` (or standalone from their own directory):

```text
toolsDots/devTools/myITerm
toolsDots/devTools/myNvim
toolsDots/devTools/myVSCode
toolsDots/aiTools/myLocalLLM
toolsDots/aiTools/myOpenCode
```
