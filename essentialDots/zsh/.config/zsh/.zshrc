source $HOME/.config/zsh/.zshenv
source $HOME/.config/zsh/.zprofile
source $HOME/.config/zsh/.zshp10k
source $HOME/.config/zsh/.p10k.zsh

# Load aliases if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/.aliases" ] && . "${XDG_CONFIG_HOME}/zsh/.aliases"
[ -f "${XDG_CONFIG_HOME}/zsh/.aliases.local" ] && . "${XDG_CONFIG_HOME}/zsh/.aliases.local"

# Load external shell integrations if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/.external" ] && . "${XDG_CONFIG_HOME}/zsh/.external"
[ -f "${XDG_CONFIG_HOME}/zsh/.external.local" ] && . "${XDG_CONFIG_HOME}/zsh/.external.local"

# Load functions if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/.functions" ] && . "${XDG_CONFIG_HOME}/zsh/.functions"
[ -f "${XDG_CONFIG_HOME}/zsh/.functions.local" ] && . "${XDG_CONFIG_HOME}/zsh/.functions.local"

# Load python specific configs if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/apps/pythonrc" ] && . "${XDG_CONFIG_HOME}/zsh/apps/pythonrc"

# Load border specific configs if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/apps/bordersrc" ] && . "${XDG_CONFIG_HOME}/zsh/apps/bordersrc"

# Load nvm specific configs if they exist.
[ -f "${XDG_CONFIG_HOME}/zsh/apps/nvmrc" ] && . "${XDG_CONFIG_HOME}/zsh/apps/nvmrc"

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

if command -v conda >/dev/null 2>&1; then
  __conda_setup="$(conda shell.zsh hook 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  fi
  unset __conda_setup
fi

export PATH="$HOME/.local/bin:$PATH"

# App-provided command-line helpers.
[[ -d "$HOME/.antigravity/antigravity/bin" ]] && export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
[[ -d "$HOME/.antigravity-ide/antigravity-ide/bin" ]] && export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
[[ -d "/Applications/ChatGPT.app/Contents/Resources" ]] && export PATH="/Applications/ChatGPT.app/Contents/Resources:$PATH"

# Load direnv config if it exists.
[ -f "${XDG_CONFIG_HOME}/zsh/apps/direnvrc" ] && . "${XDG_CONFIG_HOME}/zsh/apps/direnvrc"

# Load generated theme config if it exists.
[ -f "${XDG_CONFIG_HOME}/zsh/apps/themerc" ] && . "${XDG_CONFIG_HOME}/zsh/apps/themerc"
