#!/usr/bin/env bash
# handoff.sh - compatibility shim for the /handoff -> /pass rename (2026-11-02).
#
# Sessions started before the rename still follow the old rule: "run
# handoff.sh status; if it reports on, run /handoff". This shim forwards every
# call to ../pass/pass.sh, maps on->auto and off->manual, and rewrites the
# status output back (auto->on, manual->off) so those sessions keep working.
# Removed next release.
set -u

src="$(readlink -f "${BASH_SOURCE[0]}")"
dir="$(dirname "$src")"
target="$dir/../pass/pass.sh"

if [ ! -f "$target" ]; then
  echo "handoff: /pass is not installed" >&2
  exit 1
fi

cmd="${1:-}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
  on) cmd=auto ;;
  off) cmd=manual ;;
esac

if [ "$cmd" = status ]; then
  out="$(bash "$target" status "$@")"
  rc=$?
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sed -E 's/^auto( |$)/on\1/; s/^manual( |$)/off\1/'
  fi
  exit "$rc"
fi

exec bash "$target" "$cmd" "$@"
