# optional: catalogued, never installed by a profile.
#
# Every line here is commented out on purpose. No profile pulls this tier;
# entries are installed one at a time by name:
#
#   ./install.sh --pick orbstack
#   ./install.sh --pick raycast --pick uv
#
# --pick matches the quoted token, uncomments just that line into the merged
# Brewfile for a single run, and leaves this file untouched. Keeping the
# alternatives written down next to each other is the point: this file is a
# decision record, not a queue.

# Containers -- pick one; both provide the `docker` CLI and will conflict.
# cask "docker-desktop" # Heavier; includes Kubernetes and the GUI dashboard.
# cask "orbstack"       # Much lighter on RAM and battery; drop-in docker CLI.

# Launchers and clipboard -- overlapping; Raycast includes clipboard history.
# cask "raycast" # Launcher + clipboard history + window management + snippets.
# cask "maccy"   # Clipboard history only, much smaller.

# Local model runtimes -- alternatives to ai-local's llama.cpp, which is the
# one the local-llm wrapper and the CodeCompanion integration actually use.
# Nothing in this repository is wired to either of these.
# cask "ollama-app" # Local model runner, GUI plus a background daemon.
# cask "lm-studio"  # GUI model browser and runner.

# Python
# brew "uv" # Fast installer; can pin CPython itself. Potential pyenv replacement.

# Thermals -- appended automatically by install.sh on a Mac that has fans.
# Listed here so --pick can force it onto a fanless machine for testing.
# cask "tg-pro" # Per-sensor thermal detail and fan control.

# Work communication -- install per employer, not per machine.
# cask "microsoft-teams" # Microsoft Teams desktop client.
# cask "amazon-chime"    # Amazon Chime desktop client.
