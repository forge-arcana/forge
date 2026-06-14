#!/usr/bin/env bash
# lean.sh — Tool-neutral output compressor (Tier 1 of the token-burn levers)
#
# The technique stolen from rtk (Apache-2.0), reimplemented as ~format-agnostic
# bash so forge owns it outright: no binary, no supply chain, no review gate,
# no drift. Strips ANSI, collapses duplicate lines, caps line width, and elides
# the middle of long output — none of which parses any command's format, so it
# never rots. Command-aware (Tier 2) filters can be layered on top later.
#
# TWO WAYS TO USE IT:
#   1. Filter stdin:     some-noisy-command | lean.sh
#   2. Wrap a command:   lean.sh -- some-noisy-command --args   (exit code preserved)
#   3. Source it:        source lean.sh   then call lean_filter / _dedup / etc.
#
# OPTIONS (filter + wrap modes):
#   -w N        cap each line to N chars (default 200; 0 disables)
#   -l H:T      keep first H + last T lines, elide the middle (default off)
#   -p PREFIX   strip PREFIX/ from every line (e.g. an absolute project path)
#   --no-dedup  do not collapse consecutive duplicate lines
#
# Portable: bash >=3.2, awk, sed. No external deps.
set -euo pipefail

# --- Primitive filters (all read stdin, write stdout) ---

# Remove ANSI/VT100 escape sequences (colour, cursor moves).
_strip_ansi() {
  sed -E $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g; s/\x1b\\][^\x07]*\x07//g'
}

# Collapse runs of identical consecutive lines into one, annotated "[×N]".
# This is where most real savings live: repeated warnings, progress spam, etc.
_dedup() {
  awk '
    NR==1 { prev=$0; c=1; next }
    $0==prev { c++; next }
    { if (c>1) printf "%s  [×%d]\n", prev, c; else print prev; prev=$0; c=1 }
    END { if (NR>0) { if (c>1) printf "%s  [×%d]\n", prev, c; else print prev } }
  '
}

# Cap each line to W chars, marking truncation with an ellipsis. W=0 disables.
_trunc_width() {
  local w="${1:-200}"
  [[ "$w" -le 0 ]] && { cat; return; }
  awk -v w="$w" '{ if (length($0) > w) print substr($0, 1, w-1) "…"; else print }'
}

# Keep the first H and last T lines; elide the middle with a count marker.
_trunc_lines() {
  local h="${1:-0}" t="${2:-0}"
  [[ "$h" -le 0 && "$t" -le 0 ]] && { cat; return; }
  awk -v h="$h" -v t="$t" '
    { line[NR]=$0 }
    END {
      if (NR <= h+t) { for (i=1;i<=NR;i++) print line[i] }
      else {
        for (i=1;i<=h;i++) print line[i]
        printf "… [%d lines elided] …\n", NR-h-t
        for (i=NR-t+1;i<=NR;i++) print line[i]
      }
    }
  '
}

# Strip a leading PREFIX/ everywhere it appears (de-noises repeated abs paths).
_strip_prefix() {
  local prefix="$1"
  [[ -z "$prefix" ]] && { cat; return; }
  sed "s|${prefix}/||g"
}

# Compose the default lean pipeline. Args: width prefix dedup(on|off) [h] [t]
lean_filter() {
  local w="${1:-200}" prefix="${2:-}" dedup="${3:-on}" h="${4:-0}" t="${5:-0}"
  local out
  out=$(cat)
  printf '%s\n' "$out" \
    | _strip_ansi \
    | { [[ -n "$prefix" ]] && _strip_prefix "$prefix" || cat; } \
    | { [[ "$dedup" == "on" ]] && _dedup || cat; } \
    | _trunc_lines "$h" "$t" \
    | _trunc_width "$w"
}

# --- CLI entrypoint (only when executed, not when sourced) ---
_lean_main() {
  local w=200 prefix="" dedup="on" h=0 t=0
  local -a cmd=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -w) w="$2"; shift 2 ;;
      -p) prefix="$2"; shift 2 ;;
      -l) h="${2%%:*}"; t="${2##*:}"; shift 2 ;;
      --no-dedup) dedup="off"; shift ;;
      --) shift; cmd=("$@"); break ;;
      *) echo "lean.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
  done

  if [[ ${#cmd[@]} -gt 0 ]]; then
    # Wrap mode: run the command, compress its merged stdout+stderr, but
    # preserve the command's own exit code (toolchain fidelity, like rtk).
    set +e
    "${cmd[@]}" 2>&1 | lean_filter "$w" "$prefix" "$dedup" "$h" "$t"
    local rc=${PIPESTATUS[0]}
    set -e
    return "$rc"
  else
    lean_filter "$w" "$prefix" "$dedup" "$h" "$t"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _lean_main "$@"
fi
