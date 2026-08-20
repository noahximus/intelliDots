# core: installed on every machine, in every profile.
#
# These are the packages the shell configuration itself references -- the
# prompt, its font, the zsh plugins, and the CLIs that the zsh config and
# install.sh call directly. A machine that skips every other tier still
# needs these, or the stowed zsh config breaks on first shell start.

brew "stow"    # Symlink manager used to install these dotfiles.
brew "git"     # Version control.
brew "yq"      # Reads features.yaml; install.sh needs it.
brew "jq"      # Reads Homebrew JSON; install.sh needs it.

brew "eza"     # Modern ls replacement used by the zsh config.
brew "fd"      # Fast, friendly file finder; used by fzf and the shell config.
brew "fzf"     # Fuzzy finder used by shell, Git, and editor workflows.
brew "ripgrep" # Very fast text search used by shell and editor workflows.
brew "bat"     # cat with syntax highlighting and paging.
brew "zoxide"  # Frecency-ranked cd.

brew "powerlevel10k"                # Zsh prompt theme used by the shell config.
brew "zsh-autosuggestions"          # Suggests commands from shell history.
brew "zsh-fast-syntax-highlighting" # Highlights commands as you type.
cask "font-meslo-for-powerlevel10k" # MesloLGS NF font required by the prompt.
