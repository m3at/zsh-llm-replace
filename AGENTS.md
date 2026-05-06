Zsh plugin that turns a natural-language prompt typed at the command line into a single shell one-liner via an LLM. Bound to a hotkey (default Ctrl+O), it replaces the buffer with the generated command, awaiting Enter to accept or any key to restore.

## Layout

- zsh-llm-replace.plugin.zsh — entry point sourced by plugin managers; just sources the main file.
- zsh-llm-replace.zsh — config resolution, ZLE widget `fzf_ai_commands`, system prompt, curl call, accept/reject UI.
- lib/providers.zsh — provider abstraction. Three pairs of functions (`_zaic_build_request_*`, `_zaic_parse_response_*`) for `gemini`, `openai`, and `openrouter`, plus dispatchers that pick by `$ZSH_AI_COMMANDS_PROVIDER`.
- lib/parse.zsh — `_zaic_clean_command`: strips fences, drops English-prose lines, flattens to one line.
- tests/run.zsh — runner. Sources libs, executes test_parse.zsh and test_providers.zsh, prints pass/fail.
- tests/fixtures/ — recorded JSON responses (clean, fenced, error, multipart) used to test parsing without network.
- bench.zsh — latency/cost benchmark across models.

## Conventions

- All public-ish functions are prefixed `_zaic_` (zsh-ai-commands). Don't rename without updating the dispatcher string interpolation in lib/providers.zsh (`"_zaic_build_request_${ZSH_AI_COMMANDS_PROVIDER}"`).
- Provider contract: `_zaic_build_request_<provider>` sets `_zaic_url`, `_zaic_headers` (array), `_zaic_body` in the caller's scope. `_zaic_parse_response_<provider>` reads a response file path and prints raw text to stdout, returns 1 on error.
- All env vars use the `ZSH_AI_COMMANDS_` prefix (note: prefix differs from the repo name).
- OpenAI calls use the `/v1/responses` endpoint, not `/chat/completions`. The parser reads `.output[1].content[0].text` — index 1 because index 0 is the reasoning item.
- Gemini default is `gemini-3-flash-preview`; OpenAI default is `gpt-4.1-mini`; OpenRouter default is `openai/gpt-oss-120b:nitro`.
- `service_tier: priority` is on by default for OpenAI (lower latency, 2x cost). Toggle with `ZSH_AI_COMMANDS_OPENAI_PRIORITY=false`.
- Reasoning effort is hardcoded to `low` in providers.zsh, with one exception: OpenRouter qwen models (slug containing `qwen`) get `reasoning:{enabled:false}` because they ignore `effort` and emit thousands of reasoning tokens otherwise. gpt-oss requires reasoning enabled, so we can't blanket-disable.
- Model-prefix shorthand: `ZSH_AI_COMMANDS_MODEL=or:<slug>` forces `ZSH_AI_COMMANDS_PROVIDER=openrouter` and strips the prefix before the request. Resolved at the top of the config block in zsh-llm-replace.zsh.
- OpenRouter returns USD cost on `.usage.cost` directly, so `bench.zsh` reads it instead of consulting `COST_IN`/`COST_OUT` for openrouter rows.

## Adding a provider

1. Add `_zaic_build_request_<name>` and `_zaic_parse_response_<name>` to lib/providers.zsh following the contract above.
2. Add the provider to the auto-detection and validation case statements in zsh-llm-replace.zsh.
3. Add a model default in the same file.
4. Add fixtures under tests/fixtures/ and tests in tests/test_providers.zsh.

## Testing

```sh
zsh tests/run.zsh    # offline, uses fixtures
zsh bench.zsh        # hits live APIs, needs keys
```

Tests run without network by sourcing libs directly and feeding fixture files into the parse functions. Always add a fixture when adding a new response shape; never make tests depend on live API output.

## Things to watch

- The widget mutates `BUFFER`, `CURSOR`, and `region_highlight` (ZLE state). On any error path, restore `BUFFER="$original_buffer"` and call `zle reset-prompt` before returning.
- `mktemp -t zshllmresp` is portable between macOS and Linux because the template has no Xs (BSD mktemp accepts a bare prefix).
- Response files are deleted unless `ZSH_AI_COMMANDS_DEBUG=true`, in which case the path is echoed for inspection.
- The Ctrl-C trap restores the buffer and removes the temp file; don't add early returns that bypass it without clearing the trap.
- The clean-command commentary heuristic is a regex of English sentence starters — it's intentionally crude. If the model wraps commands in prose, prefer fixing the system prompt or asking for fences over expanding the regex.
- Inside the `bench()` loop in bench.zsh, never re-declare `local foo` per iteration: zsh echoes `foo=value` to stdout when redeclaring an already-set local. All bench locals are hoisted to the top of the function.
