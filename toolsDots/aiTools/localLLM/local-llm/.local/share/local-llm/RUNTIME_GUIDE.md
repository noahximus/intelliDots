# Local LLM Runtime and Model Guide

`local-llm` is the command-line manager for your local GGUF model setup.
It starts `llama-server`, tracks the selected model, and can optionally run a
small OpenAI-compatible wrapper that repairs malformed tool calls from local
models.

This is the default **llama** provider. `local-llm` can also run
**TurboFieldfare** (a single pinned Gemma 4 26B-A4B model, no GGUF catalog)
as an alternative provider on the same port -- see `local-llm provider use
turbo` and `USAGE_GUIDE.md` for the full picture, including the Neovim
integration. Everything below in this file is specific to the llama
provider.

The stack is installed by `localLLM` at:

```text
~/.local/bin/local-llm
~/.local/share/local-llm/
~/.config/local-llm/stack.env
```

## What It Runs

Default ports:

```text
llama-server backend: http://127.0.0.1:8081
wrapper endpoint:     http://127.0.0.1:8090
model alias:          local-llm
models directory:     ~/Models
```

Normal request path:

```text
Client app
  -> wrapper on:  http://127.0.0.1:8090 -> llama-server :8081
  -> wrapper off: http://127.0.0.1:8081
```

The wrapper is useful for CodeCompanion/tool-calling workflows. It is usually
enabled for Qwen Coder and disabled for general models, but you can toggle it
manually.

## Basic Commands

The underlying stack commands are below.

Check setup health:

```sh
local-llm doctor
```

List downloaded models:

```sh
local-llm model list
```

Show the currently selected model:

```sh
local-llm model status
```

Select a model:

```sh
local-llm model use qwen/Qwen2.5-Coder-7B-Instruct-Q4_K_M
```

Start, stop, and inspect the services:

```sh
local-llm start
local-llm stop
local-llm restart
local-llm status
local-llm logs
```

Control the wrapper:

```sh
local-llm wrapper status
local-llm wrapper on
local-llm wrapper off
local-llm wrapper toggle
```

## Listing And Selecting Models

`local-llm` discovers `.gguf` files recursively under `~/Models`.
Model IDs are paths relative to `~/Models` with the `.gguf` extension removed.

Example downloaded file:

```text
~/Models/qwen/coding/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
```

Its model ID is:

```text
qwen/coding/Qwen2.5-Coder-7B-Instruct-Q4_K_M
```

List available models:

```sh
local-llm model list
```

Use the exact ID from that list:

```sh
local-llm model use qwen/coding/Qwen2.5-Coder-7B-Instruct-Q4_K_M
```

The downloader also creates compatibility symlinks for shorter legacy IDs, so
this usually works too:

```sh
local-llm model use qwen/Qwen2.5-Coder-7B-Instruct-Q4_K_M
```

After selecting a model, restart the stack if it is already running:

```sh
local-llm restart
```

For scripts, use the porcelain output:

```sh
local-llm model list --porcelain
```

## Downloading Models

`localLLM` installs a helper command:

```sh
download-local-models
```

List known downloadable models:

```sh
download-local-models --list
```

Download every configured model:

```sh
download-local-models --all
```

Download specific models:

```sh
download-local-models qwen-coder
download-local-models qwen3-4b phi4-mini
download-local-models gemma3-12b
```

Some repositories are gated on Hugging Face. If a download says access approval
is required, open the printed `Model page:` URL, sign in to the same Hugging
Face account used by `hf auth whoami`, accept the model terms, then retry the
failed model.

## Available Model Catalog

These are the model IDs known by `download-local-models`.

| Download ID | Saved Path Under `~/Models` | Best For | Source |
| --- | --- | --- | --- |
| `qwen-coder` | `qwen/coding/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf` | Coding, tool use, agent workflows, and repository questions. | <https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF> |
| `qwen3` | `qwen/general/Qwen3-8B-Q4_K_M.gguf` | General chat, reasoning, writing, and mixed tasks. | <https://huggingface.co/Qwen/Qwen3-8B-GGUF> |
| `qwen3-4b` | `qwen/general/Qwen3-4B-Q4_K_M.gguf` | Fast everyday local assistant for terminal help and short tasks. | <https://huggingface.co/Qwen/Qwen3-4B-GGUF> |
| `qwen3-14b` | `qwen/general/Qwen3-14B-Q4_K_M.gguf` | Higher-quality Qwen general model for 16 GB Macs when speed matters less. | <https://huggingface.co/ggml-org/Qwen3-14B-GGUF> |
| `gemma3-4b` | `google/gemma/general/gemma-3-4b-it-q4_0.gguf` | Fast writing, summarization, multilingual help, and light multimodal experiments. | <https://huggingface.co/google/gemma-3-4b-it-qat-q4_0-gguf> |
| `gemma3-12b` | `google/gemma/general/gemma-3-12b-it-q4_0.gguf` | Higher-quality general assistant, writing, summarization, and multilingual work. | <https://huggingface.co/google/gemma-3-12b-it-qat-q4_0-gguf> |
| `ministral` | `mistral/general/Ministral-8B-Instruct-2410-Q4_K_M.gguf` | Fast general assistant with a Mistral-style instruction format. | <https://huggingface.co/bartowski/Ministral-8B-Instruct-2410-GGUF> |
| `deepseek-r1-qwen` | `deepseek/reasoning/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf` | Reasoning experiments and step-by-step analytical tasks. | <https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF> |
| `bonsai` | `prism-ml/general/Bonsai-8B-Q1_0.gguf` | Lightweight/default local model for faster casual use. | <https://huggingface.co/prism-ml/Bonsai-8B-gguf> |
| `phi4-mini` | `microsoft/reasoning/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf` | Small reasoning, math, and concise instruction-following. | <https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF> |

## Recommended Choices

- Coding and agent workflows: `qwen-coder`
- Fast general local chat: `qwen3-4b` or `bonsai`
- Better general quality on a 16 GB Mac: `qwen3`, `qwen3-14b`, or `gemma3-12b`
- Reasoning experiments: `deepseek-r1-qwen` or `phi4-mini`

## Using With The Local UI

Start the stack:

```sh
local-llm start
```

Install the separate UI application, then start it:

```sh
git clone https://github.com/noahximus/local-llm-ui.git
cd local-llm-ui
npm start
```

The UI defaults to the wrapper endpoint:

```text
http://127.0.0.1:8090
```

Use the model name:

```text
local-llm
```

## Configuration

Edit:

```text
~/.config/local-llm/stack.env
```

Important settings:

```sh
LOCAL_LLM_MODELS_DIR="$HOME/Models"
LOCAL_LLM_DEFAULT_MODEL="prism-ml/Bonsai-8B-Q1_0"
LOCAL_LLM_MODEL_ALIAS="local-llm"
LOCAL_LLM_BACKEND_PORT="8081"
LOCAL_LLM_WRAPPER_PORT="8090"
LOCAL_LLM_CTX_SIZE="16384"
LOCAL_LLM_N_GPU_LAYERS="99"
```

After changing config, restart:

```sh
local-llm restart
```
