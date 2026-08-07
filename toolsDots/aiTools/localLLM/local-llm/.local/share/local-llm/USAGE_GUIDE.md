# Local LLM and CodeCompanion Guide

This guide covers the local stack installed on this Mac, then walks through
building and maintaining a small browser calculator with CodeCompanion's local
coding agent.

## 1. Understand the pieces

`local-llm` is not just the llama.cpp/GGUF manager -- it is the orchestrator
between two interchangeable backends, selected by a `provider` setting:

```text
Neovim + CodeCompanion
        |
        +--> <leader>ap picks: Local LLM | TurboFieldfare | online Codex
        |
        v
    local-llm (provider: llama | turbo)
        |
        +--> llama:  wrapper on:  local-llm-wrapper :8090 --> llama-server :8081
        |     wrapper off: llama-server :8081
        |
        +--> turbo:  delegates straight to the turbo-fieldfare CLI --> :8081
```

- **llama** (the default): `local-llm` discovers GGUF models below `~/Models`,
  selects a model, and starts or stops `llama-server`, which exposes an
  OpenAI-compatible API. `local-llm-wrapper` validates and repairs malformed
  tool calls; selecting Qwen 2.5 enables it automatically, selecting another
  model disables it, and you can toggle it manually.
- **turbo**: `local-llm` delegates to the separate `turbo-fieldfare` CLI,
  which runs a single pinned model (Gemma 4 26B-A4B) purpose-built to fit in
  ~2GB of RAM on Apple Silicon. There is no model catalog and no wrapper for
  this provider -- `local-llm model` and `local-llm wrapper` refuse clearly if
  you run them while turbo is active.
- Both backends share port 8081 on purpose (so 8080 stays free for ordinary
  dev servers) and are never meant to run at the same time. `local-llm`
  stops whichever one is active before starting the other, whichever surface
  you switch from -- the Neovim picker and a terminal `local-llm provider use
  ...` read and write the same state, so they can never disagree.
- CodeCompanion provides the chat UI and the built-in `@{agent}` tool group.
  The agent, not the wrapper, creates, reads, edits, deletes, and tests files.

## 2. TurboFieldfare and switching providers

One-time setup for TurboFieldfare (terminal, outside Neovim; skip if already
done):

```sh
turbo-fieldfare install   # builds the release binaries, downloads the ~14GB model
```

To use it from Neovim, press `Space a p` and choose **TurboFieldfare (Gemma 4
26B)**, or run `:AIProviderUse turbo`. This does not start anything by
itself -- it only records which adapter your *next* message should use. The
actual switch (stopping the old backend, starting the new one) happens the
moment you send that message, so the first chat or completion after switching
pauses briefly with a "Starting..." notification. A cold TurboFieldfare start
loads a 26B-parameter model, so that first message can take noticeably longer
than usual; every message after it is normal speed.

To switch back, press `Space a p` again and choose **Local LLM**, or run
`:AIProviderUse local`.

From a terminal instead of Neovim, the equivalent is:

```sh
local-llm provider status
local-llm provider use llama
local-llm provider use turbo
```

Either surface keeps the other in sync, since both read and write the same
provider state file.

## 3. Check the stack from a terminal

List installed models:

```sh
local-llm model list
```

Show the selected model and service health:

```sh
local-llm status
```

Useful service commands (act on whichever provider is currently active,
llama or turbo -- the names predate the provider switch):

```sh
local-llm start
local-llm stop
local-llm restart
local-llm doctor
local-llm logs
```

Useful model and wrapper commands (llama only; error clearly if turbo is
active):

```sh
local-llm model status
local-llm model use qwen/Qwen2.5-Coder-7B-Instruct-Q4_K_M
local-llm model use prism-ml/Bonsai-8B-Q1_0
local-llm wrapper status
local-llm wrapper on
local-llm wrapper off
local-llm wrapper toggle
```

TurboFieldfare's own CLI, useful when it's the active provider:

```sh
turbo-fieldfare status
turbo-fieldfare doctor
turbo-fieldfare update
```

For coding-agent work on the llama provider, start with Qwen 2.5 because its
wrapper policy is tuned for tool-call repair. Bonsai remains the general
default model.

## 4. Know the Neovim controls

The leader key is `Space`.

| Keys | Action | Scope |
| --- | --- | --- |
| `Space a p` | Select provider: Local LLM, TurboFieldfare, or online Codex | all |
| `Space a m` | Select an installed local GGUF model | llama only |
| `Space a g` | Start a coding-agent task | all |
| `Space a c` | Open a normal chat | all |
| `Space a i` | Run an inline local-model request | local & turbo |
| `Space a w` | Toggle the local tool-call wrapper | llama only |
| `Space a a` | Open CodeCompanion actions | all |

`Space a m` and `Space a w` show a clear message and do nothing destructive if
you run them while TurboFieldfare is the active provider -- switch to llama
first (`Space a p`) if you need them.

Equivalent Neovim commands include:

```vim
:LocalLLMStatus
:LocalLLMModelSelect
:LocalLLMModelStatus
:LocalLLMWrapperOn
:LocalLLMWrapperOff
:LocalLLMWrapperToggle
:AIProviderSelect
:AIProviderStatus
:AIProviderUse local
:AIProviderUse turbo
```

In a CodeCompanion chat:

- Press `Ctrl-s` in insert mode to send a message.
- Press `Enter` in normal mode to send a message.
- Press `Ctrl-c` to close the chat.
- Start a manual agent prompt with `@{agent}`. The `Space a g` shortcut adds
  this automatically.

Model and provider changes are clearest in a new chat. Close an old chat and
open a new one after switching.

## 5. Understand the coding agent

CodeCompanion's built-in `@{agent}` group includes tools to:

- Ask clarifying questions.
- Find, search, and read project files.
- Create files.
- Edit existing files and present a diff for confirmation.
- Delete files.
- Inspect Git changes and editor diagnostics.
- Run commands such as syntax checks and tests.

The tools are scoped to Neovim's current working directory. Launch Neovim from
the project root so the agent cannot accidentally operate in a broader folder.

CodeCompanion asks for approval before sensitive actions. Prefer **Allow once**
while learning the workflow. Inspect every path, command, and diff, especially
for `delete_file` and `run_command`. Do not enable YOLO mode for this tutorial.

## 6. Create the calculator project

Open a terminal and create a clean, version-controlled project:

```sh
mkdir -p ~/Projects/local-calculator
cd ~/Projects/local-calculator
git init
nvim .
```

Starting Neovim from this directory makes it the agent's working boundary.

This tutorial uses the llama provider, since it exercises the model catalog
and wrapper. TurboFieldfare can run the same agent tasks (see Section 2), but
has no model catalog to switch mid-tutorial.

### Select the local provider

1. Press `Space a p`.
2. Choose **Local LLM**.

This selection applies to new CodeCompanion chats.

### Select Qwen 2.5

1. Press `Space a m`.
2. Choose `qwen/Qwen2.5-Coder-7B-Instruct-Q4_K_M`.
3. Wait for the notification that the backend and wrapper started.
4. Run `:LocalLLMStatus` if you want to confirm the state.

Selecting Qwen 2.5 automatically turns the wrapper on. You can confirm with:

```vim
:LocalLLMWrapperStatus
```

### Give the creation task to the agent

Press `Space a g`, then enter this task:

```text
Build a small static browser calculator in the current directory. Inspect the
directory first, then complete the implementation using your tools.

Create index.html, styles.css, app.js, README.md, and scratch-notes.md. Use only
HTML, CSS, and vanilla JavaScript with no external packages. The calculator must
support addition, subtraction, multiplication, division, decimals, clear,
backspace, keyboard input, and a friendly divide-by-zero error. Make the layout
responsive and accessible with clear button labels and visible keyboard focus.
Keep calculation logic separate from DOM event handling where practical.

Write a short implementation summary in scratch-notes.md. After creating the
files, inspect them and run `node --check app.js` if Node.js is available. Fix
any syntax errors you find. Do not modify or delete anything outside this
project directory.
```

`Space a g` automatically prepends `@{agent}`. If you opened a normal chat with
`Space a c`, type `@{agent}` before the task yourself.

### Handle approvals

During the task:

1. Confirm that every proposed path is inside `~/Projects/local-calculator`.
2. Choose **Allow once** for each expected file creation.
3. Approve `node --check app.js` after verifying the command.
4. Review each generated file when the agent reports completion.
5. If an action targets an unexpected path, reject it and explain the correct
   project path in the rejection reason.

### Preview the result

From a separate terminal in the project directory, either open the file:

```sh
open index.html
```

or serve it locally:

```sh
python3 -m http.server 8000
```

Then visit `http://127.0.0.1:8000` and test mouse and keyboard input. Stop the
server with `Ctrl-c`.

## 7. Update and edit the calculator

Continue in the same agent chat so it retains the task context, or open a new
agent chat with `Space a g`. Use this prompt:

```text
Inspect the calculator files before editing them. Add a calculation history
panel that stores the five most recent successful calculations. Each history
entry should be reusable by clicking it. Add a Clear history control and keep
the layout usable on a narrow mobile screen. Update README.md to document the
feature. Do not rewrite unrelated code.

Use the edit tools to make the changes, show me the proposed diffs, run
`node --check app.js`, and fix any problems before finishing.
```

For edits, CodeCompanion presents a diff confirmation. Review the changed lines
before accepting. Reject a diff that replaces unrelated sections and ask for a
smaller edit.

Afterward, refresh the browser and test:

1. Several valid calculations appear in history.
2. Clicking a history entry restores its result or expression.
3. Only five entries are retained.
4. Clear history works.
5. Division by zero is not added to history.
6. Keyboard controls still work.

## 8. Delete a file with the agent

The temporary notes file was intentionally created so deletion can be tested
without risking application code. Send this agent prompt:

```text
Verify that scratch-notes.md exists and is not required by the calculator.
Delete only scratch-notes.md using the delete-file tool. Do not delete or edit
any other file. Afterward, list the remaining project files and confirm that
index.html, styles.css, app.js, and README.md still exist.
```

When prompted, verify that the deletion target is exactly
`scratch-notes.md`, then choose **Allow once**. Reject the operation if any
other path is included.

## 9. Review and preserve the work

Inspect all changes outside the agent conversation:

```sh
git status --short
git diff -- index.html styles.css app.js README.md
node --check app.js
```

When satisfied:

```sh
git add index.html styles.css app.js README.md
git commit -m "Build local calculator app"
```

Git gives you a reliable recovery point before asking the agent for more edits.

## 10. Switch back to Bonsai

In Neovim:

1. Press `Space a m`.
2. Choose `prism-ml/Bonsai-8B-Q1_0`.

Or use the terminal:

```sh
local-llm model use prism-ml/Bonsai-8B-Q1_0
```

Selecting Bonsai automatically stops the wrapper. You may manually enable it
for Bonsai with `local-llm wrapper on` or `:LocalLLMWrapperOn`.

## 11. Troubleshooting

Check dependencies and model discovery:

```sh
local-llm doctor
local-llm model list
```

Check service state:

```sh
local-llm status
local-llm provider status
local-llm wrapper status
turbo-fieldfare status
```

Find the log locations:

```sh
local-llm logs
```

Restart both services:

```sh
local-llm restart
```

If a local model describes a file operation but does not call a tool, verify
that the prompt includes `@{agent}`. For Qwen 2.5, also verify that the wrapper
is on. If a tool call is rejected, keep the error in the chat and ask the agent
to retry with the exact relative file path.

**"requested model is not available"** -- you're talking to the wrong engine
for what's actually running on :8081. Run `local-llm provider status` to
check, or press `Space a p` and reselect the provider you meant.

**"port occupied by a different backend"** -- the other engine is still
running and holding :8081. The error names which command stops it
(`local-llm stop` or `turbo-fieldfare stop`), or just switch providers again
and let `local-llm` handle it.

**First TurboFieldfare message feels stuck** -- normal, it's loading a
26B-parameter model on first start. Later messages in the same session are
fast.
