# zsh-llm-replace

Zsh plugin to integrate LLMs into the shell for quick command generation.


https://github.com/user-attachments/assets/fd6408ed-edf2-407a-812b-2e1fac25698c

_Demo with gpt-4.1-mini's priority tier_

Supports Gemini (default with free credits), OpenAI-compatible APIs (OpenAI, Ollama, LMStudio, etc.), and OpenRouter (one key, hundreds of models including OSS).

## Requirements

* [curl](https://curl.se/)
* [jq](https://github.com/jqlang/jq)
* either a locally running LLM or valid api keys

## Installation

Using [zplug](https://github.com/zplug/zplug):
```sh
zplug "m3at/zsh-llm-replace"
```

## Configuration

### Gemini

```sh
export ZSH_AI_COMMANDS_GEMINI_API_KEY="your-key-here"
```

### OpenAI

```sh
export ZSH_AI_COMMANDS_OPENAI_API_KEY="your-key-here"
```

### OpenRouter

```sh
export ZSH_AI_COMMANDS_OPENROUTER_API_KEY="your-key-here"
# Optional — defaults to openai/gpt-oss-120b:nitro
export ZSH_AI_COMMANDS_MODEL="qwen/qwen3.5-35b-a3b:nitro"
```

Or use the `or:` model-prefix shorthand to switch provider with a single env var:

```sh
export ZSH_AI_COMMANDS_MODEL=or:qwen/qwen3.5-35b-a3b:nitro
```

The prefix forces `ZSH_AI_COMMANDS_PROVIDER=openrouter` and is stripped before
the request is sent. Useful when multiple keys are set and you want to flip
providers without touching `ZSH_AI_COMMANDS_PROVIDER`.

### OpenAI-compatible APIs (llama.cpp, LMStudio, etc.)

```sh
export ZSH_AI_COMMANDS_PROVIDER=openai
export ZSH_AI_COMMANDS_OPENAI_API_KEY="your-key"
export ZSH_AI_COMMANDS_OPENAI_ENDPOINT="http://localhost:11434/v1/chat/completions"
export ZSH_AI_COMMANDS_MODEL="LiquidAI/LFM2.5-1.2B-Thinking"
```

### All environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ZSH_AI_COMMANDS_PROVIDER` | Auto-detected from which key is set | `gemini`, `openai`, or `openrouter` |
| `ZSH_AI_COMMANDS_MODEL` | `gemini-3-flash-preview` / `gpt-4.1-mini` / `openai/gpt-oss-120b:nitro` | Model identifier (prefix with `or:` to force OpenRouter) |
| `ZSH_AI_COMMANDS_GEMINI_API_KEY` | — | Gemini API key |
| `ZSH_AI_COMMANDS_OPENAI_API_KEY` | — | OpenAI API key |
| `ZSH_AI_COMMANDS_OPENAI_ENDPOINT` | `https://api.openai.com/v1/responses` | Custom endpoint (use `/v1/chat/completions` for OpenAI-compatible servers) |
| `ZSH_AI_COMMANDS_OPENAI_PRIORITY` | `true` | OpenAI priority tier (lower latency, 2x cost) |
| `ZSH_AI_COMMANDS_OPENROUTER_API_KEY` | — | OpenRouter API key |
| `ZSH_AI_COMMANDS_HOTKEY` | `^o` (Ctrl+O) | Keybinding |
| `ZSH_AI_COMMANDS_HISTORY` | `false` | Log queries to history |
| `ZSH_AI_COMMANDS_DEBUG` | `false` | Keep response files for debugging |

## Usage

1. Type a natural language description in your terminal
2. Press Ctrl+o (or your configured hotkey)
3. Accept (enter) or discard (any other key) the generated command

## Testing

```sh
# unit + fixture tests
zsh tests/run.zsh          

# mini cost/latency bench mark
zsh bench.zsh
```

Test results with `reasoning: { effort: "low" }` and 2x priority-tier cost, as of 2026/03/18:
```
Model                        Latency  Tokens    Cost x1000
──────────────────────────  ────────  ──────  ────────────
gemini-3-flash-preview          3.7s      15        $0.186
gemini-2.5-flash                2.6s      16        $0.124
gpt-4o                          0.7s      15        $2.848
gpt-4.1-mini                    0.7s      27        $0.536
gpt-5-mini                      3.3s     482        $3.717
gpt-5.4-mini                    1.1s      28        $0.669
gpt-5.4-nano                    0.9s      32        $0.190
or:gpt-oss-120b:nitro           0.6s     109        $0.201
or:qwen3.5-35b-a3b:nitro        1.0s      25        $0.081

```

---

Reworked based on ideas from my [previous fork](https://github.com/m3at/zsh-ai-commands/tree/main).
