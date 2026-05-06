#!/usr/bin/zsh

# ── Provider abstraction ─────────────────────────────────────────
# _zaic_build_request  — sets _zaic_url, _zaic_headers, _zaic_body in caller scope
# _zaic_parse_response — prints raw text to stdout, returns 1 on error
# ─────────────────────────────────────────────────────────────────

# ── Gemini ────────────────────────────────────────────────────────

_zaic_build_request_gemini() {
  local sys_prompt="$1" user_query="$2"

  _zaic_url="https://generativelanguage.googleapis.com/v1beta/models/${ZSH_AI_COMMANDS_MODEL}:generateContent?key=$ZSH_AI_COMMANDS_GEMINI_API_KEY"
  _zaic_headers=("Content-Type: application/json" "Accept: application/json")
  _zaic_body=$(
    jq -n \
      --arg sys  "$sys_prompt" \
      --arg user "$user_query" \
      '{
        system_instruction: { parts: { text: $sys } },
        contents: [{ role: "user", parts: { text: $user } }],
        generationConfig: { maxOutputTokens: 512, temperature: 0.2 }
      }'
  ) || return 1
}

_zaic_parse_response_gemini() {
  local resp_file="$1"

  local raw
  raw="$(jq -r '
    .candidates[0].content.parts
    | map(.text // "")
    | join("\n")
  ' "$resp_file" 2>/dev/null)"

  if [[ -z "$raw" || "$raw" == "null" ]]; then
    local err
    err="$(jq -r '
      .error.message
      // .promptFeedback.blockReasonMessage
      // .promptFeedback.blockReason
      // "unknown error (set ZSH_AI_COMMANDS_DEBUG=true)"
    ' "$resp_file" 2>/dev/null)"
    echo "Gemini API error: $err" >&2
    return 1
  fi

  print -r -- "$raw"
}

# ── OpenAI ────────────────────────────────────────────────────────

_zaic_build_request_openai() {
  local sys_prompt="$1" user_query="$2"

  _zaic_url="${ZSH_AI_COMMANDS_OPENAI_ENDPOINT}"
  _zaic_headers=(
    "Content-Type: application/json"
    "Authorization: Bearer $ZSH_AI_COMMANDS_OPENAI_API_KEY"
  )

  local service_tier="auto"
  [[ "$ZSH_AI_COMMANDS_OPENAI_PRIORITY" == true ]] && service_tier="priority"

  # Reasoning:
  # Supported values are model-dependent and can include: none, minimal, low, medium, high, and xhigh
  # https://developers.openai.com/api/reference/resources/responses/methods/create
  local reasoning_level="low"
  _zaic_body=$(
    jq -n \
      --arg model "$ZSH_AI_COMMANDS_MODEL" \
      --arg reasoning_effort "$reasoning_level" \
      --arg sys   "$sys_prompt" \
      --arg user  "$user_query" \
      --arg tier  "$service_tier" \
      '{
        model: $model,
        reasoning: { effort: $reasoning_effort },
        instructions: $sys,
        input: $user,
        max_output_tokens: 512,
        service_tier: $tier
      }'
  ) || return 1
}

_zaic_parse_response_openai() {
  local resp_file="$1"

  local raw
  raw="$(jq -r '.output[1].content[0].text // empty' "$resp_file" 2>/dev/null)"

  if [[ -z "$raw" ]]; then
    local err
    err="$(jq -r '
      .error // "unknown error (set ZSH_AI_COMMANDS_DEBUG=true)"
    ' "$resp_file" 2>/dev/null)"
    echo "OpenAI API error: $err" >&2
    return 1
  fi

  print -r -- "$raw"
}

# ── OpenRouter ────────────────────────────────────────────────────
# Uses /chat/completions (not /responses). Reasoning shape varies by
# upstream model: gpt-oss requires effort, qwen3 thinking models only
# honor enabled:false. We branch on the model slug.

_zaic_build_request_openrouter() {
  local sys_prompt="$1" user_query="$2"

  _zaic_url='https://openrouter.ai/api/v1/chat/completions'
  _zaic_headers=(
    "Content-Type: application/json"
    "Authorization: Bearer $ZSH_AI_COMMANDS_OPENROUTER_API_KEY"
  )

  local reasoning='{"effort":"low"}'
  [[ "$ZSH_AI_COMMANDS_MODEL" == *qwen* ]] && reasoning='{"enabled":false}'

  _zaic_body=$(
    jq -n \
      --arg model "$ZSH_AI_COMMANDS_MODEL" \
      --arg sys   "$sys_prompt" \
      --arg user  "$user_query" \
      --argjson reasoning "$reasoning" \
      '{
        model: $model,
        reasoning: $reasoning,
        messages: [
          { role: "system", content: $sys },
          { role: "user",   content: $user }
        ],
        max_tokens: 512,
        temperature: 0.2
      }'
  ) || return 1
}

_zaic_parse_response_openrouter() {
  local resp_file="$1"

  local raw
  raw="$(jq -r '.choices[0].message.content // empty' "$resp_file" 2>/dev/null)"

  if [[ -z "$raw" ]]; then
    local err
    err="$(jq -r '
      (.error.message // .error // "unknown error (set ZSH_AI_COMMANDS_DEBUG=true)")
      | tostring
    ' "$resp_file" 2>/dev/null)"
    echo "OpenRouter API error: $err" >&2
    return 1
  fi

  print -r -- "$raw"
}

# ── Dispatchers ───────────────────────────────────────────────────

_zaic_build_request() {
  local sys_prompt="$1" user_query="$2"
  "_zaic_build_request_${ZSH_AI_COMMANDS_PROVIDER}" "$sys_prompt" "$user_query"
}

_zaic_parse_response() {
  local resp_file="$1"
  "_zaic_parse_response_${ZSH_AI_COMMANDS_PROVIDER}" "$resp_file"
}
