#!/usr/bin/env bash
# web-cache.sh — Shared web-research cache for the evaluative arts
#
# Implements the Forge Protocol "Web Research Cache" contract
# (core/skills/forge/protocol.md#web-research-cache) as a deterministic
# script so no art re-derives key normalization or TTL arithmetic in-context.
#
# Cache file: <project>/memory/.web-cache.json
#   { "queries": { "<key>": { query, summary, sources[], cached_at, ttl_days } } }
#
# USAGE:
#   web-cache.sh get "<raw query>" [--project <path>]
#       HIT     → prints the entry JSON {query, summary, sources, cached_at, ttl_days}, exit 0
#       MISS    → prints "MISS <key>",    exit 1
#       EXPIRED → prints "EXPIRED <key>", exit 1  (caller re-searches and puts)
#   web-cache.sh put "<raw query>" --summary "<text>" [--source <url>]... \
#                    [--ttl <days>] [--project <path>]
#       Writes/overwrites the entry (cached_at = now, ttl default 30). Prints the key.
#   web-cache.sh key "<raw query>"
#       Prints the normalized cache key only.
#
# Key normalization (per protocol): lowercase, strip 4-digit years, spaces → hyphens.
#   "Drizzle ORM best practices 2025" → drizzle-orm-best-practices
#
# Requires: jq. bash >=3.2.
set -euo pipefail

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required for web-cache.sh." >&2; exit 1; }

[[ $# -ge 2 ]] || usage
CMD="$1"; RAW="$2"; shift 2

PROJECT="."
TTL=30
SUMMARY=""
declare -a SOURCES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?--project needs a path}"; shift 2 ;;
    --ttl)     TTL="${2:?--ttl needs a number}"; shift 2 ;;
    --summary) SUMMARY="${2:?--summary needs text}"; shift 2 ;;
    --source)  SOURCES+=("${2:?--source needs a url}"); shift 2 ;;
    *)         echo "web-cache.sh: unknown option '$1'" >&2; usage ;;
  esac
done

normalize_key() {
  # lowercase → drop 4-digit years → non-alphanumerics to hyphens → squeeze/trim hyphens
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/\b(19|20)[0-9]{2}\b//g; s/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//'
}

KEY=$(normalize_key "$RAW")
[[ -n "$KEY" ]] || { echo "ERROR: query normalized to empty key." >&2; exit 2; }
CACHE="$PROJECT/memory/.web-cache.json"

read_cache() {
  # Corrupt or absent file degrades to an empty cache rather than erroring.
  if [[ -f "$CACHE" ]] && jq -e . "$CACHE" >/dev/null 2>&1; then
    cat "$CACHE"
  else
    echo '{"queries":{}}'
  fi
}

case "$CMD" in
  key)
    echo "$KEY"
    ;;

  get)
    STATE=$(read_cache | jq -r --arg k "$KEY" '
      .queries[$k] as $e
      | if $e == null then "MISS"
        elif (($e.cached_at | fromdateiso8601) + (($e.ttl_days // 30) * 86400)) > now then "HIT"
        else "EXPIRED"
        end')
    case "$STATE" in
      HIT)     read_cache | jq --arg k "$KEY" '.queries[$k]' ;;
      MISS)    echo "MISS $KEY";    exit 1 ;;
      EXPIRED) echo "EXPIRED $KEY"; exit 1 ;;
    esac
    ;;

  put)
    [[ -n "$SUMMARY" ]] || { echo "ERROR: put requires --summary." >&2; exit 2; }
    mkdir -p "$PROJECT/memory"
    SRC_JSON=$(printf '%s\n' "${SOURCES[@]+"${SOURCES[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')
    TMP=$(mktemp "${TMPDIR:-/tmp}/web-cache.XXXXXX")
    read_cache | jq --arg k "$KEY" --arg q "$RAW" --arg s "$SUMMARY" \
                    --argjson src "$SRC_JSON" --argjson ttl "$TTL" '
      .queries[$k] = {
        query: $q, summary: $s, sources: $src,
        cached_at: (now | todateiso8601), ttl_days: $ttl
      }' > "$TMP"
    mv "$TMP" "$CACHE"
    echo "$KEY"
    ;;

  *) usage ;;
esac
