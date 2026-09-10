#!/usr/bin/env bash
# Hyprland backend (community adapter stub). Not Omarchy-specific.

backend_id() { echo hyprland; }

backend_desktop_sddm_session() {
  if [[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]]; then
    echo hyprland-uwsm
  else
    echo hyprland
  fi
}

backend_validate() {
  command -v hyprctl >/dev/null || die "hyprctl required for hyprland backend"
}

backend_pre_gaming_switch() {
  local env_conf="${GAMESCOPE_ENV_CONF:-$HOME/.config/environment.d/gamescope-session-plus.conf}"
  [[ -f "$env_conf" ]] || return 0
  local to_disable
  to_disable=$(awk -F= '$1=="OUTPUT_CONNECTOR_TO_DISABLE" { sub(/^[^=]*=/,""); v=$0 } END { print v }' "$env_conf")
  [[ -n "$to_disable" ]] || return 0
  local conn
  IFS=',' read -ra DISABLE_LIST <<< "$to_disable"
  for conn in "${DISABLE_LIST[@]}"; do
    conn="${conn// /}"
    [[ -z "$conn" ]] && continue
    hyprctl keyword monitor "${conn},disable" 2>/dev/null || true
  done
  sleep 0.5
}

backend_portal_wait() {
  local i
  for i in $(seq 1 20); do
    systemctl --user show-environment 2>/dev/null \
      | grep -q '^HYPRLAND_INSTANCE_SIGNATURE=' && return 0
    sleep 0.5
  done
  return 1
}

backend_portal_backends() {
  echo "xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service"
}

backend_keybind_doc() {
  cat <<'DOC'
Hyprland (~/.config/hypr/bindings.conf or bindings.lua):

  bind = SUPER SHIFT, G, exec, niri-shift-switch-to-gaming

Omarchy 4 Lua users: use hl.unbind if SUPER+SHIFT+S is claimed, then o.bind(...).
DOC
}

backend_autostart_snippet() {
  echo 'exec-once = niri-shift-portal-recovery'
}
