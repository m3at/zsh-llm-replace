#!/usr/bin/zsh

# ══════════════════════════════════════════════════════════════════
# zsh-ai-commands — LLM-powered command generation
# ══════════════════════════════════════════════════════════════════
#
# The model is tasked to write valid comments, smartly understanding requests, robust to
# typos and abbreviations.
# Example inputs and expected outputs for reference:
#
#   "list files by desc size"
#   → ls -lhSr
#
#   "diff without lock files"
#   → git diff -- . ':!*.lock'
#
#   "count success true in file.jsonl"
#   → jq '[.success | select(. == true)] | length' < file.jsonl | awk '{s+=$1} END {print s}'
#
#   "gimme TODO in src excpt node_modules"
#   → rg 'TODO' src/ --glob '!node_modules'
#
#   "show sorted disk usage at top-level"
#   → du -sh */ | sort -rh
#
#   "kill wtf is listening on 3000"
#   → lsof -ti tcp:3000 | xargs kill -9
#
# ══════════════════════════════════════════════════════════════════

(( ! $+commands[curl] )) && return
(( ! $+commands[jq] )) && return

# ── Source library files ──────────────────────────────────────────

source "${0:A:h}/lib/parse.zsh"
source "${0:A:h}/lib/providers.zsh"

# ── Config resolution ─────────────────────────────────────────────

# Provider auto-detection: explicit > inferred from available keys
if (( ${+ZSH_AI_COMMANDS_PROVIDER} )); then
  : # user explicitly chose
elif (( ${+ZSH_AI_COMMANDS_GEMINI_API_KEY} )); then
  typeset -g ZSH_AI_COMMANDS_PROVIDER=gemini
elif (( ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )); then
  typeset -g ZSH_AI_COMMANDS_PROVIDER=openai
else
  echo "zsh-ai-commands::Error::No API key set. Set ZSH_AI_COMMANDS_GEMINI_API_KEY or ZSH_AI_COMMANDS_OPENAI_API_KEY"
  return
fi

# Validate key for chosen provider
case "$ZSH_AI_COMMANDS_PROVIDER" in
  gemini)
    if (( ! ${+ZSH_AI_COMMANDS_GEMINI_API_KEY} )); then
      echo "zsh-ai-commands::Error::provider=gemini but ZSH_AI_COMMANDS_GEMINI_API_KEY not set"
      return
    fi
    ;;
  openai)
    if (( ! ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )); then
      echo "zsh-ai-commands::Error::provider=openai but ZSH_AI_COMMANDS_OPENAI_API_KEY not set"
      return
    fi
    ;;
  *)
    echo "zsh-ai-commands::Error::Unknown provider '$ZSH_AI_COMMANDS_PROVIDER' (use gemini or openai)"
    return
    ;;
esac

# Model defaults (ZSH_AI_COMMANDS_LLM_NAME honored as fallback)
if (( ! ${+ZSH_AI_COMMANDS_MODEL} )); then
  if (( ${+ZSH_AI_COMMANDS_LLM_NAME} )); then
    typeset -g ZSH_AI_COMMANDS_MODEL="$ZSH_AI_COMMANDS_LLM_NAME"
  else
    case "$ZSH_AI_COMMANDS_PROVIDER" in
      gemini) typeset -g ZSH_AI_COMMANDS_MODEL='gemini-3-flash-preview' ;;
      openai) typeset -g ZSH_AI_COMMANDS_MODEL='gpt-5-mini' ;;
    esac
  fi
fi

# OpenAI endpoint default
(( ! ${+ZSH_AI_COMMANDS_OPENAI_ENDPOINT} )) && \
  typeset -g ZSH_AI_COMMANDS_OPENAI_ENDPOINT='https://api.openai.com/v1/chat/completions'

# OpenAI priority processing (lower, more consistent latency; 2x cost)
(( ! ${+ZSH_AI_COMMANDS_OPENAI_PRIORITY} )) && typeset -g ZSH_AI_COMMANDS_OPENAI_PRIORITY=true

# Other defaults
(( ! ${+ZSH_AI_COMMANDS_HOTKEY} )) && typeset -g ZSH_AI_COMMANDS_HOTKEY='^o'
(( ! ${+ZSH_AI_COMMANDS_HISTORY} )) && typeset -g ZSH_AI_COMMANDS_HISTORY=false
(( ! ${+ZSH_AI_COMMANDS_DEBUG} )) && typeset -g ZSH_AI_COMMANDS_DEBUG=false

# ── Main widget ───────────────────────────────────────────────────

fzf_ai_commands() {
  setopt localoptions extendedglob pipefail

  [[ -n "$BUFFER" ]] || { echo "Empty prompt"; return }

  local original_buffer="$BUFFER"
  local user_query="${original_buffer/#AI_ASK: /}"

  if [[ "$ZSH_AI_COMMANDS_HISTORY" == true ]]; then
    print -r -- "AI_ASK: $user_query" >> "$HISTFILE"
    if (( $+commands[atuin] )); then
      local atuin_id
      atuin_id=$(atuin history start "AI_ASK: $user_query")
      atuin history end --exit 0 "$atuin_id"
    fi
  fi

  # ── Loading indicator ──────────────────────────────────────────
  BUFFER="# ⏳ …"
  CURSOR=$#BUFFER
  zle -R

  # ── Build request ──────────────────────────────────────────────
  local sys
  read -r -d '' sys <<'PROMPT'
You are an expert sysadmin and shell scripter. Given a task description, output a single shell one-liner.

Environment:
- Shell: zsh on macOS (Darwin). GNU coreutils are installed.
- Available beyond the defaults: rg (ripgrep), jq, fzf, fd, sed, awk, perl, curl, git.

Output rules:
- Print ONLY the bare command. Nothing else.
- No markdown, no code fences, no backticks, no commentary, no leading/trailing whitespace.
- The command must be a single logical line. Use pipes, &&, ||, ;, or subshells to chain steps. Never use literal newlines.
- Quoting: prefer single quotes for fixed strings, double quotes when variable expansion or escapes are needed. Escape carefully inside nested quotes.
- Prefer sensible defaults, but when you can't, use <placeholder> for values that must be filled in, e.g. <file>, <pattern>, <port>.
- If you must include commentary, wrap the command in a ``` block so it can be extracted.

Command quality:
- Prefer simple, robust solutions. Avoid unnecessary subshells or processes.
- When the task is ambiguous, pick the most common interpretation rather than asking for clarification.
PROMPT

  local _zaic_url _zaic_body
  typeset -a _zaic_headers
  _zaic_build_request "$sys" "$user_query" || {
    BUFFER="$original_buffer"; zle reset-prompt; return 1
  }

  # ── API call with interruption handling ─────────────────────────
  local resp_file
  resp_file="$(mktemp /tmp/zshllmresp.XXXXXX.json)" || {
    BUFFER="$original_buffer"; zle reset-prompt; return 1
  }

  trap 'BUFFER="$original_buffer"; zle reset-prompt; rm -f "$resp_file" 2>/dev/null; trap - INT; return 130' INT

  local _curl_args=("--silent" "--max-time" "30" "$_zaic_url")
  for h in "${_zaic_headers[@]}"; do
    _curl_args+=("-H" "$h")
  done
  _curl_args+=("-d" "$_zaic_body")
  curl "${_curl_args[@]}" > "$resp_file"
  local ret=$?
  trap - INT

  if (( ret != 0 )); then
    echo "curl failed (exit $ret)"
    BUFFER="$original_buffer"; zle end-of-line; zle reset-prompt
    [[ "$ZSH_AI_COMMANDS_DEBUG" == true ]] && echo "$resp_file" || rm -f "$resp_file"
    return $ret
  fi

  # ── Parse response ──────────────────────────────────────────────
  local raw
  raw="$(_zaic_parse_response "$resp_file")"

  if [[ $? -ne 0 || -z "$raw" ]]; then
    echo "${ZSH_AI_COMMANDS_PROVIDER} API error (set ZSH_AI_COMMANDS_DEBUG=true for details)"
    BUFFER="$original_buffer"; zle end-of-line; zle reset-prompt
    [[ "$ZSH_AI_COMMANDS_DEBUG" == true ]] && echo "$resp_file" || rm -f "$resp_file"
    return 1
  fi

  # ── Clean command ───────────────────────────────────────────────
  local cmd
  cmd="$(print -r -- "$raw" | _zaic_clean_command)"

  if [[ -z "$cmd" ]]; then
    echo "Empty command after parsing"
    BUFFER="$original_buffer"; zle end-of-line; zle reset-prompt
    [[ "$ZSH_AI_COMMANDS_DEBUG" == true ]] && echo "$resp_file" || rm -f "$resp_file"
    return 1
  fi

  # ── Preview and accept/reject ────────────────────────────────────
  BUFFER="$cmd"
  CURSOR=$#BUFFER
  region_highlight=("0 $#BUFFER fg=cyan,bold")
  zle -R "▶ Enter = accept  |  Any other key = restore"

  local key
  read -k 1 key
  # Drain remaining bytes from escape sequences (e.g., arrow keys send \e[A)
  if [[ "$key" == $'\e' ]]; then
    local _discard
    while read -t 0.01 -k 1 _discard 2>/dev/null; do :; done
  fi

  region_highlight=()
  if [[ "$key" == $'\n' || "$key" == $'\r' ]]; then
    BUFFER="$cmd"
  else
    BUFFER="$original_buffer"
  fi

  zle end-of-line
  zle reset-prompt

  [[ "$ZSH_AI_COMMANDS_DEBUG" == true ]] && echo "$resp_file" || rm -f "$resp_file"
}

autoload fzf_ai_commands
zle -N fzf_ai_commands
bindkey "$ZSH_AI_COMMANDS_HOTKEY" fzf_ai_commands
