#!/usr/bin/env bash
# Patch gamescope-session-plus for --nested-refresh fallback (from DeckShift v0.1.12 logic).

set -euo pipefail

gsp="/usr/share/gamescope-session-plus/gamescope-session-plus"

if [[ ! -f "$gsp" ]]; then
  echo "gamescope-session-plus not found at $gsp" >&2
  exit 0
fi

if grep -q "NIRI-SHIFT-NESTED-REFRESH-FALLBACK" "$gsp" 2>/dev/null; then
  echo "already patched"
  exit 0
fi

tmp=$(mktemp)
python3 - "$gsp" "$tmp" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()

pattern = re.compile(
    r'(\tCUSTOM_REFRESH_RATES_OPTION=""\n'
    r'\tif \[ -n "\$CUSTOM_REFRESH_RATES" \] && gamescope_has_option "--custom-refresh-rates"; then\n'
    r'\t\tCUSTOM_REFRESH_RATES_OPTION="--custom-refresh-rates \$CUSTOM_REFRESH_RATES"\n'
    r')(\tfi\n)'
)

def _patch(m):
    return m.group(1) + (
        '\telif [ -n "$CUSTOM_REFRESH_RATES" ] && gamescope_has_option "--nested-refresh"; then  # NIRI-SHIFT-NESTED-REFRESH-FALLBACK\n'
        '\t\t_niri_shift_rate=$(echo "$CUSTOM_REFRESH_RATES" | tr "," "\\n" | sort -nr | head -1)\n'
        '\t\tCUSTOM_REFRESH_RATES_OPTION="--nested-refresh $_niri_shift_rate"\n'
    ) + m.group(2)

new = pattern.sub(_patch, content, count=1)
if new == content:
    sys.stderr.write("could not locate CUSTOM_REFRESH_RATES_OPTION block\n")
    sys.exit(1)
with open(dst, "w") as f:
    f.write(new)
PY

if ! grep -q "NIRI-SHIFT-NESTED-REFRESH-FALLBACK" "$tmp"; then
  echo "patch verification failed" >&2
  rm -f "$tmp"
  exit 1
fi

sudo install -m 0755 "$tmp" "$gsp"
rm -f "$tmp"
echo "patched $gsp"
