#!/usr/bin/env bash
# Niri compositor backend for NiriShift.

backend_id() { echo niri; }

backend_desktop_sddm_session() { echo niri; }

backend_validate() {
  command -v niri >/dev/null || die "niri not found in PATH"
  [[ -f /usr/share/wayland-sessions/niri.desktop ]] || \
    warn "niri.desktop not in /usr/share/wayland-sessions (SDDM may use a different session name)"
}

backend_pre_gaming_switch() {
  local env_conf="${GAMESCOPE_ENV_CONF:-$HOME/.config/environment.d/gamescope-session-plus.conf}"
  [[ -f "$env_conf" ]] || return 0
  local to_disable
  to_disable=$(awk -F= '$1=="OUTPUT_CONNECTOR_TO_DISABLE" { sub(/^[^=]*=/,""); v=$0 } END { print v }' "$env_conf")
  [[ -n "$to_disable" ]] || return 0
  command -v niri >/dev/null || { warn "niri not in PATH; skipping output disable"; return 0; }
  if ! niri msg version &>/dev/null; then
    warn "niri socket unavailable; skipping output disable"
    return 0
  fi
  local conn
  IFS=',' read -ra DISABLE_LIST <<< "$to_disable"
  for conn in "${DISABLE_LIST[@]}"; do
    conn="${conn// /}"
    [[ -z "$conn" ]] && continue
    niri msg output "$conn" off 2>/dev/null || warn "could not disable output $conn"
  done
  sleep 0.5
}

backend_portal_wait() {
  local i
  for i in $(seq 1 20); do
    if niri msg version &>/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

backend_portal_backends() {
  # Stop common portal implementations; frontend restart picks the right one.
  echo "xdg-desktop-portal-gnome.service xdg-desktop-portal-wlr.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service"
}

backend_keybind_doc() {
  cat <<'DOC'
Add to ~/.config/niri/modules/keybinds.kdl (inside `binds { ... }`):

    Mod+Shift+G hotkey-overlay-title="Gaming Mode" { spawn-sh "niri-shift-switch-to-gaming"; }

Mod+Shift+S is often used elsewhere; pick any free binding.
DOC
}

backend_autostart_snippet() {
  echo 'spawn-sh-at-startup "niri-shift-portal-recovery"'
}
