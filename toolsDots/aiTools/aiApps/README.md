# aiApps

Tracked AI desktop and CLI applications, installed via Homebrew. Part of
`toolsDots/aiTools` in `intelliDots`. No dotfile payload -- this component
only manages a Brewfile.

## What it owns

- `cask "chatgpt"` -- OpenAI's official ChatGPT desktop app
- `cask "claude"` -- Anthropic's official Claude desktop app
- `cask "claude-code"` -- Anthropic's official Claude Code CLI app
- `brew "gemini-cli"` -- Google's Gemini command-line AI assistant (`--full` only)
- `cask "antigravity"` -- Google's AI-powered development environment (`--full` only)

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.aiTools.aiApps
```

Or directly:

```bash
cd toolsDots/aiTools/aiApps
./install.sh
```

```bash
./install.sh --full        # also installs Gemini CLI and Antigravity
./install.sh --dry-run
./install.sh --no-brew
```

## Uninstall

```bash
./uninstall.sh              # removes ChatGPT, Claude, Claude Code
./uninstall.sh --full       # also removes Gemini CLI and Antigravity
./uninstall.sh --dry-run
```
