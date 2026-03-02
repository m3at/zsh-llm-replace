# zsh-llm-replace

Zsh plugin to integrate LLMs into the shell for quick command generation.

Supports Gemini (default) and OpenAI-compatible APIs (OpenAI, Ollama, LMStudio, etc.).

## Requirements

* [curl](https://curl.se/)
* either a locally running LLM or valid api keys

## Installation

Using [zplug](https://github.com/zplug/zplug):
```sh
zplug "m3at/zsh-llm-replace"
```

## Configuration

### Gemini (default)

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
export ZSH_AI_COMMANDS_MODEL="llama3"
```

### All environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ZSH_AI_COMMANDS_PROVIDER` | Auto-detected from which key is set | `gemini` or `openai` |
| `ZSH_AI_COMMANDS_MODEL` | `gemini-3-flash-preview` / `gpt-4o-mini` | Model identifier |
| `ZSH_AI_COMMANDS_GEMINI_API_KEY` | — | Gemini API key |
| `ZSH_AI_COMMANDS_OPENAI_API_KEY` | — | OpenAI API key |
| `ZSH_AI_COMMANDS_OPENAI_ENDPOINT` | `https://api.openai.com/v1/chat/completions` | Custom endpoint |
| `ZSH_AI_COMMANDS_HOTKEY` | `^o` (Ctrl+O) | Keybinding |
| `ZSH_AI_COMMANDS_HISTORY` | `false` | Log queries to history |
| `ZSH_AI_COMMANDS_DEBUG` | `false` | Keep response files for debugging |
| `ZSH_AI_COMMANDS_LLM_NAME` | — | Legacy fallback for `_MODEL` |

## Usage

1. Type a natural language description in your terminal
2. Press Ctrl+O (or your configured hotkey)
3. Review the generated command in fzf
4. Select "Use command" or abort

## Testing

```sh
zsh tests/run.zsh          # unit + fixture tests
zsh tests/run.zsh --live   # also run live API smoke tests (needs keys set)
```

---

Reworked based on ideas from my [previous fork](https://github.com/m3at/zsh-ai-commands/tree/main).
