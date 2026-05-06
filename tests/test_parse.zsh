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
# `\<newline>` is a shell line-continuation: the backslash and newline are
# consumed when joining, so the result must not contain a literal `\`.
assert_eq "multi-line fence with line-continuation joined cleanly" \
  "find . -name '*.txt' -exec grep -l 'foo' {} +" \
  "$(_tc "$_t")"

# Same behavior outside a fence (raw multi-line response).
_t=$(printf 'find . -name "*.log" \\\n  -delete\n')
assert_eq "line-continuation joined cleanly (no fence)" \
  'find . -name "*.log" -delete' \
  "$(_tc "$_t")"

# Backslash parity: an EVEN run of trailing `\` is literal escapes, not
# a continuation. Joining must preserve all of them.
_t=$(printf 'echo \\\\\nnext\n')
assert_eq "even trailing backslashes are not line-continuations" \
  'echo \\ next' \
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

# ── Internal whitespace must survive flattening ─────────────────
# Regression: the old flatten collapsed every run of whitespace, corrupting
# commands like `sed 's/\t/  /g'` (two spaces) into `sed 's/\t/ /g'` (one).

assert_eq "internal multi-spaces preserved (no fence)" \
  "sed 's/\t/  /g'" \
  "$(_tc "sed 's/\t/  /g'")"

_t=$(cat <<'FENCE'
```bash
awk '{print $1   $2   $3}' file
```
FENCE
)
assert_eq "internal multi-spaces preserved (inside fence)" \
  "awk '{print \$1   \$2   \$3}' file" \
  "$(_tc "$_t")"

# ── Unpaired fence markers (model leaked ``` at the boundary) ────
# Stage-1 paired extraction fails, so stage 3 has to strip these.

assert_eq "trailing fence on same line as command stripped" \
  "tar -czf out.tgz ." \
  "$(_tc 'tar -czf out.tgz . ```')"

_t=$(printf 'tar -czf out.tgz .\n```\n')
assert_eq "trailing fence on its own line stripped" \
  "tar -czf out.tgz ." \
  "$(_tc "$_t")"

assert_eq "leading fence on same line as command stripped" \
  "ls -la" \
  "$(_tc '```ls -la')"

# Unpaired opening fence with a language label, no closer — body still
# extracted, label not leaked.
_t=$(printf '```bash\nls -la\n')
assert_eq "unpaired opening fence with label extracts body" \
  "ls -la" \
  "$(_tc "$_t")"

# Unknown info string (model used ```console, ```text, ```shell-session…).
_t=$(cat <<'FENCE'
```console
ls -la
```
FENCE
)
assert_eq "fence with unknown info string extracts body" \
  "ls -la" \
  "$(_tc "$_t")"

# Two fenced blocks in one response — take only the first (the buffer
# can only hold one command).
_t=$(cat <<'FENCE'
```bash
ls -la
```
```bash
echo second
```
FENCE
)
assert_eq "multiple fenced blocks: first only" \
  "ls -la" \
  "$(_tc "$_t")"

# ── Edge cases ───────────────────────────────────────────────────

assert_eq "empty input"          "" "$(_tc '')"
assert_eq "whitespace-only input" "" "$(printf '   \n  \n' | _zaic_clean_command)"
