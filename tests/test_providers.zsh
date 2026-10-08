#!/usr/bin/zsh
# ── Fixture-based provider response extraction tests ─────────────

_fixtures_dir="${_test_dir}/fixtures"

# ── Gemini fixtures ──────────────────────────────────────────────

# Clean response
assert_eq "gemini: clean response" \
  "ls -la" \
  "$(_zaic_parse_response_gemini "$_fixtures_dir/gemini_clean.json")"

# Fenced response (raw extraction, before clean_command)
assert_eq "gemini: fenced response has fence markers" \
  '```bash
ls -la
```' \
  "$(_zaic_parse_response_gemini "$_fixtures_dir/gemini_fenced.json")"

# Multi-part response
assert_eq "gemini: multi-part response" \
  "echo hello
echo world" \
  "$(_zaic_parse_response_gemini "$_fixtures_dir/gemini_multipart.json")"

# Error response
local _gerr
_gerr="$(_zaic_parse_response_gemini "$_fixtures_dir/gemini_error.json" 2>/dev/null)"
assert_eq "gemini: error returns empty" "" "$_gerr"

# Verify error message goes to stderr
local _gerr_msg
_gerr_msg="$(_zaic_parse_response_gemini "$_fixtures_dir/gemini_error.json" 2>&1 1>/dev/null)"
assert_not_empty "gemini: error message on stderr" "$_gerr_msg"

# ── OpenAI fixtures ──────────────────────────────────────────────

# Request service tier
typeset -g ZSH_AI_COMMANDS_MODEL='gpt-6-luna'
typeset -g ZSH_AI_COMMANDS_OPENAI_ENDPOINT='https://api.openai.com/v1/responses'
typeset -g ZSH_AI_COMMANDS_OPENAI_API_KEY='test-key'
typeset -g ZSH_AI_COMMANDS_OPENAI_FAST=true
_zaic_build_request_openai "system" "query"
assert_eq "openai: Fast mode request tier" \
  "fast" \
  "$(jq -r '.service_tier' <<< "$_zaic_body")"
assert_eq "openai: reasoning effort is fixed to none" \
  "none" \
  "$(jq -r '.reasoning.effort' <<< "$_zaic_body")"

typeset -g ZSH_AI_COMMANDS_OPENAI_FAST=false
_zaic_build_request_openai "system" "query"
assert_eq "openai: standard request tier" \
  "auto" \
  "$(jq -r '.service_tier' <<< "$_zaic_body")"

# Clean response
assert_eq "openai: clean response" \
  "ls -la" \
  "$(_zaic_parse_response_openai "$_fixtures_dir/openai_clean.json")"

# A none-effort response has no leading reasoning item.
assert_eq "openai: response without reasoning item" \
  "ls -la" \
  "$(_zaic_parse_response_openai "$_fixtures_dir/openai_no_reasoning.json")"

# Fenced response
assert_eq "openai: fenced response has fence markers" \
  '```bash
ls -la
```' \
  "$(_zaic_parse_response_openai "$_fixtures_dir/openai_fenced.json")"

# Error response
local _oerr
_oerr="$(_zaic_parse_response_openai "$_fixtures_dir/openai_error.json" 2>/dev/null)"
assert_eq "openai: error returns empty" "" "$_oerr"

# Verify error message goes to stderr
local _oerr_msg
_oerr_msg="$(_zaic_parse_response_openai "$_fixtures_dir/openai_error.json" 2>&1 1>/dev/null)"
assert_not_empty "openai: error message on stderr" "$_oerr_msg"

# ── OpenRouter fixtures ──────────────────────────────────────────

assert_eq "openrouter: clean response" \
  "ls -la" \
  "$(_zaic_parse_response_openrouter "$_fixtures_dir/openrouter_clean.json")"

assert_eq "openrouter: fenced response has fence markers" \
  '```bash
ls -la
```' \
  "$(_zaic_parse_response_openrouter "$_fixtures_dir/openrouter_fenced.json")"

local _orerr
_orerr="$(_zaic_parse_response_openrouter "$_fixtures_dir/openrouter_error.json" 2>/dev/null)"
assert_eq "openrouter: error returns empty" "" "$_orerr"

local _orerr_msg
_orerr_msg="$(_zaic_parse_response_openrouter "$_fixtures_dir/openrouter_error.json" 2>&1 1>/dev/null)"
assert_not_empty "openrouter: error message on stderr" "$_orerr_msg"
