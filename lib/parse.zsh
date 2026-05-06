#!/usr/bin/zsh

# ── _zaic_clean_command ──────────────────────────────────────────
# Reads raw LLM text from stdin, outputs a clean single-line command.
#
# Pipeline:
#   1. Fence extraction — first ```...``` block only. Accepts any alnum
#      info string (bash, zsh, console, shell-session, etc.) or none.
#   2. Commentary heuristic — drop lines starting with common English
#      starters (Here, This, You, ...).
#   3. Flatten — strip shell line-continuations, join lines into one
#      logical line preserving internal whitespace, strip stray boundary
#      fence markers.
# ─────────────────────────────────────────────────────────────────

_zaic_clean_command() {
  local raw cleaned
  raw="$(cat)"

  [[ -z "${${raw//[[:space:]]/}}" ]] && return 0

  # Stage 1: paired fence extraction (first block only).
  if print -r -- "$raw" | grep -q '```'; then
    cleaned="$(print -r -- "$raw" | awk '
      /^[[:space:]]*```[[:alnum:]_-]*[[:space:]]*$/ {
        if (state == 0) { state = 1; next }
        if (state == 1) { state = 2; next }
        next
      }
      state == 1 { print }
    ')"
    if [[ -n "$cleaned" ]]; then
      _zaic_flatten "$cleaned"
      return 0
    fi
    # Unpaired/malformed fence — fall through; stage 3 will strip
    # any leftover boundary markers (with or without info string).
  fi

  # Stage 2: commentary heuristic (no fence found, or extraction failed).
  cleaned="$(print -r -- "$raw" \
    | grep -vE '^[[:space:]]*(Here|This|You|Note|Sure|I |The |To |It |If |For |Or |As |By |In |An |A |Of )')"

  [[ -z "$cleaned" ]] && cleaned="$raw"

  _zaic_flatten "$cleaned"
}

# Join multi-line text into a single command line.
# - Removes shell line-continuations: `\<newline><indent>` → single space
#   (per POSIX shell rules — the backslash and newline are consumed).
# - Per-line strips leading/trailing whitespace and joins with one space.
#   This collapses fence/continuation indentation without touching the
#   command's internal whitespace (so `sed 's/\t/  /g'` survives).
# - Skips empty lines.
# - Strips any unpaired ``` markers (with optional info string) at the
#   start or end of the joined result.
_zaic_flatten() {
  print -r -- "$1" \
    | awk '
        { raw = (NR == 1 ? $0 : raw "\n" $0) }
        END {
          n = split(raw, lines, "\n")
          for (i = 1; i <= n; i++) {
            line = lines[i]
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            # Backslash-parity-aware line continuation: an odd-count run
            # of trailing backslashes means the last one is a continuation
            # marker (the rest pair up as literal `\`). Strip it and any
            # whitespace exposed. An even-count run is all literal — keep.
            if (i < n) {
              bs = 0
              j = length(line)
              while (j > 0 && substr(line, j, 1) == "\\") { bs++; j-- }
              if (bs % 2 == 1) {
                line = substr(line, 1, length(line) - 1)
                sub(/[[:space:]]+$/, "", line)
              }
            }
            if (line == "") continue
            out = out (out == "" ? "" : " ") line
          }
          print out
        }
      ' \
    | sed -E 's/^[[:space:]]*```[[:space:]]*//; s/[[:space:]]*```[[:space:]]*$//; s/^[[:space:]]+//; s/[[:space:]]+$//'
}
