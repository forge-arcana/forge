#!/usr/bin/env bash
#
# PreToolUse hook — the commit gate. Enforces the forge rule "Builds Go
# Through the Forge Arts" at the one point every build passes through: a
# git commit that carries more than one changed source file is denied unless
# an evaluative art (/poke, /pound, /preen, /press, /probe, /temper) has
# reviewed the repo since its last commit.
#
# Why: a multi-file, security-sensitive change was delegated to ad-hoc
# subagents and committed without any art; a worker had weakened a security
# test and nothing caught it. Rules in prose did not hold; a gate at the
# commit does. It is a nudge, not a lock: records are unauthenticated and
# FORGE_ARTS_SKIP is a visible, deliberate way past it.
#
# Records: each art, on finishing, runs core/scripts/forge-art-record.sh,
# which writes <git-dir>/forge-arts/<art> with a head=<sha> line (sha of HEAD
# at review time, "none" before the first commit). The dir is per worktree
# (git rev-parse --git-path forge-arts), so a review in one worktree never
# unlocks another. The gate allows the commit when ANY record's head= equals
# the current HEAD: a review ran since the last commit. No time window — the
# next commit moves HEAD and expires every record at once.
#
# What counts: source files by extension only (code languages and shell),
# added, copied, modified, or renamed with edits. A pure rename (similarity
# 100, `-M100%`: only exact renames are detected) does not count. Docs, markup, styles, data, config, lockfiles and
# images never count. One source file is always allowed.
#
# Which command is judged: the FIRST simple command of the Bash call. The
# scanner stops at the first top-level |, ||, &&, ;, &, # or newline and
# judges what is left of it, so `git commit ... && git push` and
# `git commit ... 2>&1 | tail` are gated. Anything BEFORE the commit
# (`git add . && git commit`) is not parsed and passes (known, accepted gap).
#
# Why fail open on every uncertain path (WRONG-BLOCK IS WORSE THAN
# WRONG-ALLOW): this hook sees every Bash call in every session on the box.
# Missing jq, malformed or oversized payloads, subshells, command
# substitution outside a heredoc message, repo-redirecting GIT_* env prefixes (GIT_DIR, GIT_CONFIG*, ...),
# --git-dir/--work-tree, explicit pathspecs, interactive, dry-run or
# status-style (--short, --porcelain, ...) commits, a merge/rebase/
# cherry-pick/revert in progress, a path that is not a repo, any git error:
# ALLOW (exit 0, no output). A false deny stops real work fleet-wide; a false
# allow only means the gate missed once.
#
# Commit messages are not parsed as commands: quoted strings are consumed by
# a quote-aware scanner, and the common heredoc message forms
# (-m "$(cat <<'EOF' ... EOF)" and -F - <<'EOF' ... EOF) are collapsed first,
# so a message containing ";", "|" or the word commit neither chains nor
# hides a commit.
#
# Hot path and cost: stdin is read with a bash builtin and the payload is
# checked for the substring "commit" before anything forks. Payloads over
# 64 KB and commands over 8 KB (after heredoc collapse) are allowed unread.
# Every step after that is linear in the command length.
#
# Contract: read JSON on stdin. To allow, exit 0 with empty stdout. To deny,
# exit 0 (NOT 2) and print hookSpecificOutput.permissionDecision="deny" JSON.
# No network.
#
# settings.json matcher: Bash
#
# Escape hatches (both allow):
#   - FORGE_ALLOW_UNGATED_COMMIT set in the hook's environment (session-wide,
#     set before starting the session).
#   - the command itself starts with an env assignment
#     FORGE_ARTS_SKIP=<non-empty reason> (quoted or bare), e.g.
#     FORGE_ARTS_SKIP='docs-only refactor' git commit -m ... — the deliberate,
#     visible, per-commit skip. It is shown in the transcript and must be told
#     to the user. An empty reason is not a skip.
#
# Subagents: calls carrying agent_id are gated EXACTLY like the parent's.
# Unlike tier-guard (whose job is to force delegation, so subagents must pass),
# this gate is about the commit, not who types it: the incident it exists for
# was delegated work committed unreviewed. A subagent that commits multi-file
# code needs an art first, same as anyone.
#
# Check mode: `arts-gate.sh --check <path>` (no stdin) judges the STAGED set
# exactly as the hook judges a plain `git commit` (same helper, gate_check),
# and prints `arts-gate: ok` (exit 0) or `arts-gate: blocked — <reason>`
# (exit 1), plus at most one `arts-gate: note — …` line about untracked
# source files, which never block. Fails open to ok. /wrap runs it right
# after staging.

set -uo pipefail

# --- shared helpers -------------------------------------------------------

g() { GIT_OPTIONAL_LOCKS=0 git "$@"; }

# is_source <path>: 0 when the extension is a code/shell extension.
is_source() {
  local name="${1##*/}" ext
  case "$name" in *.*) ;; *) return 1 ;; esac
  ext="${name##*.}"
  case "${ext,,}" in
    ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|c|h|cc|cpp|hpp|cs|php|sh|bash|zsh|sql|lua|dart|scala|vue|svelte) return 0 ;;
  esac
  return 1
}

# arts_dir <repo-dir>: absolute per-worktree record dir (<git-dir>/forge-arts;
# .git/worktrees/<name>/forge-arts in a linked worktree), or fail.
# Keep in sync with the same resolution in core/scripts/forge-art-record.sh.
arts_dir() {
  local d
  d="$(g -C "$1" rev-parse --path-format=absolute --git-path forge-arts 2>/dev/null)"
  case "$d" in /*) printf '%s' "$d"; return 0 ;; esac
  d="$(g -C "$1" rev-parse --git-path forge-arts 2>/dev/null)" || return 1
  [ -n "$d" ] || return 1
  case "$d" in /*) ;; *) d="$(cd "$1" 2>/dev/null && pwd -P)/$d" || return 1 ;; esac
  printf '%s' "$d"
}

# in_progress <repo-dir>: 0 when a merge/rebase/cherry-pick/revert is under way
# (per-worktree state, so --git-path, not the common dir).
in_progress() {
  local p rel
  for rel in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    p="$(g -C "$1" rev-parse --path-format=absolute --git-path "$rel" 2>/dev/null)" || return 0
    case "$p" in /*) ;; *) p="$1/$p" ;; esac
    [ -e "$p" ] && return 0
  done
  return 1
}

# fresh <arts-dir> <head>: 0 when any art record names this HEAD.
fresh() {
  local f
  for f in "$1"/*; do
    [ -f "$f" ] || continue
    grep -qxF "head=$2" "$f" 2>/dev/null && return 0
  done
  return 1
}

# head_of <repo-dir>: HEAD sha, or "none" before the first commit.
head_of() {
  local h
  h="$(g -C "$1" rev-parse -q --verify HEAD 2>/dev/null)"
  printf '%s' "${h:-none}"
}

# count_source <repo-dir> <diff args...>: source files added, copied,
# modified, or renamed with edits (a pure R100 rename does not count).
count_source() {
  local repo="$1" st p n=0
  shift
  while IFS= read -r -d '' st; do
    case "$st" in
      R*|C*) IFS= read -r -d '' p; IFS= read -r -d '' p
             [ "$st" = "R100" ] && continue ;;
      A|M)   IFS= read -r -d '' p ;;
      *)     IFS= read -r -d '' p; continue ;;
    esac
    is_source "$p" && n=$((n + 1))
  done < <(g -C "$repo" "$@" --no-color --no-ext-diff --name-status -M100% -z --diff-filter=ACMR 2>/dev/null)
  printf '%s' "$n"
}

# reason <repo-dir> <count>
reason() {
  local top name
  top="$(g -C "$1" rev-parse --show-toplevel 2>/dev/null)"
  name="${top##*/}"; [ -n "$name" ] || name="${1##*/}"
  printf "Commit gate: %s has %s changed source files and no review art has run since the last commit. Builds Go Through the Forge Arts: run /poke (code review), plus /pound (security, identity, auth) and /preen (UI) where they apply, then commit. A deliberate skip is FORGE_ARTS_SKIP='<reason>' git commit ... and must be told to the user." "$name" "$2"
}

# gate_check <repo-dir> <all: 0|1>: the one verdict both modes use.
# 0 = allow; 1 = deny with GATE_REASON set. Every uncertain step allows.
GATE_REASON=""
gate_check() {
  local repo="$1" all="$2" arts head n
  [ -d "$repo" ] || return 0
  [ "$(g -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || return 0
  in_progress "$repo" && return 0
  arts="$(arts_dir "$repo")" || return 0
  head="$(head_of "$repo")"
  if [ "$all" = 1 ] && [ "$head" != "none" ]; then
    n="$(count_source "$repo" diff HEAD)"
  else
    n="$(count_source "$repo" diff --cached)"
  fi
  [ "${n:-0}" -le 1 ] && return 0
  fresh "$arts" "$head" && return 0
  GATE_REASON="$(reason "$repo" "$n")"
  return 1
}

# --- check mode -----------------------------------------------------------

if [ "${1:-}" = "--check" ]; then
  exec 2>/dev/null
  [ -n "${FORGE_ALLOW_UNGATED_COMMIT:-}" ] && { echo "arts-gate: ok"; exit 0; }
  command -v git >/dev/null 2>&1 || { echo "arts-gate: ok"; exit 0; }
  repo="${2:-$PWD}"
  rc=0
  if gate_check "$repo" 0; then
    echo "arts-gate: ok"
  else
    echo "arts-gate: blocked — $GATE_REASON"
    rc=1
  fi
  u=0
  if [ -d "$repo" ]; then
    while IFS= read -r -d '' f; do
      is_source "$f" && u=$((u + 1))
    done < <(g -C "$repo" ls-files --others --exclude-standard -z 2>/dev/null)
  fi
  [ "$u" -gt 0 ] && echo "arts-gate: note — $u untracked source file(s) not staged; not judged"
  exit "$rc"
fi

# --- hook mode: hot path --------------------------------------------------

# The builtin read never forks but reads a pipe byte by byte, so it stops one
# past the 64 KB cap: an oversized payload is allowed without being read whole.
payload=""
IFS= read -r -d '' -n 65537 payload || true
[ "${#payload}" -le 65536 ] || exit 0
case "$payload" in
  *commit*) ;;
  *) exit 0 ;;
esac
exec 2>/dev/null
[ -n "${FORGE_ALLOW_UNGATED_COMMIT:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

meta="$(printf '%s' "$payload" | jq -r '"\(.tool_name // "")\t\(.cwd // "")"' 2>/dev/null)" || exit 0
tool_name="${meta%%$'\t'*}"; cwd="${meta#*$'\t'}"
[ "$tool_name" = "Bash" ] || exit 0
[ -n "$cwd" ] || exit 0
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command | if type == "string" then . else "" end' 2>/dev/null)" || exit 0

# Byte semantics from here: parameter expansions stay linear and locale-proof.
LC_ALL=C

# Leading whitespace/newlines off in one expansion.
lead="${cmd%%[![:space:]]*}"; cmd="${cmd:${#lead}}"
case "$cmd" in *commit*) ;; *) exit 0 ;; esac
# The first simple command must be git: it shows up early or not at all.
case "${cmd:0:4096}" in *git*) ;; *) exit 0 ;; esac

# --- collapse the first heredoc (linear: %% expansions only) --------------
# Forms: -m "$(cat <<'EOF' ... EOF\n)"  →  -m MSG
#        <<'EOF' rest-of-line \n ... \nEOF  →  rest-of-line (stdin body dropped)
# Anything unexpected leaves the command unchanged (the scanner then sees the
# raw << and fails open).
collapse_heredoc() {
  local pre post line body before after s d r
  case "$cmd" in *'<<'*) ;; *) return 0 ;; esac
  pre="${cmd%%<<*}"; post="${cmd:${#pre}+2}"
  case "$post" in '<'*) return 0 ;; esac                    # <<< here-string
  line="${post%%$'\n'*}"
  [ "${#line}" -lt "${#post}" ] || return 0                 # no body
  body="${post:${#line}+1}"
  [[ "${line:0:256}" =~ ^-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_-]*)[\'\"]? ]] || return 0
  d="${BASH_REMATCH[1]}"; r="${line:${#BASH_REMATCH[0]}}"
  s=$'\n'"$body"
  before="${s%%$'\n'"$d"*}"
  [ "${#before}" -lt "${#s}" ] || return 0                  # no terminator
  after="${s:${#before}+1+${#d}}"
  case "$after" in ''|$'\n'*|')'*|[[:blank:]]*) ;; *) return 0 ;; esac
  local base=""
  case "$pre" in
    *'"$(cat') base="${pre%\"\$(cat}" ;;
    *'"$(cat ') base="${pre%\"\$(cat }" ;;
  esac
  if [ -n "$base" ]; then
    local lw="${after%%[![:space:]]*}"
    after="${after:${#lw}}"
    case "$after" in ')"'*) ;; *) return 0 ;; esac
    cmd="${base}MSG${after:2}"
  else
    cmd="$pre$r$after"
  fi
}
collapse_heredoc
[ "${#cmd}" -le 8192 ] || exit 0

# --- quote-aware scan of the first simple command into words --------------
# Runs of ordinary characters are consumed in one expansion each; `$` is
# ordinary (a `$(` inside a run fails open). Each step still costs O(length),
# so the step budget bounds the worst case: a real commit line takes a few
# dozen steps; a token flood fails open.
TOP_SPECIAL='[[:space:]'\''"\\`;|&()#]'
DQ_SPECIAL='["\\`]'
NONBLANK=$'[! \t]'
words=(); cur=""; inword=0; state=0; rest="$cmd"; steps=0
while [ -n "$rest" ]; do
  steps=$((steps + 1)); [ "$steps" -le 400 ] || exit 0
  if [ "$state" = 1 ]; then                       # single quotes: to the next '
    seg="${rest%%\'*}"
    [ "${#seg}" -lt "${#rest}" ] || exit 0        # unterminated
    cur+="$seg"; rest="${rest:${#seg}+1}"; state=0
    continue
  fi
  if [ "$state" = 2 ]; then                       # double quotes
    chunk="${rest%%$DQ_SPECIAL*}"
    case "$chunk" in *'$('*) exit 0 ;; esac       # command substitution
    cur+="$chunk"; rest="${rest:${#chunk}}"
    [ -n "$rest" ] || exit 0                      # unterminated
    c="${rest:0:1}"; nx="${rest:1:1}"
    case "$c" in
      '"') state=0; rest="${rest:1}" ;;
      '\') case "$nx" in
             '$'|'`'|'"'|'\') cur+="$nx"; rest="${rest:2}" ;;
             $'\n') rest="${rest:2}" ;;
             *) cur+="$c"; rest="${rest:1}" ;;
           esac ;;
      '`') exit 0 ;;
    esac
    continue
  fi
  chunk="${rest%%$TOP_SPECIAL*}"                  # top level
  if [ -n "$chunk" ]; then
    case "$chunk" in *'$') [ "${rest:${#chunk}:1}" = "(" ] && exit 0 ;; esac
    cur+="$chunk"; inword=1; rest="${rest:${#chunk}}"
    continue
  fi
  c="${rest:0:1}"; nx="${rest:1:1}"
  case "$c" in
    $'\n'|';'|'|') break ;;                       # end of the first command
    '&') case "$cur" in
           *'>') ;;                               # >&N redirect
           *) [ "$nx" = ">" ] || break ;;         # && or & ends it; &> is a redirect
         esac
         cur+="$c"; inword=1; rest="${rest:1}" ;;
    '#') if [ "$inword" = 1 ]; then cur+="$c"; rest="${rest:1}"; else break; fi ;;
    '`'|'('|')') exit 0 ;;
    ' '|$'\t')
      if [ "$inword" = 1 ]; then words+=("$cur"); cur=""; inword=0; fi
      blank="${rest%%$NONBLANK*}"; rest="${rest:${#blank}}" ;;
    [[:space:]])
      if [ "$inword" = 1 ]; then words+=("$cur"); cur=""; inword=0; fi
      rest="${rest:1}" ;;
    "'") state=1; inword=1; rest="${rest:1}" ;;
    '"') state=2; inword=1; rest="${rest:1}" ;;
    '\') if [ "$nx" = $'\n' ]; then rest="${rest:2}"   # line continuation
         else cur+="$nx"; inword=1; rest="${rest:2}"; fi ;;
    *) exit 0 ;;                                  # unreachable; fail open
  esac
done
[ "$state" = 0 ] || exit 0
[ "$inword" = 1 ] && words+=("$cur")
nw=${#words[@]}
[ "$nw" -gt 0 ] || exit 0

# --- env assignments and wrappers, then git -------------------------------

k=0; skip=""
while [ "$k" -lt "$nw" ]; do
  w="${words[k]}"
  case "$w" in
    env)
      k=$((k + 1)); case "${words[k]:-}" in -*) exit 0 ;; esac; continue ;;
    command)
      k=$((k + 1)); case "${words[k]:-}" in -*) exit 0 ;; esac; continue ;;
    time)
      k=$((k + 1)); while [[ "${words[k]:-}" == -* ]]; do k=$((k + 1)); done; continue ;;
    nice)
      k=$((k + 1))
      case "${words[k]:-}" in
        -n) k=$((k + 2)) ;;
        -[0-9]*|--adjustment=*|-n[0-9]*) k=$((k + 1)) ;;
        -*) exit 0 ;;
      esac
      continue ;;
    timeout)
      k=$((k + 1))
      [[ "${words[k]:-}" =~ ^[0-9]+(\.[0-9]+)?[smhd]?$ ]] || exit 0
      k=$((k + 1)); continue ;;
  esac
  if [[ "$w" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
    case "${w%%=*}" in
      GIT_DIR|GIT_WORK_TREE|GIT_INDEX_FILE|GIT_COMMON_DIR|GIT_OBJECT_DIRECTORY|GIT_NAMESPACE|GIT_CEILING_DIRECTORIES|GIT_DISCOVERY_ACROSS_FILESYSTEM|GIT_ALTERNATE_OBJECT_DIRECTORIES|GIT_CONFIG*)
        exit 0 ;;                                 # repo/index/config redirected
      FORGE_ARTS_SKIP) skip="${w#*=}" ;;
    esac
    k=$((k + 1)); continue
  fi
  break
done
[ "$k" -lt "$nw" ] || exit 0
[ "${words[k]##*/}" = "git" ] || exit 0
k=$((k + 1))

# Git global options before the subcommand.
cpaths=()
sub=""
while [ "$k" -lt "$nw" ]; do
  w="${words[k]}"
  case "$w" in
    -C) k=$((k + 1)); [ "$k" -lt "$nw" ] || exit 0; cpaths+=("${words[k]}") ;;
    -c|--namespace|--config-env|--super-prefix|--exec-path) k=$((k + 1)) ;;
    --git-dir|--git-dir=*|--work-tree|--work-tree=*) exit 0 ;;
    -h|--help|-v|--version) exit 0 ;;
    -*) ;;
    *) sub="$w"; k=$((k + 1)); break ;;
  esac
  k=$((k + 1))
done
[ "$sub" = "commit" ] || exit 0

# Deliberate skip: a non-empty FORGE_ARTS_SKIP reason on this commit.
[ -n "$skip" ] && exit 0

# --- commit arguments -----------------------------------------------------

all=0
while [ "$k" -lt "$nw" ]; do
  w="${words[k]}"
  case "$w" in
    --) [ $((k + 1)) -lt "$nw" ] && exit 0 ;;          # pathspecs follow
    --all) all=1 ;;
    --dry-run|--interactive|--patch|--include|--only|--pathspec-from-file|--pathspec-from-file=*) exit 0 ;;
    # status-style output: these never create a commit (with abbreviations)
    --sh|--sho|--shor|--short|--po|--por|--porc*|--l|--lo|--lon|--long|--nu|--nul|--null|--he|--hel|--help) exit 0 ;;
    --message|--file|--reuse-message|--reedit-message|--template|--author|--date|--fixup|--squash|--cleanup|--trailer)
      k=$((k + 1)) ;;
    --*) ;;                                              # flag or --opt=value
    \<*) exit 0 ;;                                       # input redirection
    [0-9]\>*|[0-9][0-9]\>*|\>*|\&\>*)                    # output redirection
      case "$w" in
        *\>|*\>\>) k=$((k + 1)) ;;                       # target is the next word
      esac ;;
    -?*)
      j=1; L=${#w}
      [ "$L" -le 64 ] || exit 0                          # absurd flag word: fail open
      while [ "$j" -lt "$L" ]; do
        ch="${w:j:1}"
        case "$ch" in
          a) all=1 ;;
          i|o|p|z|h) exit 0 ;;
          m|F|C|c|t) [ $((j + 1)) -ge "$L" ] && k=$((k + 1)); break ;;
          S|u) break ;;                                  # optional attached arg
        esac
        j=$((j + 1))
      done ;;
    *) exit 0 ;;                                         # explicit pathspec
  esac
  k=$((k + 1))
done

# --- repo -------------------------------------------------------------------

repo="$cwd"
for p in "${cpaths[@]+"${cpaths[@]}"}"; do
  case "$p" in
    "~"|"~/"*|'$HOME'|'$HOME/'*|'${HOME}'|'${HOME}/'*)
      [ -n "${HOME:-}" ] || exit 0 ;;                   # needs HOME and it is empty: fail open
  esac
  case "$p" in
    "~"|'$HOME'|'${HOME}') p="${HOME:-}" ;;
    "~/"*)       p="${HOME:-}/${p#\~/}" ;;
    '$HOME/'*)   p="${HOME:-}/${p#\$HOME/}" ;;
    '${HOME}/'*) p="${HOME:-}/${p#\$\{HOME\}/}" ;;
    '$PWD'|'${PWD}') p="$cwd" ;;
    '$PWD/'*)    p="$cwd/${p#\$PWD/}" ;;
    '${PWD}/'*)  p="$cwd/${p#\$\{PWD\}/}" ;;
  esac
  case "$p" in *'$'*) exit 0 ;; esac                    # other expansions: unknown
  case "$p" in /*) repo="$p" ;; *) repo="$repo/$p" ;; esac
done

gate_check "$repo" "$all" && exit 0
jq -n --arg reason "$GATE_REASON" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
exit 0
