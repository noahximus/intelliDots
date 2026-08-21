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

# Coding agents -- Claude Code and OpenCode are in ai-essentials and cover
# this ground already, so a third is a duplicate rather than an addition.
# brew "aider" # Terminal pair-programming agent; model-agnostic, commits to git.

# HTTP clients -- curl ships with macOS and does the same work; this is
# ergonomics for poking at APIs by hand, not a missing capability.
# brew "httpie" # Friendly HTTP client: JSON bodies and colorized output.

# GUI clients -- no database or HTTP work in this setup declares a need for
# these, and both are heavier than the CLI tools already installed.
# cask "tableplus" # Database GUI.
# cask "bruno"     # Local-first API client; requests stored as files in git.

# Messaging -- WhatsApp and Viber are in mac-essentials; this one was
# commented out of the old Brewfile-essential, so it stays opt-in. Being in
# mac-extras was not enough, since the full profiles take every tier.
# cask "messenger" # Facebook Messenger desktop app.

# Work communication -- which one depends on the employer, not the machine.
# cask "slack" # Team chat and messaging.
# cask "zoom"  # Video meetings.

# Mac utilities
# cask "keka" # Archives beyond zip: rar, 7z, split and encrypted.
# brew "mas"  # Mac App Store CLI. Enables `mas "App", id: N` lines in a
            # Brewfile -- nothing here uses that yet.

# CLI tools that improve on something already working. Kept out of
# dev-extras because ps, wc and a stopwatch are not actually broken.
# brew "procs"     # Process viewer; ps replacement.
# brew "tokei"     # Source lines of code, per language.
# brew "hyperfine" # Benchmarks a command over many runs; compares two.

# Python
# brew "uv" # Fast installer; can pin CPython itself. Potential pyenv replacement.

# Thermals -- appended automatically by install.sh on a Mac that has fans.
# Listed here so --pick can force it onto a fanless machine for testing.
# cask "tg-pro" # Per-sensor thermal detail and fan control.

# Work communication -- install per employer, not per machine.
# cask "microsoft-teams" # Microsoft Teams desktop client.
# cask "amazon-chime"    # Amazon Chime desktop client.
