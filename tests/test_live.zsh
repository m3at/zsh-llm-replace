#!/usr/bin/zsh
# ── Optional live API smoke tests ────────────────────────────────
# Run with: zsh tests/run.zsh --live
# Requires API keys to be set in the environment.
# ─────────────────────────────────────────────────────────────────

_live_query="list files sorted by size descending"

# ── Gemini live test ─────────────────────────────────────────────

if (( ${+ZSH_AI_COMMANDS_GEMINI_API_KEY} )); then
  echo "  [live] Testing Gemini..."

  ZSH_AI_COMMANDS_PROVIDER=gemini
  : ${ZSH_AI_COMMANDS_MODEL:=gemini-2.5-flash}

  local _zaic_url _zaic_body _zaic_resp_file _zaic_raw _zaic_cmd
  typeset -a _zaic_headers
  _zaic_build_request_gemini \
    "You are a shell expert. Output ONLY a single command, nothing else." \
    "$_live_query"

  _zaic_resp_file="$(mktemp /tmp/zaic_live.XXXXXX.json)"
  local _curl_args=("--silent" "--max-time" "30" "$_zaic_url")
  for h in "${_zaic_headers[@]}"; do
    _curl_args+=("-H" "$h")
  done
  _curl_args+=("-d" "$_zaic_body")
  curl "${_curl_args[@]}" > "$_zaic_resp_file"

  _zaic_raw="$(_zaic_parse_response_gemini "$_zaic_resp_file")"
  assert_not_empty "gemini: live response not empty" "$_zaic_raw"

  _zaic_cmd="$(print -r -- "$_zaic_raw" | _zaic_clean_command)"
  assert_not_empty "gemini: live cleaned command not empty" "$_zaic_cmd"

  echo "  [live] Gemini returned: $_zaic_cmd"
  rm -f "$_zaic_resp_file"
else
  echo "  [skip] Gemini: ZSH_AI_COMMANDS_GEMINI_API_KEY not set"
fi

# ── OpenAI live test ─────────────────────────────────────────────

if (( ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )); then
  echo "  [live] Testing OpenAI..."

  ZSH_AI_COMMANDS_PROVIDER=openai
  : ${ZSH_AI_COMMANDS_MODEL:=gpt-4o-mini}
  : ${ZSH_AI_COMMANDS_OPENAI_ENDPOINT:=https://api.openai.com/v1/chat/completions}

  local _zaic_url _zaic_body _zaic_resp_file _zaic_raw _zaic_cmd
  typeset -a _zaic_headers
  _zaic_build_request_openai \
    "You are a shell expert. Output ONLY a single command, nothing else." \
    "$_live_query"

  _zaic_resp_file="$(mktemp /tmp/zaic_live.XXXXXX.json)"
  local _curl_args=("--silent" "--max-time" "30" "$_zaic_url")
  for h in "${_zaic_headers[@]}"; do
    _curl_args+=("-H" "$h")
  done
  _curl_args+=("-d" "$_zaic_body")
  curl "${_curl_args[@]}" > "$_zaic_resp_file"

  _zaic_raw="$(_zaic_parse_response_openai "$_zaic_resp_file")"
  assert_not_empty "openai: live response not empty" "$_zaic_raw"

  _zaic_cmd="$(print -r -- "$_zaic_raw" | _zaic_clean_command)"
  assert_not_empty "openai: live cleaned command not empty" "$_zaic_cmd"

  echo "  [live] OpenAI returned: $_zaic_cmd"
  rm -f "$_zaic_resp_file"
else
  echo "  [skip] OpenAI: ZSH_AI_COMMANDS_OPENAI_API_KEY not set"
fi
