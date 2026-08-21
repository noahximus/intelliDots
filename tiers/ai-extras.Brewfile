# ai-extras: additional AI tooling that is not wired into anything here.
#
# The distinction against ai-local is integration, not where the model runs.
# ai-local is the stack this repository actually builds on: llama.cpp, the
# local-llm wrapper, its two LaunchAgents, and the CodeCompanion Neovim
# integration that points at it. Anything in ai-extras stands alone -- useful
# on its own terms, but nothing in these dotfiles depends on it and nothing
# breaks when it is absent.
#
# TurboFieldfare is not here -- it stays behind localLLM's own
# --with-turbo-fieldfare option, since it needs macOS 26, Xcode 26, Apple
# Silicon, and roughly 14GB of model weights.
#
# Gemini CLI, Antigravity, and Aider went to optional.Brewfile: ai-essentials
# already installs Claude, Claude Code, ChatGPT and OpenCode, so each of those
# was a fourth or fifth tool doing a job two existing ones already do.

cask "lm-studio" # Model browser, chat UI, and OpenAI-compatible local server.
                 # Its value over llama.cpp is the browser: it sizes GGUF
                 # quantizations against available RAM before downloading.
