#!/usr/bin/env zsh
set -uo pipefail

# bench.zsh — Benchmark LLM provider latency for zsh-llm-replace
# Runs 5 prompts per model, reports avg time, output tokens, and cost.

# ── Pricing (USD per 1M tokens) ─────────────────────────────────
typeset -A COST_IN COST_OUT
COST_IN=(  gemini-3-flash-preview 0.50  gemini-2.5-flash 0.30  gpt-4o 4.25   gpt-4.1-mini 0.70  gpt-5-mini 0.45  gpt-5.4-mini 0.75  gpt-5.4-nano 0.2 )
COST_OUT=( gemini-3-flash-preview 3.00  gemini-2.5-flash 2.50  gpt-4o 17.00  gpt-4.1-mini 2.80  gpt-5-mini 3.6   gpt-5.4-mini 4.5   gpt-5.4-nano 1.25 )

OPENAI_PRIORITY="${ZSH_AI_COMMANDS_OPENAI_PRIORITY:-true}"

# ── Test prompts ─────────────────────────────────────────────────
PROMPTS=(
  "list all files sorted by size descending"
  "find all TODO comments in python files recursively"
  "show disk usage of top 10 largest directories"
  "replace all tabs with 2 spaces in all js files"
  "show git commits from last week with stats"
)

# ── System prompt (matches the plugin) ───────────────────────────
read -r -d '' SYS_PROMPT <<'PROMPT'
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

# ── Validate API keys ───────────────────────────────────────────
check_keys() {
  local fail=0
  [[ -z "${ZSH_AI_COMMANDS_GEMINI_API_KEY:-}" ]] && { print -P "%F{red}ZSH_AI_COMMANDS_GEMINI_API_KEY not set%f" >&2; fail=1; }
  [[ -z "${ZSH_AI_COMMANDS_OPENAI_API_KEY:-}" ]] && { print -P "%F{red}ZSH_AI_COMMANDS_OPENAI_API_KEY not set%f" >&2; fail=1; }
  (( fail )) && exit 1
}

# ── API callers (return wall-clock seconds via curl -w) ──────────
call_gemini() {
  local model=$1 query=$2 out=$3
  local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${ZSH_AI_COMMANDS_GEMINI_API_KEY}"
  local body
  body=$(jq -n --arg sys "$SYS_PROMPT" --arg user "$query" '{
    system_instruction: { parts: { text: $sys } },
    contents: [{ role: "user", parts: { text: $user } }],
    generationConfig: { maxOutputTokens: 512, temperature: 0.2 }
  }') || return 1
  curl -s -o "$out" -w '%{time_total}' \
    -H 'Content-Type: application/json' \
    "$url" -d "$body"
}

call_openai() {
  local model=$1 query=$2 out=$3
  local url="${ZSH_AI_COMMANDS_OPENAI_ENDPOINT:-https://api.openai.com/v1/chat/completions}"
  local tier=auto
  [[ $OPENAI_PRIORITY == true ]] && tier=priority
  local body
  body=$(jq -n --arg m "$model" --arg sys "$SYS_PROMPT" --arg user "$query" --arg tier "$tier" '{
    model: $m,
    messages: [
      { role: "system", content: $sys },
      { role: "user",   content: $user }
    ],
    max_completion_tokens: 512,
    service_tier: $tier
  }') || return 1
  curl -s -o "$out" -w '%{time_total}' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ZSH_AI_COMMANDS_OPENAI_API_KEY}" \
    "$url" -d "$body"
}

# ── Token extractors ─────────────────────────────────────────────
tokens_gemini() {
  jq -r '[(.usageMetadata.promptTokenCount // 0), (.usageMetadata.candidatesTokenCount // 0)] | @tsv' "$1" 2>/dev/null || printf '0\t0'
}
tokens_openai() {
  jq -r '[(.usage.prompt_tokens // 0), (.usage.completion_tokens // 0)] | @tsv' "$1" 2>/dev/null || printf '0\t0'
}

# ── Results accumulators ─────────────────────────────────────────
typeset -A R_TIME R_TOK R_COST
LABELS=()

# ── Benchmark one model ──────────────────────────────────────────
bench() {
  local label=$1 provider=$2 model=$3
  LABELS+=("$label")
  local n=${#PROMPTS[@]}
  local tmp
  tmp=$(mktemp /tmp/bench.XXXXXX.json) || return 1
  local sum_t=0 sum_in=0 sum_out=0 sum_cost=0 errors=0

  printf '\n\e[1m── %s ──\e[0m\n' "$label"

  for i in {1..$n}; do
    local q=${PROMPTS[$i]}
    printf '  [%d/%d] %-44s ' "$i" "$n" "$q"

    local t
    if [[ $provider == gemini ]]; then
      t=$(call_gemini "$model" "$q" "$tmp")
    else
      t=$(call_openai "$model" "$q" "$tmp")
    fi

    local err
    err=$(jq -r '.error.message // empty' "$tmp" 2>/dev/null)
    if [[ -n $err ]]; then
      printf '\e[31mERROR: %s\e[0m\n' "$err"
      (( errors++ ))
      continue
    fi

    local in_tok out_tok
    if [[ $provider == gemini ]]; then
      read in_tok out_tok <<< "$(tokens_gemini "$tmp")"
    else
      read in_tok out_tok <<< "$(tokens_openai "$tmp")"
    fi

    local cost
    cost=$(awk "BEGIN { printf \"%.8f\", ($in_tok * ${COST_IN[$model]} + $out_tok * ${COST_OUT[$model]}) / 1000000 }")
    [[ $provider == openai && $OPENAI_PRIORITY == true ]] && \
      cost=$(awk "BEGIN { printf \"%.8f\", $cost * 2 }")

    printf '%5.2fs  %4d tok  $%.6f\n' "$t" "$out_tok" "$cost"

    sum_t=$(awk   "BEGIN { printf \"%.4f\", $sum_t   + $t }")
    sum_out=$(awk "BEGIN { printf \"%.0f\", $sum_out + $out_tok }")
    sum_cost=$(awk "BEGIN { printf \"%.8f\", $sum_cost + $cost }")
  done

  rm -f "$tmp"

  local counted=$(( n - errors ))
  if (( counted > 0 )); then
    R_TIME[$label]=$(awk  "BEGIN { printf \"%.1f\", $sum_t    / $counted }")
    R_TOK[$label]=$(awk   "BEGIN { printf \"%.0f\", $sum_out  / $counted }")
    R_COST[$label]=$(awk  "BEGIN { printf \"%.6f\", $sum_cost / $counted }")
  else
    R_TIME[$label]="-.-"
    R_TOK[$label]="-"
    R_COST[$label]="-.------"
  fi

  printf '  ─────────────────────────────────────────────────────────\n'
  printf '  \e[1mAVG:  %6ss  %5s tok  $%s\e[0m\n' \
    "${R_TIME[$label]}" "${R_TOK[$label]}" "${R_COST[$label]}"
}

# ── Main ─────────────────────────────────────────────────────────
check_keys

printf '\n\e[1m'
echo '╔══════════════════════════════════════════════════════════════╗'
echo '║          LLM Provider Benchmark · zsh-llm-replace            ║'
echo '╠══════════════════════════════════════════════════════════════╣'
printf '║  Prompts: %-3d  |  ' "${#PROMPTS[@]}"
if [[ $OPENAI_PRIORITY == true ]]; then
  printf 'OpenAI: priority tier (2x cost)            ║\n'
else
  printf 'OpenAI: standard tier                      ║\n'
fi
echo '╚══════════════════════════════════════════════════════════════╝'
printf '\e[0m'

bench "gemini-3-flash-preview"  gemini  gemini-3-flash-preview
bench "gemini-2.5-flash"        gemini  gemini-2.5-flash
bench "gpt-4o"                  openai  gpt-4o
bench "gpt-4.1-mini"            openai  gpt-4.1-mini
bench "gpt-5-mini"              openai  gpt-5-mini
bench "gpt-5.4-mini"            openai  gpt-5.4-mini
bench "gpt-5.4-nano"            openai  gpt-5.4-nano

# ── Summary table ────────────────────────────────────────────────
printf '\n\e[1m'
echo '═══ Summary ══════════════════════════════════════════════════'
printf '  %-26s  %8s  %6s  %12s\n' "Model" "Latency" "Tokens" "Cost x1000"
printf '  %-26s  %8s  %6s  %12s\n' "──────────────────────────" "────────" "──────" "────────────"
for label in "${LABELS[@]}"; do
  if [[ ${R_COST[$label]} == '-.------' ]]; then
    scaled_cost='-.---'
  else
    scaled_cost=$(awk "BEGIN { printf \"%.3f\", ${R_COST[$label]} * 1000 }")
  fi
  printf '  %-26s  %7ss  %6s  %12s\n' \
    "$label" "${R_TIME[$label]}" "${R_TOK[$label]}" '$'"$scaled_cost"
done
printf '\e[0m\n'

echo "Summary costs are per-request averages based on token counts, displayed x1000."
[[ $OPENAI_PRIORITY == true ]] && echo "OpenAI costs include 2x priority-tier multiplier."
echo
