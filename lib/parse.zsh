#!/usr/bin/zsh

# ── _zaic_clean_command ──────────────────────────────────────────
# Reads raw LLM text from stdin, outputs a clean single-line command.
#
# Three-stage pipeline:
#   1. Fence extraction — if fenced block found, extract its content
#   2. Commentary heuristic — remove lines starting with common English starters
#   3. Flatten — join lines, normalize whitespace
# ─────────────────────────────────────────────────────────────────

_zaic_clean_command() {
  local raw
  raw="$(cat)"

  # Empty / whitespace-only input
  if [[ -z "${${raw//[[:space:]]/}}" ]]; then
    return 0
  fi

  local cleaned

  # Stage 1: Fence extraction
  if print -r -- "$raw" | grep -q '```'; then
    # Extract content inside the first fenced block
    # Handles ```bash, ```zsh, ```sh, ```shell, bare ```
    cleaned="$(print -r -- "$raw" | sed -nE '/^[[:space:]]*```(bash|zsh|sh|shell)?[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/{
      /^[[:space:]]*```/d
      p
    }')"

    # If sed extraction got nothing (malformed fences), fall through to stage 2
    if [[ -n "$cleaned" ]]; then
      # Stage 3: Flatten
      print -r -- "$cleaned" \
        | tr '\n' ' ' \
        | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
      return 0
    fi
  fi

  # Stage 2: Commentary heuristic (no-fence fallback)
  cleaned="$(print -r -- "$raw" \
    | grep -vE '^[[:space:]]*(Here|This|You|Note|Sure|I |The |To |It |If |For |Or |As |By |In |An |A |Of )')"

  # If filtering emptied everything, use full text
  if [[ -z "$cleaned" ]]; then
    cleaned="$raw"
  fi

  # Stage 3: Flatten
  print -r -- "$cleaned" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}
