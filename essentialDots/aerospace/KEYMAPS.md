# AeroSpace Keymaps

This is the quick reference for the active AeroSpace config at:

```text
~/.config/aerospace/aerospace.toml
```

The main modifier is `alt`.

## Launch

| Key | Action |
| --- | --- |
| `alt-enter` | Open Terminal |

## Layout

| Key | Action |
| --- | --- |
| `alt-shift-space` | Cycle tiles layout orientation |
| `alt-comma` | Cycle accordion layout orientation |
| `alt-shift-f` | Toggle fullscreen |

## Focus Windows

| Key | Action |
| --- | --- |
| `alt-h` | Focus left |
| `alt-j` | Focus down |
| `alt-k` | Focus up |
| `alt-l` | Focus right |

## Move Windows

| Key | Action |
| --- | --- |
| `alt-shift-h` | Move window left |
| `alt-shift-j` | Move window down |
| `alt-shift-k` | Move window up |
| `alt-shift-l` | Move window right |

## Workspaces

| Key | Workspace |
| --- | --- |
| `alt-1` to `alt-9` | Switch to workspace `1` to `9` |
| `alt-b` | Browser workspace |
| `alt-e` | Extra/editor workspace |
| `alt-m` | Messages/mail workspace |
| `alt-n` | Notes/AI workspace |
| `alt-p` | Python/project workspace |
| `alt-s` | System/settings workspace |
| `alt-t` | Terminal/tools workspace |
| `alt-v` | Video/visual workspace |

## Move Windows To Workspaces

| Key | Action |
| --- | --- |
| `alt-shift-1` to `alt-shift-9` | Move window to workspace `1` to `9` |
| `alt-shift-b` | Move window to workspace `B` |
| `alt-shift-e` | Move window to workspace `E` |
| `alt-shift-m` | Move window to workspace `M` |
| `alt-shift-n` | Move window to workspace `N` |
| `alt-shift-p` | Move window to workspace `P` |
| `alt-shift-s` | Move window to workspace `S` |
| `alt-shift-t` | Move window to workspace `T` |
| `alt-shift-v` | Move window to workspace `V` |

## Workspace Navigation

| Key | Action |
| --- | --- |
| `alt-tab` | Switch back to the previous workspace |
| `alt-shift-tab` | Move current workspace to the next monitor |

## Resize Mode

Enter resize mode:

```text
alt-shift-r
```

| Key In Resize Mode | Action |
| --- | --- |
| `h` | Decrease width |
| `j` | Increase height |
| `k` | Decrease height |
| `l` | Increase width |
| `b` | Balance window sizes |
| `minus` | Smart resize smaller |
| `equal` | Smart resize larger |
| `enter` | Return to main mode |
| `esc` | Return to main mode |

## Service Mode

Enter service mode:

```text
alt-shift-semicolon
```

| Key In Service Mode | Action |
| --- | --- |
| `esc` | Reload config and return to main mode |
| `r` | Flatten/reset workspace layout and return to main mode |
| `f` | Toggle floating/tiling layout and return to main mode |
| `backspace` | Close all windows except current and return to main mode |
| `alt-shift-h` | Join with left window and return to main mode |
| `alt-shift-j` | Join with lower window and return to main mode |
| `alt-shift-k` | Join with upper window and return to main mode |
| `alt-shift-l` | Join with right window and return to main mode |

## Automatic Workspace Rules

| App | Workspace |
| --- | --- |
| WezTerm | `T` |
| iTerm2 | `T` |
| Google Chrome | `B` |
| Safari | `B` |
| Obsidian | `N` |
| App Store | `S` |
| TextEdit | `N` |
| Mail | `M` |
| Messages | `M` |
| Messenger | `M` |
| System Settings | `S` |
| Python apps | `P` |
| ChatGPT | `N` |
| Notes | `N` |
| Discord | `M` |
| Visual Studio Code | `T` |
