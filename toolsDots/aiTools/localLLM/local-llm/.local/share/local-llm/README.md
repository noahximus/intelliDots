# Local LLM

`local-llm` manages a local `llama-server` backend and an optional
OpenAI-compatible tool-call repair proxy. It discovers GGUF files recursively
under `~/Models`, so it is not tied to a particular model family.

The default model is `prism-ml/Bonsai-8B-Q1_0`. If that file is unavailable,
the stack falls back to the first discovered GGUF file.

Selecting Qwen 2.5 automatically enables the tool-call repair wrapper. Selecting
any other model automatically disables it. This happens only during model
selection; afterward, the wrapper can be turned on or off manually for any model.

## Commands

```sh
local-llm model list
local-llm model status
local-llm model use prism-ml/Bonsai-8B-Q1_0
local-llm start
local-llm stop
local-llm status
local-llm doctor
local-llm wrapper toggle
```

Model IDs are paths relative to `~/Models` with the `.gguf` extension removed.
`model use` also accepts a unique filename with or without the extension.

See [USAGE_GUIDE.md](USAGE_GUIDE.md) for a complete CodeCompanion walkthrough,
including a create, edit, test, and delete workflow for a calculator app.
