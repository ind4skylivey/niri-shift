#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core/common.sh
source "$ROOT/core/common.sh"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: $0 [--dry-run]"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

rm_file() {
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] rm $1"
  elif [[ -e "$1" ]]; then
    sudo rm -f "$1"
  fi
}

BINARIES=(
  /usr/local/bin/niri-shift-switch-to-gaming
  /usr/local/bin/niri-shift-switch-to-desktop
  /usr/local/bin/niri-shift-gaming-session-switch
  /usr/local/bin/niri-shift-gamescope-wrapper
  /usr/local/bin/niri-shift-keybind-monitor
  /usr/local/bin/niri-shift-portal-recovery
  /usr/local/bin/niri-shift-gamescope-nm-start
  /usr/local/bin/niri-shift-gamescope-nm-stop
  /usr/local/bin/niri-shift
  /usr/local/bin/niri-shift-settings
)

for f in "${BINARIES[@]}"; do rm_file "$f"; done
rm_file /usr/share/wayland-sessions/gamescope-session-steam-nm.desktop
rm_file /etc/sddm.conf.d/zz-niri-shift-session.conf
rm_file /etc/sudoers.d/niri-shift-session
sudo rm -rf /usr/local/lib/niri-shift 2>/dev/null || true

warn "os-session-select left in place if another tool installed it"
warn "gamescope-session-plus patch marker NIRI-SHIFT-* is not reverted automatically"
info "Uninstall finished"
