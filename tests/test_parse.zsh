#!/usr/bin/zsh
# ── Unit tests for _zaic_clean_command ───────────────────────────

_tc() { print -r -- "$1" | _zaic_clean_command }

# Passthrough: no fence, no commentary starter — must not be touched.
# One representative covers all the "no transformation" cases.
assert_eq "passthrough: pipe + quotes + subshell" \
  "cat foo.txt | grep 'hello' | awk '{print \$1}'" \
  "$(_tc "cat foo.txt | grep 'hello' | awk '{print \$1}'")"

# Single backticks must not be confused for fences (only ``` triggers extraction).
assert_eq "single backticks not treated as fence" \
  'echo `whoami`' \
  "$(_tc 'echo `whoami`')"

# ── Fenced extraction ────────────────────────────────────────────

local _t
_t=$(cat <<'FENCE'
```bash
ls -la
```
FENCE
)
assert_eq "bash fence extracts command" "ls -la" "$(_tc "$_t")"

_t=$(cat <<'FENCE'
```
ls -la /tmp
```
FENCE
)
assert_eq "bare fence extracts command" "ls -la /tmp" "$(_tc "$_t")"

_t=$(cat <<'FENCE'
Here is the command you need:

```bash
find . -name '*.log' -delete
```

This will delete all log files.
FENCE
)
assert_eq "commentary around fence stripped" \
  "find . -name '*.log' -delete" \
  "$(_tc "$_t")"

_t=$(cat <<'FENCE'
```bash
find . -name '*.txt' \
  -exec grep -l 'foo' {} +
```
FENCE
)
assert_eq "multi-line fence flattened" \
  "find . -name '*.txt' \\ -exec grep -l 'foo' {} +" \
  "$(_tc "$_t")"

# ── Commentary heuristic (no fence) ──────────────────────────────

_t=$(printf 'Here is the command:\nls -la\nThis lists all files.\n')
assert_eq "commentary without fences filtered" "ls -la" "$(_tc "$_t")"

# When everything looks like prose, fall back to the raw text rather
# than returning empty (better to let the user see something wrong
# than nothing at all).
assert_eq "all-commentary fallback returns raw text" \
  "Here is the answer." \
  "$(_tc 'Here is the answer.')"

# ── Edge cases ───────────────────────────────────────────────────

assert_eq "empty input"          "" "$(_tc '')"
assert_eq "whitespace-only input" "" "$(printf '   \n  \n' | _zaic_clean_command)"
