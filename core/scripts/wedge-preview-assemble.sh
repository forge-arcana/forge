#!/usr/bin/env bash
# wedge-preview-assemble.sh — Mechanical Heat 3 preview assembly for /wedge.
# Combines 2+ scoped HTML fragments (one per direction/apprentice) into a
# single self-contained preview file with a plain-JS tab selector at the top.
#
# Each fragment is isolated in its own <iframe srcdoc="..."> so a fragment's
# CSS/JS can never bleed into another tab or into the shell chrome. srcdoc
# content is HTML-escaped (& and ") so the browser's attribute decode step
# reconstructs the original fragment byte-for-byte.
#
# Usage:
#   wedge-preview-assemble.sh <out.html> <label1> <frag1.html> [<label2> <frag2.html> ...]
#
# Requires at least 2 label/fragment pairs. Deterministic: identical inputs
# always produce byte-identical output (no timestamps, no random ids — tab
# ids are index-based).
#
# Portable: bash >=3.2 (no associative arrays), sed only. No external deps.
set -euo pipefail

usage() {
  echo "Usage: wedge-preview-assemble.sh <out.html> <label1> <frag1.html> [<label2> <frag2.html> ...]" >&2
  echo "  Requires at least 2 label/fragment pairs." >&2
  exit 1
}

OUT="${1:-}"
[[ -z "$OUT" ]] && usage
shift || true

if [[ $# -lt 4 ]]; then
  echo "ERROR: need at least 2 label/fragment pairs (got $# args after output path)." >&2
  usage
fi
if (( $# % 2 != 0 )); then
  echo "ERROR: arguments after the output path must come in label/fragment pairs (odd count given)." >&2
  usage
fi

LABELS=()
FRAGS=()
while [[ $# -gt 0 ]]; do
  LABELS+=("$1")
  FRAGS+=("$2")
  shift 2
done

for f in "${FRAGS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: fragment file not found: $f" >&2
    exit 1
  fi
done

OUT_DIR="$(dirname "$OUT")"
if [[ ! -d "$OUT_DIR" ]]; then
  echo "ERROR: output directory does not exist: $OUT_DIR" >&2
  exit 1
fi

# HTML-attribute-escape a fragment file's contents for embedding inside a
# double-quoted srcdoc="..." attribute. Only & and " need escaping — the
# browser's attribute-value decode pass reverses exactly this transform
# before parsing the iframe's document, so it round-trips losslessly.
esc_attr_file() {
  sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' "$1"
}

# HTML-escape a short string (labels) for use as element text or an
# attribute value in the shell chrome itself.
esc_html_str() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  printf '%s' "$s"
}

TMP="$(mktemp "${TMPDIR:-/tmp}/wedge-preview.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

{
  echo '<!doctype html>'
  echo '<html lang="en">'
  echo '<head>'
  echo '<meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  echo '<title>Wedge Preview</title>'
  echo '<style>'
  echo '  :root { color-scheme: light dark; }'
  echo '  * { box-sizing: border-box; }'
  echo '  html, body { margin: 0; height: 100%; }'
  echo '  body {'
  echo '    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;'
  echo '    background: #111; color: #eee; display: flex; flex-direction: column;'
  echo '  }'
  echo '  .tabbar {'
  echo '    display: flex; gap: 4px; padding: 8px; background: #000;'
  echo '    border-bottom: 1px solid #333; flex: 0 0 auto;'
  echo '  }'
  echo '  .tabbar button {'
  echo '    font: inherit; font-size: 14px; padding: 8px 16px; border: 1px solid #333;'
  echo '    border-radius: 6px; background: #1a1a1a; color: #ccc; cursor: pointer;'
  echo '  }'
  echo '  .tabbar button.active { background: #333; color: #fff; border-color: #666; }'
  echo '  .panels { flex: 1 1 auto; position: relative; }'
  echo '  .panel { position: absolute; inset: 0; display: none; }'
  echo '  .panel.active { display: block; }'
  echo '  .panel iframe { width: 100%; height: 100%; border: 0; display: block; }'
  echo '</style>'
  echo '</head>'
  echo '<body>'
  echo '<div class="tabbar" role="tablist">'
  for i in "${!LABELS[@]}"; do
    active=""
    [[ "$i" == "0" ]] && active=" active"
    label_esc="$(esc_html_str "${LABELS[$i]}")"
    echo "  <button class=\"tab$active\" data-tab=\"t$i\" role=\"tab\" aria-selected=\"$([[ "$i" == "0" ]] && echo true || echo false)\">$label_esc</button>"
  done
  echo '</div>'
  echo '<div class="panels">'
  for i in "${!LABELS[@]}"; do
    active=""
    [[ "$i" == "0" ]] && active=" active"
    echo "  <div class=\"panel$active\" id=\"t$i\" role=\"tabpanel\">"
    label_esc="$(esc_html_str "${LABELS[$i]}")"
    printf '    <iframe title="%s" srcdoc="' "$label_esc"
    esc_attr_file "${FRAGS[$i]}"
    printf '"></iframe>\n'
    echo '  </div>'
  done
  echo '</div>'
  echo '<script>'
  echo '(function () {'
  echo '  var buttons = document.querySelectorAll(".tabbar button");'
  echo '  var panels = document.querySelectorAll(".panel");'
  echo '  function activate(id) {'
  echo '    buttons.forEach(function (b) {'
  echo '      var on = b.getAttribute("data-tab") === id;'
  echo '      b.classList.toggle("active", on);'
  echo '      b.setAttribute("aria-selected", on ? "true" : "false");'
  echo '    });'
  echo '    panels.forEach(function (p) { p.classList.toggle("active", p.id === id); });'
  echo '  }'
  echo '  buttons.forEach(function (b) {'
  echo '    b.addEventListener("click", function () {'
  echo '      var id = b.getAttribute("data-tab");'
  echo '      window.location.hash = id;'
  echo '      activate(id);'
  echo '    });'
  echo '  });'
  echo '  var initial = (window.location.hash || "").replace("#", "");'
  echo '  if (!document.getElementById(initial)) { initial = "t0"; }'
  echo '  activate(initial);'
  echo '})();'
  echo '</script>'
  echo '</body>'
  echo '</html>'
} > "$TMP"

mv "$TMP" "$OUT"
trap - EXIT

echo "Wrote preview: $OUT (${#LABELS[@]} tabs)"
