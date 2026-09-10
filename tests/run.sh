#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0
fail=0

ok() { echo "PASS: $*"; pass=$((pass + 1)); }
bad() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }

# Syntax check shell scripts
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done < <(find . -type f \( -name '*.sh' -o -path './bin/*' -o -path './settings/*' \) ! -path './.git/*' -print0)

# Backend interface
for b in backends/*.sh; do
  # shellcheck source=/dev/null
  source "$b"
  for fn in backend_id backend_desktop_sddm_session backend_validate backend_pre_gaming_switch; do
    if declare -f "$fn" >/dev/null; then ok "$b defines $fn"; else bad "$b missing $fn"; fi
  done
done

# Dry-run install (capture output; pipefail + grep -q SIGPIPE otherwise)
install_out=$(./install.sh --dry-run --backend niri 2>&1) || true
if echo "$install_out" | grep -qE '\[dry-run\]|dry-run'; then
  ok "install.sh --dry-run"
else
  bad "install.sh --dry-run"
fi

uninstall_out=$(./uninstall.sh --dry-run 2>&1) || true
if echo "$uninstall_out" | grep -qE '\[dry-run\]|dry-run'; then
  ok "uninstall.sh --dry-run"
else
  bad "uninstall.sh --dry-run"
fi

# Docs present
[[ -f docs/ARCHITECTURE.md ]] && ok "ARCHITECTURE.md" || bad "ARCHITECTURE.md"
[[ -f LICENSE ]] && ok "LICENSE" || bad "LICENSE"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
