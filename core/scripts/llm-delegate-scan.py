#!/usr/bin/env python3
"""llm-delegate-scan: is delegating code generation to the local helper saving
or burning assistant-plan tokens?

Reads (read-only) the helper call ledger and the session transcripts, writes one
JSON row per Europe/London day plus a 14-day verdict.

Inputs
  ledger      ${FORGE_LLM_LEDGER:-${XDG_STATE_HOME:-$HOME/.local/state}/forge/llm-delegate/calls.jsonl}
              ("off" reads no ledger)
  transcripts ${FORGE_MEMBRANE:-$HOME/.claude}/projects/**/*.jsonl (recursive);
              a missing projects directory is an error (exit 2), not "no usage"
Output
  <state dir>/daily/YYYY-MM-DD.json (mode 600, atomic replace), or --json / text.
  State dir: --state-dir, else the ledger file's directory, else
  ${XDG_STATE_HOME:-$HOME/.local/state}/forge/llm-delegate. Never relative to cwd.
  A rerun that finds fewer attributed calls than the good file already on disk
  keeps the file (say so on stderr) unless --force is given.

Method and limits (all numbers are PROXIES, in plan OUTPUT-token units)
  The thresholds are the constants at the top of this file; METHOD, written into
  every daily file, is built from them.
  1. A helper call is an assistant shell tool_use whose command EXECUTES
     llm-delegate.sh (command word, after bash/sh/env VAR=/testgate --/timeout/
     pipe/subshell/command substitution). Commands that only read, search or
     syntax-check (bash -n) it do not count. It is paired with its tool_result by
     tool_use id.
  2. Each call joins one ledger line, one-to-one: first same session id inside the
     call window +-JOIN_SLACK, then, for what is left, the nearest ledger ts to
     the call start inside the window whatever the session (subagent calls can
     carry another id). Unmatched ledger lines are "unattributed" (cron/manual);
     they count as calls but carry no wrap/saved/redo. A call with no ledger line
     is counted once from transcript evidence (exit and local tokens parsed from
     the result: "[exited with code N]", helper stderr, and the "[N tokens, Xs,
     Y tok/s, model: M]" stat line); when it starts after the ledger's first
     line it is also flagged and summed in numbers.join_misses.
  3. wrap_tokens = output_tokens of the issuing assistant turn split evenly
     across that turn's tool_use blocks + ceil(result chars / 4). It ignores
     cached-input re-reads. A turn's output is the max seen across its streamed
     records (records of one message id + requestId are one turn).
  4. class: fallback if exit != 0. Otherwise, over USE_WINDOW after the result:
     used = Write/Edit/NotebookEdit input (or shell heredoc) holds >=USED_FRAC of
     the returned text's lines (stripped, >=MIN_LINE chars), or fewer than
     SHORT_LINES such lines and all present; redone = a Write/Edit happened but
     overlap <REDONE_FRAC; else unknown. Line overlap is exact-match, so
     reformatted code reads as redone. saved_tokens = eval tokens * overlap for
     used calls.
  5. redo_tokens (fallback and redone calls) = output_tokens of the first
     REDO_CAP Write/Edit assistant turns in the next REDO_WINDOW. Each edit turn
     is assigned to at most one call: the nearest preceding fallback or redone
     call whose window holds it. It may count unrelated edits.
  6. Day = Europe/London calendar day of the call start (ledger ts for
     unattributed lines). calls counts transcript calls plus unattributed lines.
  7. Verdict over the trailing TRAIL_DAYS ending on the report date:
     too-little-data (<MIN_CALLS calls), helping (net > 0), else burning.
No transcript text is written anywhere. Python 3 stdlib only.
"""
import argparse
import datetime as dt
import json
import math
import os
import re
import shlex
import sys
import tempfile
from zoneinfo import ZoneInfo

LONDON = ZoneInfo("Europe/London")
HELPER = "llm-delegate.sh"
TRAIL_DAYS = 14        # verdict window, days
MIN_CALLS = 10         # under this many trailing calls the verdict is too-little-data
JOIN_SLACK = 30        # seconds around a call when pairing ledger lines
USE_WINDOW = 1800      # seconds after the result in which edits count as use
REDO_WINDOW = 600      # seconds after the result in which edits count as redo
REDO_CAP = 3           # edit turns summed per call
MIN_LINE = 12          # shortest stripped line that counts for overlap
USED_FRAC = 0.6        # overlap at or above this is "used"
REDONE_FRAC = 0.2      # overlap below this (with an edit) is "redone"
SHORT_LINES = 3        # under this many distinct lines, all must be present
EDIT_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
SHELL_TOOLS = {"Bash"}
METHOD = ("Proxy estimate in plan output-token units. wrap = issuing turn output "
          "split across its tool_use blocks + ceil(result chars/4); saved = local "
          "eval tokens x line overlap of the returned text with Write/Edit input "
          "in the next %d min (used >=%d%%, redone <%d%%; under %d distinct lines "
          "all must be present); redo = output tokens of up to %d Write/Edit turns "
          "in the next %d min after a fallback or redone call, each turn assigned "
          "to the nearest preceding such call. Calls pair with ledger lines within "
          "%d s (same session first, then nearest in time); a call with no ledger "
          "line is counted once from transcript evidence and, when the ledger had "
          "already begun, flagged in join_misses. Ignores cached-input re-reads; "
          "exact-line overlap; redo may include unrelated edits. Day is "
          "Europe/London. Verdict is the trailing %d days: too-little-data under "
          "%d calls, helping if net > 0, else burning."
          % (USE_WINDOW // 60, round(USED_FRAC * 100), round(REDONE_FRAC * 100),
             SHORT_LINES, REDO_CAP, REDO_WINDOW // 60, JOIN_SLACK, TRAIL_DAYS, MIN_CALLS))
NUM_KEYS = ["calls", "ok", "fallback", "truncated", "unattributed", "used",
            "redone", "unknown", "success_rate_pct", "fallback_rate_pct",
            "local_tokens", "local_prompt_tokens", "wrap_tokens", "redo_tokens",
            "saved_tokens", "net_tokens", "local_seconds", "bad_ledger_lines",
            "join_misses", "transcripts_scanned", "skipped_transcripts"]

# ---------------------------------------------------------------- pure helpers

_WRAP_OPTS = {"bash": 1, "sh": 1, "zsh": 1}
_PREFIX_WORDS = {"if", "then", "else", "elif", "do", "while", "until", "!", "{",
                 "time", "nohup", "exec", "command", "sudo", "nice"}
_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
_SEPS = {";", "&&", "||", "|", "&", "|&", "(", ")"}
_HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
_ARITH = re.compile(r"\$\(\(.*?\)\)|(?:^|(?<=[\s;&|(]))\(\(.*?\)\)")
_NOEXEC_FLAGS = re.compile(r"^-[A-Za-z]*n[A-Za-z]*$")
_CMD_FLAGS = re.compile(r"^-[A-Za-z]*c$")
_MAX_NEST = 4


def _strip_heredocs(cmd):
    out, delim = [], None
    for line in cmd.split("\n"):
        if delim is not None:
            if line.strip() == delim:
                delim = None
            continue
        out.append(line)
        m = _HEREDOC.search(_ARITH.sub(" ", line))
        if m:
            delim = m.group(2)
    return "\n".join(out)


def _substitutions(cmd):
    """Inner text of every $(...) and `...` outside single quotes (not $((...)))."""
    out, i, n, q = [], 0, len(cmd), None
    while i < n:
        ch = cmd[i]
        if q == "'":
            if ch == "'":
                q = None
        elif ch == "\\":
            i += 1
        elif q is None and ch in "'\"":
            q = ch
        elif q == '"' and ch == '"':
            q = None
        elif cmd.startswith("$(", i) and not cmd.startswith("$((", i):
            j, depth, iq = i + 2, 1, None
            while j < n:
                c = cmd[j]
                if iq:
                    if c == "\\" and iq == '"':
                        j += 1
                    elif c == iq:
                        iq = None
                elif c == "\\":
                    j += 1
                elif c in "'\"":
                    iq = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            out.append(cmd[i + 2:j])
            i = j
        elif ch == "`":
            j = i + 1
            while j < n and cmd[j] != "`":
                j += 2 if cmd[j] == "\\" else 1
            out.append(cmd[i + 1:j])
            i = j
        i += 1
    return out


def _segments(cmd):
    cmd = cmd.replace("`", " ; ").replace("$(", " ; ")
    cmd = cmd.replace("\n", " ; ")
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        toks = list(lex)
    except ValueError:
        toks = cmd.split()
    segs, cur = [], []
    for t in toks:
        if t in _SEPS or (t and set(t) <= set(";&|()")):
            if cur:
                segs.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def _is_helper_word(w):
    return os.path.basename(w) == HELPER


def _timeout_rest(rest):
    """Words after timeout's own options and its duration."""
    j = 0
    while j < len(rest) and rest[j].startswith("-"):
        if rest[j] == "--":
            j += 1
            break
        j += 2 if rest[j] in ("-s", "-k", "--signal", "--kill-after") else 1
    return rest[j + 1:]


def _seg_executes(words, depth=0):
    i = 0
    while i < len(words):
        w = words[i]
        if _ASSIGN.match(w) or w in _PREFIX_WORDS:
            i += 1
            continue
        break
    if i >= len(words):
        return False
    w = words[i]
    base = os.path.basename(w)
    if _is_helper_word(w):
        return True
    rest = words[i + 1:]
    if base in _WRAP_OPTS:
        j = 0
        while j < len(rest) and rest[j].startswith("-"):
            if _NOEXEC_FLAGS.match(rest[j]):
                return False
            if _CMD_FLAGS.match(rest[j]) and j + 1 < len(rest) and depth < 2:
                return classify_command(rest[j + 1], depth + 1)
            j += 1
        return j < len(rest) and _is_helper_word(rest[j])
    if base == "env":
        j = 0
        while j < len(rest) and (rest[j].startswith("-") or _ASSIGN.match(rest[j])):
            j += 1
        return _seg_executes(rest[j:], depth) if j < len(rest) else False
    if base == "testgate":
        j = 0
        while j < len(rest) and rest[j].startswith("-"):
            j += 1
        return _seg_executes(rest[j:], depth) if j < len(rest) else False
    if base == "timeout":
        tail = _timeout_rest(rest)
        return _seg_executes(tail, depth) if tail else False
    return False


def _classify_stripped(body, depth):
    if depth < _MAX_NEST and any(_classify_stripped(s, depth + 1) for s in _substitutions(body)):
        return True
    return any(_seg_executes(s, depth) for s in _segments(body))


def classify_command(cmd, depth=0):
    """True when the shell command executes llm-delegate.sh (not merely reads it)."""
    if not isinstance(cmd, str) or HELPER not in cmd:
        return False
    return _classify_stripped(_strip_heredocs(cmd), depth)


_STAT = re.compile(r"^\s*\[(\d+) tokens, ([\d.]+)s, [\d.]+ tok/s, model: ([^\]]*)\]\s*$")
_EXIT = re.compile(r"(?:\[exited with code (\d+)\]|^Exit code (\d+))", re.M)


def parse_stat_line(text):
    """-> (eval_tokens, seconds, model) from the helper's stat line, or None."""
    for line in (text or "").splitlines():
        m = _STAT.match(line)
        if m:
            return int(m.group(1)), float(m.group(2)), m.group(3).strip()
    return None


def infer_exit(text, is_error):
    m = _EXIT.search(text or "")
    if m:
        return int(m.group(1) or m.group(2))
    if re.search(r"^llm-delegate\.sh: ", text or "", re.M):
        return 1
    if parse_stat_line(text):
        return 0
    return 1 if is_error else 0


def result_lines(text):
    out = []
    for line in (text or "").splitlines():
        if _STAT.match(line):
            continue
        s = line.strip()
        if len(s) >= MIN_LINE:
            out.append(s)
    return out


def overlap_fraction(helper_lines, edit_sets):
    """Fraction of distinct helper lines present in any edit's line set."""
    want = set(helper_lines)
    if not want:
        return 0.0
    have = set()
    for s in edit_sets:
        have |= want & s
    return len(have) / len(want)


def classify_call(exit_code, helper_lines, frac, wrote):
    if exit_code != 0:
        return "fallback"
    n = len(set(helper_lines))
    if n and ((n < SHORT_LINES and frac >= 1.0) or (n >= SHORT_LINES and frac >= USED_FRAC)):
        return "used"
    if wrote and frac < REDONE_FRAC:
        return "redone"
    return "unknown"


def parse_ts(s):
    if not isinstance(s, str):
        return None
    try:
        d = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d.timestamp()


def london_day(epoch):
    return dt.datetime.fromtimestamp(epoch, LONDON).date()


def verdict(rows, date):
    """rows: {date: numbers}. Trailing TRAIL_DAYS ending on `date` inclusive."""
    calls = net = 0
    for k in range(TRAIL_DAYS):
        r = rows.get(date - dt.timedelta(days=k))
        if r:
            calls += r["calls"]
            net += r["net_tokens"]
    v = "too-little-data" if calls < MIN_CALLS else ("helping" if net > 0 else "burning")
    return {"verdict": v, "trailing_days": TRAIL_DAYS, "trailing_calls": calls,
            "trailing_net_tokens": net}


def _i(v):
    """Tolerant int: anything that is not a plain number reads as 0."""
    if isinstance(v, bool):
        return 0
    try:
        return int(v or 0)
    except (TypeError, ValueError, OverflowError):
        return 0


def _edit_lines(text):
    if not isinstance(text, str):
        return set()
    return {l.strip() for l in text.splitlines() if len(l.strip()) >= MIN_LINE}


def _edit_text(name, inp):
    if not isinstance(inp, dict):
        return ""
    if name == "Write":
        return inp.get("content") or ""
    if name == "Edit":
        return inp.get("new_string") or ""
    if name == "MultiEdit":
        return "\n".join(e.get("new_string") or "" for e in inp.get("edits") or []
                         if isinstance(e, dict) and isinstance(e.get("new_string") or "", str))
    if name == "NotebookEdit":
        return inp.get("new_source") or ""
    return ""


def _result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(c["text"] for c in content
                         if isinstance(c, dict) and isinstance(c.get("text"), str))
    return ""


# ------------------------------------------------------------ transcript scan

def scan_transcript(path, session_default):
    """Stream one transcript. -> list of partial call dicts (no ledger yet)."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        if not any(HELPER in line for line in fh):
            return []
    calls, helper_ids, results = {}, set(), {}
    turns = {}      # turn key -> dict(out, ids:set, edit:bool, ts)
    edits = []      # (ts, lineset, is_tool_edit)
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict):
                continue
            msg = rec.get("message")
            if not isinstance(msg, dict):
                continue
            ts = parse_ts(rec.get("timestamp"))
            sess = rec.get("sessionId") or session_default
            content = msg.get("content")
            if rec.get("type") == "user" and isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_result" \
                            and isinstance(b.get("tool_use_id"), str) \
                            and b["tool_use_id"] in helper_ids:
                        results[b["tool_use_id"]] = (ts, _result_text(b.get("content")),
                                                     bool(b.get("is_error")))
                continue
            if msg.get("role") != "assistant" or ts is None:
                continue
            tk = "%s|%s" % (msg.get("id") or "", rec.get("requestId") or "")
            t = turns.setdefault(tk, {"out": 0, "ids": set(), "edit": False, "ts": ts})
            usage = msg.get("usage")
            if isinstance(usage, dict):
                t["out"] = max(t["out"], _i(usage.get("output_tokens")))
            t["ts"] = min(t["ts"], ts)
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict) or b.get("type") != "tool_use":
                    continue
                tid, name, inp = b.get("id"), b.get("name"), b.get("input")
                if not isinstance(tid, str):
                    continue
                t["ids"].add(tid)
                if name in EDIT_TOOLS:
                    t["edit"] = True
                    edits.append((ts, _edit_lines(_edit_text(name, inp)), True))
                elif name in SHELL_TOOLS and isinstance(inp, dict):
                    cmd = inp.get("command") or ""
                    if classify_command(cmd):
                        if tid not in calls:
                            helper_ids.add(tid)
                            calls[tid] = {"id": tid, "session": sess, "start": ts, "turn": tk}
                    elif isinstance(cmd, str) and "<<" in cmd:
                        edits.append((ts, _edit_lines(cmd), False))
    eturns = sorted((x["ts"], x["out"]) for x in turns.values() if x["edit"])
    out = []
    for tid, c in calls.items():
        r = results.get(tid)
        end = r[0] if r and r[0] else c["start"]
        text = r[1] if r else ""
        t = turns[c["turn"]]
        lines = result_lines(text)
        win = [e for e in edits if end < e[0] <= end + USE_WINDOW]
        frac = overlap_fraction(lines, [e[1] for e in win])
        wrote = any(e[2] for e in win)
        c.update({
            "end": end, "src": path, "eturns": eturns,
            "wrap": int(round(t["out"] / max(len(t["ids"]), 1))) + math.ceil(len(text) / 4),
            "lines": lines, "frac": frac, "wrote": wrote,
            "exit": infer_exit(text, r[2] if r else False),
            "stat": parse_stat_line(text),
        })
        out.append(c)
    return out


def iter_transcripts(root, min_mtime, stats):
    """Yield transcript paths newer than min_mtime; unreadable entries count as skipped."""
    def on_error(_e):
        stats["skipped"] += 1
    for d, _dirs, files in os.walk(root, onerror=on_error):
        for f in files:
            if f.endswith(".jsonl"):
                p = os.path.join(d, f)
                try:
                    if os.stat(p).st_mtime >= min_mtime:
                        yield p
                except OSError:
                    stats["skipped"] += 1


# --------------------------------------------------------------------- ledger

def read_ledger(path, lo, hi):
    """-> (lines in [lo, hi), bad line count, ts of the ledger's first line or None)."""
    lines, bad, first = [], 0, None
    try:
        fh = open(path, "r", encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return lines, bad, first
    with fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except ValueError:
                bad += 1
                continue
            ts = parse_ts(rec.get("ts")) if isinstance(rec, dict) else None
            if ts is None:
                bad += 1
                continue
            if first is None or ts < first:
                first = ts
            if lo <= ts < hi:
                rec["_ts"] = ts
                lines.append(rec)
    return lines, bad, first


def pair_ledger(calls, ledger):
    """One-to-one pairing inside the +-JOIN_SLACK window around each call.
    Pass 1: same session id. Pass 2: whatever is left, nearest ts regardless of
    session. Nearest = closest to the call start (the ledger ts is the helper's
    start). -> ({call index: ledger idx}, unmatched ledger idxs)."""
    pairs, used_l = {}, set()
    for same_session in (True, False):
        cands = []
        for ci, c in enumerate(calls):
            if ci in pairs:
                continue
            for li, l in enumerate(ledger):
                if li in used_l:
                    continue
                if not (c["start"] - JOIN_SLACK <= l["_ts"] <= c["end"] + JOIN_SLACK):
                    continue
                if same_session and not (l.get("session") and l.get("session") == c.get("session")):
                    continue
                cands.append((abs(l["_ts"] - c["start"]), ci, li))
        cands.sort()
        for _d, ci, li in cands:
            if ci in pairs or li in used_l:
                continue
            pairs[ci] = li
            used_l.add(li)
    return pairs, [i for i in range(len(ledger)) if i not in used_l]


def finalize(call, led):
    """-> per-call record for aggregation (redo is assigned later)."""
    stat = call.get("stat")
    if led is not None:
        ex = _i(led.get("exit"))
        ev, pt = _i(led.get("eval_tokens")), _i(led.get("prompt_tokens"))
        secs = _i(led.get("wall_ms")) / 1000.0
        model, outcome = led.get("model"), led.get("outcome")
    else:
        ex = call["exit"]
        ev = stat[0] if stat else 0
        pt = 0
        secs = stat[1] if stat else 0.0
        model, outcome = (stat[2] if stat else None), None
    cls = classify_call(ex, call["lines"], call["frac"], call["wrote"])
    return {
        "day": london_day(call["start"]), "ok": ex == 0, "class": cls,
        "truncated": outcome == "truncated", "unattributed": False, "join_miss": False,
        "local": ev, "prompt": pt, "secs": secs, "model": model,
        "wrap": call["wrap"], "redo": 0,
        "saved": int(round(ev * call["frac"])) if cls == "used" else 0,
    }


def finalize_unattributed(led):
    return {
        "day": london_day(led["_ts"]), "ok": _i(led.get("exit")) == 0, "class": None,
        "truncated": led.get("outcome") == "truncated", "unattributed": True, "join_miss": False,
        "local": _i(led.get("eval_tokens")), "prompt": _i(led.get("prompt_tokens")),
        "secs": _i(led.get("wall_ms")) / 1000.0, "model": led.get("model"),
        "wrap": 0, "redo": 0, "saved": 0,
    }


def assign_redo(calls, recs):
    """Give each edit turn to at most one call: the nearest preceding fallback or
    redone call (same transcript) whose REDO_WINDOW holds it; REDO_CAP turns each."""
    groups = {}
    for c, r in zip(calls, recs):
        if r["class"] in ("fallback", "redone"):
            groups.setdefault(c["src"], []).append((c, r))
    for members in groups.values():
        members.sort(key=lambda m: m[0]["end"])
        got = {id(r): [] for _c, r in members}
        for ts, out in members[0][0]["eturns"]:
            owner = None
            for c, r in members:
                if c["end"] < ts <= c["end"] + REDO_WINDOW:
                    owner = r
                elif c["end"] >= ts:
                    break
            if owner is not None:
                got[id(owner)].append(out)
        for _c, r in members:
            r["redo"] = sum(got[id(r)][:REDO_CAP])


def aggregate(recs, bad):
    n = {k: 0 for k in NUM_KEYS}
    secs, models = 0.0, {}
    for r in recs:
        n["calls"] += 1
        n["ok"] += r["ok"]
        n["fallback"] += (not r["ok"])
        n["truncated"] += r["truncated"]
        n["unattributed"] += r["unattributed"]
        n["join_misses"] += r["join_miss"]
        if r["class"] in ("used", "redone", "unknown"):
            n[r["class"]] += 1
        n["local_tokens"] += r["local"]
        n["local_prompt_tokens"] += r["prompt"]
        n["wrap_tokens"] += r["wrap"]
        n["redo_tokens"] += r["redo"]
        n["saved_tokens"] += r["saved"]
        secs += r["secs"]
        if r["model"]:
            models[r["model"]] = models.get(r["model"], 0) + 1
    n["net_tokens"] = n["saved_tokens"] - n["wrap_tokens"] - n["redo_tokens"]
    if n["calls"]:
        n["success_rate_pct"] = round(100.0 * n["ok"] / n["calls"], 1)
        n["fallback_rate_pct"] = round(100.0 * n["fallback"] / n["calls"], 1)
    n["local_seconds"] = int(round(secs))
    n["bad_ledger_lines"] = bad
    return n, models


# ------------------------------------------------------------------- plumbing

def ledger_path():
    """The ledger file, or None when FORGE_LLM_LEDGER=off."""
    p = os.environ.get("FORGE_LLM_LEDGER")
    if p == "off":
        return None
    if p:
        return p
    return os.path.join(_default_state_dir(), "calls.jsonl")


def _default_state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local/state")
    return os.path.join(base, "forge/llm-delegate")


def day_start(d):
    return dt.datetime(d.year, d.month, d.day, tzinfo=LONDON).timestamp()


def build_docs(dates, ledger_file, membrane, now):
    first, last = min(dates), max(dates)
    all_days = [first - dt.timedelta(days=TRAIL_DAYS - 1) + dt.timedelta(days=i)
                for i in range((last - first).days + TRAIL_DAYS)]
    lo = day_start(all_days[0])
    hi = day_start(last + dt.timedelta(days=1))
    if ledger_file:
        ledger, bad, first_ts = read_ledger(ledger_file, lo, hi)
    else:
        ledger, bad, first_ts = [], 0, None
    stats = {"scanned": 0, "skipped": 0}
    calls, seen_ids = [], set()
    root = os.path.join(membrane, "projects")
    for p in sorted(iter_transcripts(root, lo - 86400, stats)):
        stem = os.path.splitext(os.path.basename(p))[0]
        try:
            found = scan_transcript(p, stem)
        except OSError:
            stats["skipped"] += 1
            continue
        stats["scanned"] += 1
        for c in found:
            if c["id"] in seen_ids or not (lo <= c["start"] < hi):
                continue
            seen_ids.add(c["id"])
            calls.append(c)
    calls.sort(key=lambda c: c["start"])
    pairs, loose = pair_ledger(calls, ledger)
    recs = []
    for i, c in enumerate(calls):
        r = finalize(c, ledger[pairs[i]] if i in pairs else None)
        r["join_miss"] = i not in pairs and first_ts is not None and c["start"] >= first_ts
        recs.append(r)
    assign_redo(calls, recs)
    recs += [finalize_unattributed(ledger[i]) for i in loose]
    by_day = {d: [] for d in all_days}
    for r in recs:
        by_day.setdefault(r["day"], []).append(r)
    rows, models = {}, {}
    for d in all_days:
        # bad ledger lines are a whole-file count: report them once, on the report date
        rows[d], models[d] = aggregate(by_day.get(d, []), bad if d == last else 0)
    docs = []
    for d in sorted(dates):
        numbers = dict(rows[d], transcripts_scanned=stats["scanned"],
                       skipped_transcripts=stats["skipped"])
        docs.append({"v": 1, "date": d.isoformat(), "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                     "numbers": numbers, "verdict": verdict(rows, d),
                     "models": models[d], "method": METHOD})
    return docs


def _attributed(numbers):
    return _i(numbers.get("calls")) - _i(numbers.get("unattributed"))


def write_doc(state_dir, doc, force=False):
    """Atomic write. -> True when written, False when a better file was kept."""
    d = os.path.join(state_dir, "daily")
    target = os.path.join(d, doc["date"] + ".json")
    if not force and os.path.exists(target):
        try:
            with open(target, "r", encoding="utf-8") as fh:
                old = json.load(fh)
            old_n = old["numbers"]
            good = _i(old_n.get("transcripts_scanned")) > 0 or _attributed(old_n) > 0
            if good and _attributed(doc["numbers"]) < _attributed(old_n):
                print("llm-delegate-scan: kept existing %s (%d attributed calls; this run found %d); "
                      "use --force to replace it" % (target, _attributed(old_n), _attributed(doc["numbers"])),
                      file=sys.stderr)
                return False
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            pass
    os.makedirs(d, mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-", suffix=".json")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(doc, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return True


def summary(doc):
    n, v = doc["numbers"], doc["verdict"]
    return "\n".join([
        "Local helper delegation, %s (verdict: %s)" % (doc["date"], v["verdict"]),
        "  calls %d: ok %d, fallback %d, truncated %d, unattributed %d"
        % (n["calls"], n["ok"], n["fallback"], n["truncated"], n["unattributed"]),
        "  success %.1f%%, fallback %.1f%%" % (n["success_rate_pct"], n["fallback_rate_pct"]),
        "  outcomes: used %d, redone %d, unknown %d" % (n["used"], n["redone"], n["unknown"]),
        "  local: %d tokens out, %d tokens in, %d s" % (n["local_tokens"], n["local_prompt_tokens"], n["local_seconds"]),
        "  plan tokens: saved %d - wrap %d - redo %d = net %d"
        % (n["saved_tokens"], n["wrap_tokens"], n["redo_tokens"], n["net_tokens"]),
        "  trailing %dd: %d calls, net %d" % (v["trailing_days"], v["trailing_calls"], v["trailing_net_tokens"]),
        "  bad ledger lines: %d, join misses: %d, transcripts %d (skipped %d)"
        % (n["bad_ledger_lines"], n["join_misses"], n["transcripts_scanned"], n["skipped_transcripts"]),
    ])


def _date(s):
    try:
        return dt.date.fromisoformat(s)
    except ValueError:
        raise argparse.ArgumentTypeError("bad date %r (want YYYY-MM-DD)" % s)


def _oserr(e):
    msg = e.strerror or str(e)
    return "%s: %s" % (e.filename, msg) if e.filename else msg


def main(argv=None):
    ap = argparse.ArgumentParser(description="Daily report: is the local LLM helper saving plan tokens?")
    ap.add_argument("--date", type=_date, help="report day (Europe/London); default yesterday")
    ap.add_argument("--since", type=_date, help="first day of a range (with --until)")
    ap.add_argument("--until", type=_date, help="last day of a range (with --since)")
    ap.add_argument("--backfill", type=int, metavar="N", help="report the last N days")
    ap.add_argument("--state-dir", help="where daily/ is written (default: the ledger's directory, "
                    "else ${XDG_STATE_HOME:-$HOME/.local/state}/forge/llm-delegate)")
    ap.add_argument("--json", action="store_true", help="print JSON instead of text")
    ap.add_argument("--no-write", action="store_true", help="do not write the daily file")
    ap.add_argument("--force", action="store_true",
                    help="replace an existing daily file even when this run finds fewer attributed calls")
    a = ap.parse_args(argv)
    modes = [m for m, on in (("--date", a.date is not None),
                             ("--since/--until", a.since is not None or a.until is not None),
                             ("--backfill", a.backfill is not None)) if on]
    if len(modes) > 1:
        ap.error("argument %s: not allowed with argument %s" % (modes[1], modes[0]))
    now = dt.datetime.now(dt.timezone.utc)
    yday = dt.datetime.now(LONDON).date() - dt.timedelta(days=1)
    if a.backfill is not None:
        if a.backfill < 1:
            ap.error("--backfill needs N >= 1")
        dates = [yday - dt.timedelta(days=i) for i in range(a.backfill)]
    elif a.since or a.until:
        end = a.until or yday
        start = a.since or end
        if start > end:
            ap.error("--since is after --until")
        dates = [start + dt.timedelta(days=i) for i in range((end - start).days + 1)]
    else:
        dates = [a.date or yday]
    lp = ledger_path()
    state_dir = a.state_dir or (os.path.dirname(os.path.abspath(lp)) if lp else _default_state_dir())
    membrane = os.environ.get("FORGE_MEMBRANE") or os.path.join(os.path.expanduser("~"), ".claude")
    root = os.path.join(membrane, "projects")
    if not os.path.isdir(root):
        print("llm-delegate-scan: transcripts directory not found: %s" % root, file=sys.stderr)
        return 2
    try:
        docs = build_docs(dates, lp, membrane, now)
        if not a.no_write:
            for d in docs:
                write_doc(state_dir, d, a.force)
    except OSError as e:
        print("llm-delegate-scan: %s" % _oserr(e), file=sys.stderr)
        return 2
    if a.json:
        print(json.dumps(docs[0] if len(docs) == 1 else docs, indent=2, sort_keys=True))
    else:
        print("\n\n".join(summary(d) for d in docs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
