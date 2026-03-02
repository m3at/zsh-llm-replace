#!/usr/bin/zsh
# ── Unit tests for _zaic_clean_command ───────────────────────────

# Helper: pipe a string through _zaic_clean_command
_tc() { print -r -- "$1" | _zaic_clean_command }

# 1. Clean command passthrough
assert_eq "clean command passthrough" \
  "ls -la" \
  "$(_tc 'ls -la')"

# 2. Pipe command passthrough
assert_eq "pipe command passthrough" \
  "cat foo.txt | grep bar | wc -l" \
  "$(_tc 'cat foo.txt | grep bar | wc -l')"

# 3. Command with single quotes
assert_eq "single quotes preserved" \
  "grep 'hello world' file.txt" \
  "$(_tc "grep 'hello world' file.txt")"

# 4. Command with double quotes
assert_eq "double quotes preserved" \
  'echo "hello world"' \
  "$(_tc 'echo "hello world"')"

# 5. Command with $() subshell
assert_eq "subshell preserved" \
  'echo $(date +%Y-%m-%d)' \
  "$(_tc 'echo $(date +%Y-%m-%d)')"

# 6-9: Fenced blocks — use heredocs to avoid backtick quoting issues

local _t6 _t7 _t8 _t9

_t6=$(cat <<'FENCE'
```bash
ls -la
```
FENCE
)
assert_eq "bash fence extracts command" "ls -la" "$(_tc "$_t6")"

_t7=$(cat <<'FENCE'
```zsh
echo hello
```
FENCE
)
assert_eq "zsh fence extracts command" "echo hello" "$(_tc "$_t7")"

_t8=$(cat <<'FENCE'
```sh
pwd
```
FENCE
)
assert_eq "sh fence extracts command" "pwd" "$(_tc "$_t8")"

_t9=$(cat <<'FENCE'
```
ls -la /tmp
```
FENCE
)
assert_eq "bare fence extracts command" "ls -la /tmp" "$(_tc "$_t9")"

# 10. Commentary before and after fenced block
local _t10
_t10=$(cat <<'FENCE'
Here is the command you need:

```bash
find . -name '*.log' -delete
```

This will delete all log files.
FENCE
)
assert_eq "commentary around fence stripped" \
  "find . -name '*.log' -delete" \
  "$(_tc "$_t10")"

# 11. Commentary without fences gets filtered
local _t11
_t11=$(printf 'Here is the command:\nls -la\nThis lists all files.\n')
assert_eq "commentary without fences filtered" \
  "ls -la" \
  "$(_tc "$_t11")"

# 12. All commentary — falls back to full text
assert_eq "all-commentary fallback" \
  "Here is the answer." \
  "$(_tc 'Here is the answer.')"

# 13. Empty input
assert_eq "empty input" "" "$(_tc '')"

# 14. Whitespace-only input
assert_eq "whitespace-only input" "" "$(printf '   \n  \n' | _zaic_clean_command)"

# 15. Multi-line command inside fence gets flattened
local _t15
_t15=$(cat <<'FENCE'
```bash
find . -name '*.txt' \
  -exec grep -l 'foo' {} +
```
FENCE
)
assert_eq "multi-line fence flattened" \
  "find . -name '*.txt' \\ -exec grep -l 'foo' {} +" \
  "$(_tc "$_t15")"

# 16. Command with backticks (not fences — single inline backtick)
assert_eq "inline backtick whoami preserved" \
  'echo `whoami`' \
  "$(print -r -- 'echo `whoami`' | _zaic_clean_command)"

# 17. Command with special chars
assert_eq "special chars preserved" \
  "awk '{print \$1}' file.txt" \
  "$(_tc "awk '{print \$1}' file.txt")"
