#!/usr/bin/env bash
# temper-consolidate.sh — Deterministic consolidation for /temper Step 3
#
# Parses FINDING_START/FINDING_END blocks from saved pass outputs, groups by
# normalized TITLE+FILE, computes confidence buckets / severity promotion /
# press score averages, and emits the pre-rendered report tables. The opus
# orchestrator keeps the judgment half: adjudicating NEAR_DUPLICATES,
# challenging unevidenced findings, and owning the Temper Verdict.
#
# USAGE:
#   temper-consolidate.sh <passes-dir> <N>
#     <passes-dir> — directory holding <art>-pass-<i>.txt files
#                    (art ∈ {poke, press}; i ∈ 1..N), saved verbatim from
#                    each pass subagent's output.
#     <N>          — passes per art (confidence thresholds derive from this).
#
# Output (stdout, markdown):
#   Confidence Legend, Readiness Scorecard (press), Code Quality Summary (poke),
#   Confirmed/Likely/Possible findings, NEAR_DUPLICATES (title-token overlap
#   pairs for opus adjudication — each group lists its contributing passes so
#   merged confidence can be recomputed as the union of passes).
#
# Requires: awk. bash >=3.2.
set -euo pipefail

DIR="${1:?usage: temper-consolidate.sh <passes-dir> <N>}"
N="${2:?usage: temper-consolidate.sh <passes-dir> <N>}"
[[ -d "$DIR" ]] || { echo "ERROR: no such directory: $DIR" >&2; exit 1; }
[[ "$N" =~ ^[0-9]+$ && "$N" -ge 1 ]] || { echo "ERROR: N must be a positive integer." >&2; exit 2; }

shopt -s nullglob
FILES=("$DIR"/poke-pass-*.txt "$DIR"/press-pass-*.txt)
shopt -u nullglob
[[ ${#FILES[@]} -gt 0 ]] || { echo "ERROR: no <art>-pass-<i>.txt files in $DIR" >&2; exit 1; }

awk -v N="$N" '
function norm(s,  t) { t = tolower(s); gsub(/[^a-z0-9]+/, " ", t); gsub(/^ +| +$/, "", t); return t }
function sevrank(s) { return s == "CRITICAL" ? 3 : s == "IMPORTANT" ? 2 : 1 }
function sevname(r) { return r == 3 ? "CRITICAL" : r == 2 ? "IMPORTANT" : "MINOR" }
function confidence(c) { return c >= N ? "Confirmed" : c >= int((N + 1) / 2) ? "Likely" : "Possible" }
function halfround(x) { return int(x * 2 + 0.5) / 2 }

FNR == 1 {
  fname = FILENAME
  sub(/^.*\//, "", fname)
  art = fname; sub(/-pass-.*$/, "", art)
  pass = fname; sub(/^.*-pass-/, "", pass); sub(/\.txt$/, "", pass)
  passid = art "-" pass
}

/^FINDING_START[[:space:]]*$/ { inblock = 1; delete f; lastfield = ""; next }

/^FINDING_END[[:space:]]*$/ {
  if (!inblock) next
  inblock = 0
  key = art SUBSEP norm(f["TITLE"]) SUBSEP norm(f["FILE"])
  if (!(key in title)) {
    order[++G] = key
    title[key] = f["TITLE"]; file[key] = f["FILE"]; grpart[key] = art
    dim[key] = f["DIMENSION"]; sev[key] = 0
  }
  if (!((key, passid) in seen)) { seen[key, passid] = 1; hits[key]++
    passes[key] = (passes[key] == "" ? passid : passes[key] "," passid) }
  r = sevrank(f["SEVERITY"])
  if (r > sev[key]) { sev[key] = r
    prob[key] = f["PROBLEM"]; fix[key] = f["FIX"]; eff[key] = f["EFFORT"] }
  if (art == "press" && f["SCORE"] ~ /^[0-9]/) {
    d = norm(f["DIMENSION"])
    if (!(d in dimname)) { pdims[++PD] = d; dimname[d] = f["DIMENSION"] }
    ssum[d] += f["SCORE"] + 0; scnt[d]++
  }
  next
}

inblock && /^[A-Z]+:/ {
  fieldname = $0; sub(/:.*$/, "", fieldname)
  val = $0; sub(/^[A-Z]+:[[:space:]]*/, "", val)
  f[fieldname] = val; lastfield = fieldname; next
}

inblock && lastfield != "" { f[lastfield] = f[lastfield] " " $0; next }

END {
  print "## Consolidated Findings (temper-consolidate.sh — deterministic; opus adjudicates below)"
  print ""
  print "### Confidence Legend"
  print ""
  printf "| Confidence | Threshold (N=%d per art) |\n", N
  print "|------------|--------------------------|"
  printf "| Confirmed | %d/%d passes |\n", N, N
  printf "| Likely | >= %d passes |\n", int((N + 1) / 2)
  print "| Possible | 1 pass |"
  print ""

  print "### Readiness Scorecard (press)"
  print ""
  print "| Dimension | Avg Score | Gaps | Status |"
  print "|-----------|-----------|------|--------|"
  total = 0
  for (i = 1; i <= PD; i++) {
    d = pdims[i]; avg = halfround(ssum[d] / scnt[d]); total += avg
    status = avg >= 4 ? "🟢" : avg >= 3 ? "🟡" : "🔴"
    printf "| %s | %.1f | [opus fills] | %s |\n", dimname[d], avg, status
  }
  if (PD > 0) printf "| **Overall** | **%.1f/35** | | |\n", total
  else print "| _no press findings parsed_ | | | |"
  print ""

  print "### Code Quality Summary (poke)"
  print ""
  print "| Dimension | Confirmed | Likely | Possible |"
  print "|-----------|-----------|--------|----------|"
  for (g = 1; g <= G; g++) {
    key = order[g]
    if (grpart[key] != "poke") continue
    d = norm(dim[key])
    if (!(d in qdimname)) { qdims[++QD] = d; qdimname[d] = dim[key] }
    q[d, confidence(hits[key])]++
  }
  tc = 0; tl = 0; tp = 0
  for (i = 1; i <= QD; i++) {
    d = qdims[i]
    printf "| %s | %d | %d | %d |\n", qdimname[d], q[d, "Confirmed"] + 0, q[d, "Likely"] + 0, q[d, "Possible"] + 0
    tc += q[d, "Confirmed"] + 0; tl += q[d, "Likely"] + 0; tp += q[d, "Possible"] + 0
  }
  if (QD > 0) printf "| **Total** | **%d** | **%d** | **%d** |\n", tc, tl, tp
  else print "| _no poke findings parsed_ | | | |"
  print ""

  bucket[1] = "Confirmed"; bucket[2] = "Likely"; bucket[3] = "Possible"
  hdr[1] = "### Confirmed Findings (fix these)"
  hdr[2] = "### Likely Findings (review these)"
  hdr[3] = "### Possible Findings (may be noise)"
  for (b = 1; b <= 3; b++) {
    print hdr[b]; print ""
    any = 0
    for (r = 3; r >= 1; r--) for (g = 1; g <= G; g++) {
      key = order[g]
      if (confidence(hits[key]) != bucket[b] || sev[key] != r) continue
      any = 1
      if (b == 3) {
        printf "- [%s] %s (%s, `%s`, %s) — passes: %s\n", sevname(r), title[key], grpart[key], file[key], dim[key], passes[key]
      } else {
        printf "#### [%s] %s\n", sevname(r), title[key]
        printf "- **Art/Dimension**: %s / %s | **File**: `%s` | **Effort**: %s | **Passes**: %s (%d/%d)\n", grpart[key], dim[key], file[key], eff[key], passes[key], hits[key], N
        printf "- **Problem**: %s\n", prob[key]
        printf "- **Fix**: %s\n", fix[key]
        print ""
      }
    }
    if (!any) print "_none_"
    print ""
  }

  print "### NEAR_DUPLICATES (opus: adjudicate on defect identity, not wording)"
  print ""
  nd = 0
  for (a = 1; a <= G; a++) for (b2 = a + 1; b2 <= G; b2++) {
    k1 = order[a]; k2 = order[b2]
    if (grpart[k1] != grpart[k2]) continue
    n1 = split(norm(title[k1]), w1, " "); n2 = split(norm(title[k2]), w2, " ")
    delete set; inter = 0
    for (i = 1; i <= n1; i++) set[w1[i]] = 1
    for (i = 1; i <= n2; i++) if (w2[i] in set) { inter++; delete set[w2[i]] }
    uni = n1 + n2 - inter
    samefile = (norm(file[k1]) == norm(file[k2]) && norm(file[k1]) != "" && norm(file[k1]) != "n a")
    if ((uni > 0 && inter / uni >= 0.5) || samefile) {
      nd++
      printf "- \"%s\" (`%s`, passes: %s) ~ \"%s\" (`%s`, passes: %s) — if same defect, merge and recompute confidence from the UNION of passes\n", \
        title[k1], file[k1], passes[k1], title[k2], file[k2], passes[k2]
    }
  }
  if (nd == 0) print "_none detected_"
}
' "${FILES[@]}"
