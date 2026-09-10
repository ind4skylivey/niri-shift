#!/usr/bin/env bash
# Restart xdg-desktop-portal after returning from Gaming Mode (compositor-agnostic).

marker=/tmp/.niri-shift-just-returned
returned=0
if [[ -f $marker ]]; then
  returned=1
  rm -f "$marker"
fi

# Wait for compositor (backend hook or generic WAYLAND_DISPLAY)
if [[ -x /usr/local/lib/niri-shift/portal-wait ]]; then
  /usr/local/lib/niri-shift/portal-wait || true
else
  for _ in {1..20}; do
    systemctl --user show-environment 2>/dev/null | grep -q '^WAYLAND_DISPLAY=' && break
    sleep 0.5
  done
fi

portal_poisoned() {
  local pid
  pid=$(systemctl --user show -p MainPID --value xdg-desktop-portal.service 2>/dev/null)
  [[ -n $pid && $pid != 0 && -r /proc/$pid/environ ]] || return 1
  tr '\0' '\n' < "/proc/$pid/environ" | grep -q '^WAYLAND_DISPLAY=' || return 0
  tr '\0' '\n' < "/proc/$pid/environ" | grep -q '^XDG_CURRENT_DESKTOP=' || return 0
  return 1
}

if (( ! returned )) && ! portal_poisoned; then
  exit 0
fi

VARS="WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE"
# shellcheck disable=SC2086
systemctl --user import-environment $VARS 2>/dev/null || true
# shellcheck disable=SC2086
dbus-update-activation-environment --systemd $VARS 2>/dev/null || true

backends=""
if [[ -x /usr/local/lib/niri-shift/portal-backends ]]; then
  backends=$(/usr/local/lib/niri-shift/portal-backends)
fi
# shellcheck disable=SC2086
systemctl --user stop $backends 2>/dev/null || true
systemctl --user reset-failed xdg-desktop-portal.service 2>/dev/null || true
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
