# zsh-llm-replace

Zsh plugin to integrate LLMs into the shell for quick command generation.


https://github.com/user-attachments/assets/fd6408ed-edf2-407a-812b-2e1fac25698c

_Demo with gpt-4.1-mini's Fast mode_

Supports Gemini (default with free credits), OpenAI-compatible APIs (OpenAI, Ollama, LMStudio, etc.), and OpenRouter (one key, hundreds of models including OSS).

## Requirements

* [curl](https://curl.se/)
* [jq](https://github.com/jqlang/jq)
* either a locally running LLM or valid api keys

## Installation

Using [zplug](https://github.com/zplug/zplug):
```sh
zplug "m3at/zsh-llm-replace", at:main
```

## Configuration

### Gemini

```sh
export ZSH_AI_COMMANDS_GEMINI_API_KEY="your-key-here"
```

### OpenAI

Defaults to `gpt-6-luna` with `none` reasoning and Fast mode.

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
| `ZSH_AI_COMMANDS_MODEL` | `gemini-3-flash-preview` / `gpt-6-luna` / `openai/gpt-oss-120b:nitro` | Model identifier (prefix with `or:` to force OpenRouter) |
| `ZSH_AI_COMMANDS_GEMINI_API_KEY` | — | Gemini API key |
| `ZSH_AI_COMMANDS_OPENAI_API_KEY` | — | OpenAI API key |
| `ZSH_AI_COMMANDS_OPENAI_ENDPOINT` | `https://api.openai.com/v1/responses` | Custom endpoint (use `/v1/chat/completions` for OpenAI-compatible servers) |
| `ZSH_AI_COMMANDS_OPENAI_FAST` | `true` | OpenAI Fast mode (lower latency, 2x cost) |
| `ZSH_AI_COMMANDS_OPENAI_PRIORITY` | — | Deprecated compatibility alias for `ZSH_AI_COMMANDS_OPENAI_FAST` |
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

# latency/cost benchmark (live API calls)
zsh bench.zsh
```

Each benchmark runs five prompts per model with a 512-token output limit. OpenAI rows use the Responses API and 2x-cost Fast mode. Latency and output tokens are per-request averages; output tokens include reasoning. Cost x1000 is the estimated average cost per request multiplied by 1,000. Quality counts commands that are valid one-line zsh and pass prompt-specific sanity checks. Commands are not executed, and these checks do not establish full correctness.

GPT-6 rows were measured on 2026-10-08; other rows on 2026-08-16. Each run used one request per prompt.

```
Model                          Latency  Tokens    Cost x1000  Quality
────────────────────────────  ────────  ──────  ────────────  ───────
gemini-3-flash-preview            3.3s      15        $0.186      3/5
gemini-2.5-flash                  2.3s      15        $0.122      4/5
gpt-4o                            1.1s      14        $2.820      4/5
gpt-4.1-mini                      1.0s      26        $0.532      5/5
gpt-5.4-mini                      0.9s      31        $0.691      5/5
gpt-5.6-sol [none]                1.3s      25        $2.134      5/5
gpt-5.6-luna [none]               1.1s      28        $0.088      5/5
gpt-5.6-luna [low]                1.9s     144        $0.228      5/5
gpt-6.1-sol [low]                3.76s      88        $2.870      5/5
gpt-6-luna [none]                2.02s      26        $0.082      5/5
gpt-6-luna [low]                 3.21s     137        $0.192      5/5
or:gpt-oss-120b:nitro             0.8s     127        $0.214      5/5
or:qwen3.5-35b-a3b:nitro          0.9s      22        $0.066      5/5

```

GPT-6 costs use the published [Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) and [Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) token rates. Luna with `none` matched `TODO` anywhere in Python files, while `low` restricted matches to comments; both passed the heuristic check.

The plugin fixes OpenAI reasoning to `none` without exposing another setting. GPT-6.1 Sol requires at least `low`, so its row is a benchmark-only comparison.

---

Reworked based on ideas from my [previous fork](https://github.com/m3at/zsh-ai-commands/tree/main).
