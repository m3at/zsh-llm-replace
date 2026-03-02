#!/usr/bin/zsh
# ── zsh-ai-commands test runner ──────────────────────────────────
# Usage: zsh tests/run.zsh [--live]
# ─────────────────────────────────────────────────────────────────

setopt localoptions extendedglob

_test_dir="${0:A:h}"
_root_dir="${_test_dir:h}"

# ── Helpers ───────────────────────────────────────────────────────

typeset -gi _pass=0 _fail=0 _total=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  (( _total++ ))
  if [[ "$expected" == "$actual" ]]; then
    (( _pass++ ))
    printf '  \033[32m✓\033[0m %s\n' "$label"
  else
    (( _fail++ ))
    printf '  \033[31m✗\033[0m %s\n' "$label"
    printf '    expected: %s\n' "${(q)expected}"
    printf '    actual:   %s\n' "${(q)actual}"
  fi
}

assert_not_empty() {
  local label="$1" actual="$2"
  (( _total++ ))
  if [[ -n "$actual" ]]; then
    (( _pass++ ))
    printf '  \033[32m✓\033[0m %s\n' "$label"
  else
    (( _fail++ ))
    printf '  \033[31m✗\033[0m %s\n' "$label"
    printf '    expected non-empty, got empty\n'
  fi
}

_summary() {
  echo
  if (( _fail == 0 )); then
    printf '\033[32mAll %d tests passed.\033[0m\n' "$_total"
  else
    printf '\033[31m%d/%d tests failed.\033[0m\n' "$_fail" "$_total"
  fi
}

# ── Source library files ──────────────────────────────────────────

source "$_root_dir/lib/parse.zsh"
source "$_root_dir/lib/providers.zsh"

# ── Run test suites ──────────────────────────────────────────────

echo "=== Parse tests ==="
source "$_test_dir/test_parse.zsh"

echo
echo "=== Provider tests ==="
source "$_test_dir/test_providers.zsh"

if [[ "$1" == "--live" ]]; then
  echo
  echo "=== Live tests ==="
  source "$_test_dir/test_live.zsh"
fi

# ── Summary ──────────────────────────────────────────────────────

_summary
(( _fail > 0 )) && exit 1
exit 0
