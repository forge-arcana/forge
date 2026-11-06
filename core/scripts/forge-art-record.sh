#!/usr/bin/env bash
#
# forge-art-record.sh <art> [<path>]
#
# Notes that an evaluative art reviewed the repo at its current HEAD. The
# commit gate (core/hooks/arts-gate.sh) reads these records: a multi-file code
# commit is allowed when any record's head= line equals the current HEAD,
# i.e. a review ran since the last commit.
#
#   art   poke | pound | preen | press | probe | temper
#   path  any directory inside the repo (default: cwd)
#
# Writes <git-dir>/forge-arts/<art> atomically. The dir is per worktree
# (`git rev-parse --git-path forge-arts`: .git/forge-arts in the main checkout,
# .git/worktrees/<name>/forge-arts in a linked one), so a review in one
# worktree never overwrites or unlocks another's. Two lines:
#   head=<HEAD sha, or "none" before the first commit>
#   time=<ISO-8601 UTC>
# Silent exit 0 outside a git repo. A failed write prints one warning line on
# stderr and still exits 0. Exit 2 on a bad art. No network, no jq.

set -uo pipefail

usage() { echo "usage: forge-art-record.sh <poke|pound|preen|press|probe|temper> [<path>]" >&2; exit 2; }
warn() { echo "forge-art-record: could not write the $art record ($1); the commit gate will not see this review" >&2; exit 0; }

art="${1:-}"
case "$art" in
  poke|pound|preen|press|probe|temper) ;;
  *) usage ;;
esac

path="${2:-$PWD}"
[ -d "$path" ] || exit 0
[ "$(GIT_OPTIONAL_LOCKS=0 git -C "$path" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0

# Keep in sync with arts_dir() in core/hooks/arts-gate.sh.
dir="$(GIT_OPTIONAL_LOCKS=0 git -C "$path" rev-parse --path-format=absolute --git-path forge-arts 2>/dev/null)"
case "$dir" in
  /*) ;;
  *)
    # Older git without --path-format: the answer is relative to $path.
    dir="$(GIT_OPTIONAL_LOCKS=0 git -C "$path" rev-parse --git-path forge-arts 2>/dev/null)" || exit 0
    [ -n "$dir" ] || exit 0
    case "$dir" in /*) ;; *) dir="$(cd "$path" 2>/dev/null && pwd -P)/$dir" || exit 0 ;; esac
    ;;
esac

head="$(GIT_OPTIONAL_LOCKS=0 git -C "$path" rev-parse -q --verify HEAD 2>/dev/null)"
[ -n "$head" ] || head="none"

[ -e "$dir" ] || mkdir -p "$dir" 2>/dev/null || warn "cannot create $dir"
[ -d "$dir" ] || warn "$dir is not a directory"
# Temp file in the same dir so the mv is an atomic rename; dot-prefixed so
# the gate's glob never reads a half-written record.
tmp="$(mktemp "$dir/.tmp.XXXXXX" 2>/dev/null)" || warn "$dir is not writable"
if printf 'head=%s\ntime=%s\n' "$head" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp" 2>/dev/null \
   && mv -f "$tmp" "$dir/$art" 2>/dev/null; then
  exit 0
fi
rm -f "$tmp" 2>/dev/null
warn "write to $dir failed"
