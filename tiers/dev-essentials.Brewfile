# dev-essentials: editors, terminals, version control, and the language
# runtimes needed to actually write code on this machine.
#
# No container runtime here on purpose -- docker-desktop and orbstack both
# live in optional.Brewfile, since they conflict on the docker CLI and the
# choice is per-machine. Install one with: ./install.sh --pick orbstack

cask "iterm2"              # Terminal emulator configured by the iTerm dotfiles.
cask "visual-studio-code"  # GUI code editor.
brew "neovim"              # Terminal editor configured by the nvim dotfiles.
brew "tmux"                # Terminal multiplexer configured by the tmux dotfiles.

brew "gh"        # GitHub CLI for repositories, pull requests, issues, and auth.
brew "git-delta" # Syntax-highlighted, readable git diffs.
brew "lazygit"   # Terminal UI for git.

brew "cmake"  # Build system generator needed by native packages and tooling.
brew "direnv" # Automatically loads per-project environment variables.
brew "node"   # JavaScript runtime used by command-line development workflows.
brew "nvm"    # Node.js version manager loaded by the zsh config.

brew "pipx"                     # Installs Python CLI apps in isolated virtualenvs.
brew "pyenv"                    # Python version manager for modern runtimes.
brew "pyenv-virtualenv"         # Pyenv plugin for Python virtual environments.
brew "pyenv-virtualenvwrapper"  # Virtualenvwrapper integration for pyenv.
brew "openssl@3" # TLS library used when building Python versions with pyenv.
brew "readline"  # Command-line editing library used by pyenv-built Python.
brew "sqlite"    # SQLite support used by pyenv-built Python.
brew "xz"        # Compression library used when building Python with pyenv.
brew "zlib"      # Compression library required by many build and language tools.
brew "tcl-tk"    # Tk 9.x; pyenv links _tkinter against it for Python 3.13+.
brew "tcl-tk@8"  # Tk 8.6 (keg-only); _tkinter for Python 3.10-3.12, which target Tk 8.6.
