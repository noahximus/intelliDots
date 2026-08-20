# ai-local: running models on this machine, as opposed to calling someone
# else's.
#
# Split out of ai-extras because it is a different commitment: the localLLM
# node that comes with this tier stows the local-llm wrapper, writes two
# (disabled) LaunchAgents, and enables the CodeCompanion Neovim integration.
# None of that has anything to do with the cloud assistants in ai-extras, and
# there are machines that want one and not the other.
#
# Only llama.cpp is here. ollama-app and lm-studio are alternative runtimes
# that duplicate it without being wired into anything in this repository, so
# they live in optional.Brewfile: ./install.sh --pick ollama-app
#
# Soft dependency on dev-essentials: the model downloader is huggingface-hub,
# installed through pipx, and pipx is a dev-essentials formula. Selecting
# ai-local without it still gives a working runtime, but no `hf` for
# authenticated or gated downloads. The node says so when it skips.

brew "llama.cpp" # Local model runtime; backs the local-llm wrapper.
