#!/usr/bin/env zsh
set -uo pipefail

# bench.zsh — Benchmark LLM provider latency for zsh-llm-replace
# Runs 5 prompts per model, reports avg time, output tokens, and cost.

# ── Pricing (USD per 1M tokens) ─────────────────────────────────
typeset -A COST_IN COST_OUT
COST_IN=(  gemini-3-flash-preview 0.50  gemini-2.5-flash 0.30  gpt-4o 4.25   gpt-4.1-mini 0.70  gpt-5.4-mini 0.75  gpt-5.6-sol 2.50  gpt-5.6-luna 0.10  gpt-6.1-sol 2.00  gpt-6-luna 0.10 )
COST_OUT=( gemini-3-flash-preview 3.00  gemini-2.5-flash 2.50  gpt-4o 17.00  gpt-4.1-mini 2.80  gpt-5.4-mini 4.50  gpt-5.6-sol 15.00 gpt-5.6-luna 0.60  gpt-6.1-sol 10.00 gpt-6-luna 0.50 )

OPENAI_FAST="${ZSH_AI_COMMANDS_OPENAI_FAST:-${ZSH_AI_COMMANDS_OPENAI_PRIORITY:-true}}"

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
  [[ -z "${ZSH_AI_COMMANDS_OPENROUTER_API_KEY:-}" ]] && { print -P "%F{red}ZSH_AI_COMMANDS_OPENROUTER_API_KEY not set%f" >&2; fail=1; }
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

call_openrouter() {
  local model=$1 query=$2 out=$3
  local reasoning='{"effort":"low"}'
  [[ $model == *qwen* ]] && reasoning='{"enabled":false}'
  local body
  body=$(jq -n --arg m "$model" --arg sys "$SYS_PROMPT" --arg user "$query" --argjson r "$reasoning" '{
    model: $m,
    reasoning: $r,
    messages: [
      { role: "system", content: $sys },
      { role: "user",   content: $user }
    ],
    max_tokens: 512,
    temperature: 0.2
  }') || return 1
  curl -s -o "$out" -w '%{time_total}' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ZSH_AI_COMMANDS_OPENROUTER_API_KEY}" \
    https://openrouter.ai/api/v1/chat/completions -d "$body"
}

call_openai() {
  local model=$1 query=$2 out=$3 reasoning_effort=${4:-}
  local url="${ZSH_AI_COMMANDS_OPENAI_ENDPOINT:-https://api.openai.com/v1/responses}"
  local tier=auto
  [[ $OPENAI_FAST == true ]] && tier=fast
  local body
  body=$(jq -n --arg m "$model" --arg sys "$SYS_PROMPT" --arg user "$query" --arg tier "$tier" --arg effort "$reasoning_effort" '{
    model: $m,
    instructions: $sys,
    input: $user,
    max_output_tokens: 512,
    service_tier: $tier
  } + if $effort == "" then {} else { reasoning: { effort: $effort } } end') || return 1
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
  jq -r '[(.usage.input_tokens // 0), (.usage.output_tokens // 0)] | @tsv' "$1" 2>/dev/null || printf '0\t0'
}
# OpenRouter reports cost directly in USD on .usage.cost
tokens_openrouter() {
  jq -r '[(.usage.prompt_tokens // 0), (.usage.completion_tokens // 0), (.usage.cost // 0)] | @tsv' "$1" 2>/dev/null || printf '0\t0\t0'
}

# ── Response text + prompt-specific sanity checks ───────────────
response_text() {
  local provider=$1 file=$2
  case $provider in
    gemini) jq -r '[.candidates[0].content.parts[]?.text] | join("")' "$file" 2>/dev/null ;;
    openai) jq -r '[.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text] | join("\n")' "$file" 2>/dev/null ;;
    openrouter) jq -r '.choices[0].message.content // ""' "$file" 2>/dev/null ;;
  esac
}

sanity_check() {
  local prompt_index=$1 command=$2

  # Every answer must satisfy the plugin's core output contract.
  [[ -n $command && $command != *$'\n'* && $command != *'```'* ]] || return 1
  zsh -n -c "$command" >/dev/null 2>&1 || return 1

  case $prompt_index in
    1) [[ ($command == *ls* && $command == *S*) ||
          (($command == *find* || $command == *fd*) && $command == *sort* && $command == *r*) ]] ;;
    2) [[ $command == *TODO* && ($command == *rg* || $command == *grep*) &&
          ($command == *py* || $command == *python*) ]] ;;
    3) [[ $command == *du* && $command == *sort* &&
          (($command == *r* && ($command == *head* || $command == *'1,10'* || $command == *'10q'*)) ||
           ($command == *tail* && $command == *10*)) ]] ;;
    4) [[ $command == *js* && ($command == *sed* || $command == *perl*) &&
          ($command == *find* || $command == *fd* || $command == *rg* || $command == *'**/'*) &&
          ($command == *'\t'* || $command == *$'\t'*) ]] ;;
    5) [[ $command == *git*log* && $command == *since* && $command == *stat* ]] ;;
  esac
}

# ── Results accumulators ─────────────────────────────────────────
typeset -A R_TIME R_TOK R_COST R_QUALITY
LABELS=()

# ── Benchmark one model ──────────────────────────────────────────
bench() {
  # Locals declared up front: re-running `local foo` inside a loop in zsh
  # echoes the existing value of `foo` to stdout, polluting the table.
  local label=$1 provider=$2 model=$3 reasoning_effort=${4:-}
  local n=${#PROMPTS[@]}
  local tmp q t err in_tok out_tok cost i command call_status
  local sum_t=0 sum_out=0 sum_cost=0 errors=0 quality_passes=0
  local counted quality_mark

  LABELS+=("$label")
  tmp=$(mktemp /tmp/bench.XXXXXX.json) || return 1

  printf '\n\e[1m── %s ──\e[0m\n' "$label"

  for i in {1..$n}; do
    q=${PROMPTS[$i]}
    printf '  [%d/%d] %-44s ' "$i" "$n" "$q"

    case $provider in
      gemini)     t=$(call_gemini     "$model" "$q" "$tmp") ;;
      openai)     t=$(call_openai     "$model" "$q" "$tmp" "$reasoning_effort") ;;
      openrouter) t=$(call_openrouter "$model" "$q" "$tmp") ;;
    esac
    call_status=$?

    if (( call_status != 0 )) || ! jq -e . "$tmp" >/dev/null 2>&1; then
      printf '\e[31mERROR: request failed or returned invalid JSON\e[0m\n'
      (( errors++ ))
      continue
    fi

    err=$(jq -r '.error.message // empty' "$tmp" 2>/dev/null)
    if [[ -n $err ]]; then
      printf '\e[31mERROR: %s\e[0m\n' "$err"
      (( errors++ ))
      continue
    fi

    command=$(response_text "$provider" "$tmp")
    if sanity_check "$i" "$command"; then
      quality_mark='✓'
      (( quality_passes++ ))
    else
      quality_mark='✗'
    fi

    case $provider in
      gemini)
        read in_tok out_tok <<< "$(tokens_gemini "$tmp")"
        cost=$(awk "BEGIN { printf \"%.8f\", ($in_tok * ${COST_IN[$model]} + $out_tok * ${COST_OUT[$model]}) / 1000000 }")
        ;;
      openai)
        read in_tok out_tok <<< "$(tokens_openai "$tmp")"
        cost=$(awk "BEGIN { printf \"%.8f\", ($in_tok * ${COST_IN[$model]} + $out_tok * ${COST_OUT[$model]}) / 1000000 }")
        [[ $OPENAI_FAST == true ]] && cost=$(awk "BEGIN { printf \"%.8f\", $cost * 2 }")
        ;;
      openrouter)
        read in_tok out_tok cost <<< "$(tokens_openrouter "$tmp")"
        ;;
    esac

    printf '%5.2fs  %4d tok  $%.6f  %s\n' "$t" "$out_tok" "$cost" "$quality_mark"
    [[ $quality_mark == '✗' ]] && printf '         command: %s\n' "$command"

    sum_t=$(awk    "BEGIN { printf \"%.4f\", $sum_t    + $t }")
    sum_out=$(awk  "BEGIN { printf \"%.0f\", $sum_out  + $out_tok }")
    sum_cost=$(awk "BEGIN { printf \"%.8f\", $sum_cost + $cost }")
  done

  rm -f "$tmp"

  counted=$(( n - errors ))
  if (( counted > 0 )); then
    R_TIME[$label]=$(awk "BEGIN { printf \"%.1f\", $sum_t    / $counted }")
    R_TOK[$label]=$(awk  "BEGIN { printf \"%.0f\", $sum_out  / $counted }")
    R_COST[$label]=$(awk "BEGIN { printf \"%.6f\", $sum_cost / $counted }")
    R_QUALITY[$label]="${quality_passes}/${counted}"
  else
    R_TIME[$label]="-.-"
    R_TOK[$label]="-"
    R_COST[$label]="-.------"
    R_QUALITY[$label]="-"
  fi

  printf '  ─────────────────────────────────────────────────────────\n'
  printf '  \e[1mAVG:  %6ss  %5s tok  $%s  quality %s\e[0m\n' \
    "${R_TIME[$label]}" "${R_TOK[$label]}" "${R_COST[$label]}" "${R_QUALITY[$label]}"
}

# ── Main ─────────────────────────────────────────────────────────
check_keys

printf '\n\e[1m'
echo '╔══════════════════════════════════════════════════════════════╗'
echo '║          LLM Provider Benchmark · zsh-llm-replace            ║'
echo '╠══════════════════════════════════════════════════════════════╣'
printf '║  Prompts: %-3d  |  ' "${#PROMPTS[@]}"
if [[ $OPENAI_FAST == true ]]; then
  printf 'OpenAI: Fast mode (2x cost)                ║\n'
else
  printf 'OpenAI: standard tier                      ║\n'
fi
echo '╚══════════════════════════════════════════════════════════════╝'
printf '\e[0m'

bench "gemini-3-flash-preview"  gemini  gemini-3-flash-preview
bench "gemini-2.5-flash"        gemini  gemini-2.5-flash
bench "gpt-4o"                  openai  gpt-4o        none
bench "gpt-4.1-mini"            openai  gpt-4.1-mini  none
bench "gpt-5.4-mini"            openai  gpt-5.4-mini  none
bench "gpt-5.6-sol [none]"       openai  gpt-5.6-sol   none
bench "gpt-5.6-luna [none]"      openai  gpt-5.6-luna  none
bench "gpt-5.6-luna [low]"       openai  gpt-5.6-luna  low
bench "gpt-6.1-sol [low]"        openai  gpt-6.1-sol   low
bench "gpt-6-luna [none]"        openai  gpt-6-luna    none
bench "gpt-6-luna [low]"         openai  gpt-6-luna    low
bench "or:gpt-oss-120b:nitro"   openrouter  openai/gpt-oss-120b:nitro
bench "or:qwen3.5-35b-a3b:nitro" openrouter qwen/qwen3.5-35b-a3b:nitro

# ── Summary table ────────────────────────────────────────────────
printf '\n\e[1m'
echo '═══ Summary ══════════════════════════════════════════════════'
printf '  %-28s  %8s  %6s  %12s  %7s\n' "Model" "Latency" "Tokens" "Cost x1000" "Quality"
printf '  %-28s  %8s  %6s  %12s  %7s\n' "────────────────────────────" "────────" "──────" "────────────" "───────"
for label in "${LABELS[@]}"; do
  if [[ ${R_COST[$label]} == '-.------' ]]; then
    scaled_cost='-.---'
  else
    scaled_cost=$(awk "BEGIN { printf \"%.3f\", ${R_COST[$label]} * 1000 }")
  fi
  printf '  %-28s  %7ss  %6s  %12s  %7s\n' \
    "$label" "${R_TIME[$label]}" "${R_TOK[$label]}" '$'"$scaled_cost" "${R_QUALITY[$label]}"
done
printf '\e[0m\n'

echo "Summary costs are per-request averages based on token counts, displayed x1000."
echo "Quality is a static sanity check of the five prompt-specific command requirements."
[[ $OPENAI_FAST == true ]] && echo "OpenAI costs include the 2x Fast-mode multiplier."
echo
