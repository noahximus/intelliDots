# localLLM

Standalone local-LLM runtime for macOS with two independent, opt-in backends.
Part of `toolsDots/aiTools` in `intelliDots`. It does not require any other
intelliDots component.

- **local-llm** — manages GGUF models through `llama.cpp`, exposes an
  OpenAI-compatible endpoint, and optionally repairs tool calls through a
  Python proxy.
- **TurboFieldfare** — a Swift/Metal runtime that runs Gemma 4 26B-A4B in
  about 2GB of RAM (see [drumih/turbo-fieldfare](https://github.com/drumih/turbo-fieldfare)),
  wrapped with a `local-llm`-style CLI. Requires macOS 26, Xcode 26, and an
  Apple Silicon Mac.

## Install

From the `intelliDots` root:

```bash
./install.sh --only toolsDots.aiTools.localLLM
```

Or directly:

```bash
cd toolsDots/aiTools/localLLM
./install.sh --with-local-llm
```

Both backends are opt-in and may be combined:

```bash
./install.sh --with-local-llm
./install.sh --with-turbo-fieldfare
./install.sh --with-local-llm --with-turbo-fieldfare
```

`--with-local-llm` installs the essential `Brewfile-essential` set by default
(GNU Stow, pipx, `llama.cpp`); add `--full` to also install the Ollama desktop
app. It Stows the stack, installs the Hugging Face CLI with pipx, creates
`~/Models`, and writes backend and wrapper LaunchAgents.

`--with-turbo-fieldfare` verifies a Swift toolchain is present, clones (or
fast-forward updates) `https://github.com/drumih/turbo-fieldfare.git` into
`~/.config/turbo-fieldfare`, and stows the `turbo-fieldfare` CLI. It does
**not** build the binaries or download the ~14GB model — run
`turbo-fieldfare install` afterward for that, on your own schedule.

Other options:

```bash
./install.sh --dry-run
./install.sh --no-brew
./install.sh --no-pipx
./install.sh --adopt
```

## Models and service control

```bash
download-local-models --list
download-local-models qwen-coder
local-llm doctor
local-llm model list
local-llm model use MODEL
local-llm start
local-llm stop
local-llm wrapper toggle
local-llm endpoint
```

Configuration lives in `~/.config/local-llm`. Runtime state and logs are
under `~/Library/Application Support/local-llm` and
`~/Library/Logs/local-llm`. Models default to `~/Models`.

The model catalog `download-local-models` reads from is a single JSON file:

```text
~/.local/share/local-llm/models.json
```

Add a new model by adding an entry there -- no script changes needed:

```json
"my-model": {
  "repo": "org/My-Model-GGUF",
  "file": "my-model-q4_k_m.gguf",
  "dest": "org/general/My-Model-Q4_K_M.gguf",
  "legacy_link": "org/My-Model-Q4_K_M.gguf",
  "purpose": "One-line description shown in --help and --list.",
  "aliases": ["mymodel"]
}
```

`repo`/`file` identify the Hugging Face GGUF repo and filename; `dest` is
where it's stored under `~/Models` (organize into purpose folders as you
like); `legacy_link` is a flat-path compatibility symlink to the same file;
`aliases` are optional alternate names `download-local-models` will also
accept for this model ID.

See `local-llm/.local/share/local-llm/RUNTIME_GUIDE.md` for the model catalog,
service commands, configuration, and UI connection details. The adjacent
`USAGE_GUIDE.md` covers CodeCompanion workflows and troubleshooting.

## TurboFieldfare

```bash
turbo-fieldfare install          # first-time build + model download (~14GB)
turbo-fieldfare install --force  # reinstall the model
turbo-fieldfare update           # git pull --ff-only + rebuild
turbo-fieldfare doctor
turbo-fieldfare start
turbo-fieldfare stop
turbo-fieldfare status
turbo-fieldfare endpoint
turbo-fieldfare logs
```

The upstream git clone and its Swift build output live under
`~/.config/turbo-fieldfare`. This CLI's own runtime state (PID file, log,
optional `config.env` for overriding the port or context size) lives in
`~/.config/turbo-fieldfare/.runtime`, which is excluded via that repo's own
`.git/info/exclude` so `git status`/`git pull` there stay clean. The
installed model lives separately in `~/.config/turbo-fieldfare-model`, kept
out of the source checkout on purpose so `turbo-fieldfare update` never risks
the ~14GB model directory.

The server binds to `127.0.0.1:8081` by default -- the same port local-llm's
llama-server backend uses. This is deliberate: the two are never meant to run
at the same time, so sharing the port keeps 8080 free for ordinary dev
servers. `turbo-fieldfare start`/`status` tell the two backends apart by
checking the model id reported at `/v1/models`, and refuse to proceed if the
port is already held by the other one. Run `local-llm stop` before starting
TurboFieldfare, and vice versa. The OpenAI-compatible endpoint is available
at `turbo-fieldfare endpoint`.

## Optional integrations

- `nvim` automatically loads the supplied CodeCompanion integration when it
  detects this project’s installed integration file.
- `opencode` can use the stack through its optional `opencode-local` helper.

Neither integration is required for the core stack.

## Optional browser UI

[`local-llm-ui`](https://github.com/noahximus/local-llm-ui) is a separate
application that can connect to this stack's OpenAI-compatible endpoint. This
runtime does not install or depend on the UI. Keeping the application separate
prevents Node/frontend dependencies and generated browser assets from becoming
part of machine configuration.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --data                    # also remove local-llm runtime data and logs
./uninstall.sh --models                  # destructive: also remove downloaded GGUF models
./uninstall.sh --turbo-fieldfare-data    # destructive: also remove the TurboFieldfare clone and model
./uninstall.sh --dry-run
```

Models are never removed unless `--models` or `--turbo-fieldfare-data` is
explicitly supplied.
