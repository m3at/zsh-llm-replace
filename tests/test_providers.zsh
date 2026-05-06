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

# Clean response
assert_eq "openai: clean response" \
  "ls -la" \
  "$(_zaic_parse_response_openai "$_fixtures_dir/openai_clean.json")"

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
