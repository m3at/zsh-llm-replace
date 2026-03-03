# zsh-llm-replace

Zsh plugin to integrate LLMs into the shell for quick command generation.


https://github.com/user-attachments/assets/fd6408ed-edf2-407a-812b-2e1fac25698c

_Demo with gpt-4.1-mini's priority tier_

Supports Gemini (default with free credits) and OpenAI-compatible APIs (OpenAI, Ollama, LMStudio, etc.).

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
| `ZSH_AI_COMMANDS_PROVIDER` | Auto-detected from which key is set | `gemini` or `openai` |
| `ZSH_AI_COMMANDS_MODEL` | `gemini-3-flash-preview` / `gpt-4.1-mini` | Model identifier |
| `ZSH_AI_COMMANDS_GEMINI_API_KEY` | — | Gemini API key |
| `ZSH_AI_COMMANDS_OPENAI_API_KEY` | — | OpenAI API key |
| `ZSH_AI_COMMANDS_OPENAI_ENDPOINT` | `https://api.openai.com/v1/chat/completions` | Custom endpoint |
| `ZSH_AI_COMMANDS_HOTKEY` | `^o` (Ctrl+O) | Keybinding |
| `ZSH_AI_COMMANDS_HISTORY` | `false` | Log queries to history |
| `ZSH_AI_COMMANDS_DEBUG` | `false` | Keep response files for debugging |
| `ZSH_AI_COMMANDS_LLM_NAME` | — | Legacy fallback for `_MODEL` |

## Usage

1. Type a natural language description in your terminal
2. Press Ctrl+o (or your configured hotkey)
3. Accept (enter) or discard (any other key) the generated command

## Testing

```sh
zsh tests/run.zsh          # unit + fixture tests
```

---

Reworked based on ideas from my [previous fork](https://github.com/m3at/zsh-ai-commands/tree/main).
