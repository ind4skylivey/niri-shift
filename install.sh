#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core/common.sh
source "$ROOT/core/common.sh"

BACKEND_ARG=""
DRY_RUN=0
WIRE_AUTOSTART=0

usage() {
  cat <<EOF
NiriShift installer v${NIRI_SHIFT_VERSION}

Usage: $0 [options]

  --backend niri|hyprland   Compositor backend (default: auto)
  --wire-autostart          Append portal-recovery to niri autostarts.kdl if found
  --dry-run                 Print actions without installing
  -h, --help                This help

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend) BACKEND_ARG="${2:-}"; shift 2 ;;
    --wire-autostart) WIRE_AUTOSTART=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ $DRY_RUN -eq 0 ]] && require_root_for_install
load_backend "$BACKEND_ARG"
backend_validate

command -v sddm >/dev/null || die "SDDM required"
command -v pacman >/dev/null || die "pacman required"

PACMAN_DEPS=(
  steam gamescope gamemode lib32-gamemode mangohud lib32-mangohud
  python-evdev gum jq
)
AUR_DEPS=(gamescope-session-git gamescope-session-steam-git)

info "Backend: $(backend_id) (desktop SDDM session: $(backend_desktop_sddm_session))"

if [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] Would install: ${PACMAN_DEPS[*]} ${AUR_DEPS[*]}"
else
  info "Installing pacman packages..."
  sudo pacman -S --needed --noconfirm "${PACMAN_DEPS[@]}"
  if ! check_package gamescope-session-git && ! check_package gamescope-session; then
    check_aur_helper || die "Install yay/paru for AUR packages"
    info "Installing AUR gamescope-session packages..."
    aur_install "${AUR_DEPS[@]}"
  fi
fi

DESKTOP_SESSION="$(backend_desktop_sddm_session)"
install_script() {
  local src="$1" dest="$2" mode="${3:-755}"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] install $src -> $dest"
    return
  fi
  if [[ "$src" == *gaming-session-switch* ]]; then
    sed "s/@DESKTOP_SESSION@/${DESKTOP_SESSION}/g" "$src" | sudo tee "$dest" > /dev/null
  else
    sudo install -m "$mode" "$src" "$dest"
  fi
}

SCRIPTS=(
  "lib/scripts/niri-shift-switch-to-gaming.sh:/usr/local/bin/niri-shift-switch-to-gaming"
  "lib/scripts/niri-shift-switch-to-desktop.sh:/usr/local/bin/niri-shift-switch-to-desktop"
  "lib/scripts/niri-shift-gaming-session-switch.sh:/usr/local/bin/niri-shift-gaming-session-switch"
  "lib/scripts/niri-shift-gamescope-wrapper.sh:/usr/local/bin/niri-shift-gamescope-wrapper"
  "lib/scripts/niri-shift-portal-recovery.sh:/usr/local/bin/niri-shift-portal-recovery"
  "lib/scripts/niri-shift-gamescope-nm-start.sh:/usr/local/bin/niri-shift-gamescope-nm-start"
  "lib/scripts/niri-shift-gamescope-nm-stop.sh:/usr/local/bin/niri-shift-gamescope-nm-stop"
)

for pair in "${SCRIPTS[@]}"; do
  src="${pair%%:*}"
  dest="${pair##*:}"
  install_script "$ROOT/$src" "$dest"
done

if [[ $DRY_RUN -eq 0 ]]; then
  sudo install -m 755 "$ROOT/lib/scripts/niri-shift-keybind-monitor.py" /usr/local/bin/niri-shift-keybind-monitor
fi

# Backend hooks
if [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] install backend hooks to /usr/local/lib/niri-shift/"
else
  sudo mkdir -p /usr/local/lib/niri-shift
  sudo install -m 644 "$ROOT/backends/$(backend_id).sh" "/usr/local/lib/niri-shift/backend.sh"

  sudo tee /usr/local/lib/niri-shift/pre-gaming-switch > /dev/null <<'HOOK'
#!/usr/bin/env bash
# shellcheck source=/dev/null
source /usr/local/lib/niri-shift/backend.sh
backend_pre_gaming_switch
HOOK
  sudo tee /usr/local/lib/niri-shift/portal-wait > /dev/null <<'HOOK'
#!/usr/bin/env bash
# shellcheck source=/dev/null
source /usr/local/lib/niri-shift/backend.sh
backend_portal_wait
HOOK
  sudo tee /usr/local/lib/niri-shift/portal-backends > /dev/null <<'HOOK'
#!/usr/bin/env bash
# shellcheck source=/dev/null
source /usr/local/lib/niri-shift/backend.sh
backend_portal_backends
HOOK
  sudo chmod 755 /usr/local/lib/niri-shift/pre-gaming-switch \
    /usr/local/lib/niri-shift/portal-wait \
    /usr/local/lib/niri-shift/portal-backends
fi

# SDDM session desktop
if [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] create gamescope-session-steam-nm.desktop"
else
  sudo tee /usr/share/wayland-sessions/gamescope-session-steam-nm.desktop > /dev/null <<'DESKTOP'
[Desktop Entry]
Name=Gaming Mode (NiriShift)
Comment=Steam Big Picture with gamescope-session
Exec=/usr/local/bin/niri-shift-gamescope-wrapper
Type=Application
DesktopNames=gamescope
DESKTOP

  sudo tee /usr/lib/os-session-select > /dev/null <<'OSSEL'
#!/bin/bash
rm -f /tmp/.gaming-session-active
sudo -n /usr/local/bin/niri-shift-gaming-session-switch desktop 2>/dev/null || true
timeout 5 steam -shutdown 2>/dev/null || true
sleep 1
nohup sudo -n systemctl restart sddm &>/dev/null &
disown
exit 0
OSSEL
  sudo chmod 755 /usr/lib/os-session-select
fi

# SDDM autologin config
autologin_user="$USER"
if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  u=$(sed -n 's/^User=//p' /etc/sddm.conf.d/autologin.conf 2>/dev/null | head -1)
  [[ -n "$u" ]] && autologin_user="$u"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] create /etc/sddm.conf.d/zz-niri-shift-session.conf Session=${DESKTOP_SESSION}"
else
  sudo tee /etc/sddm.conf.d/zz-niri-shift-session.conf > /dev/null <<SDDM
[Autologin]
User=${autologin_user}
Session=${DESKTOP_SESSION}
Relogin=true
SDDM
fi

# Sudoers
if [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] sudoers /etc/sudoers.d/niri-shift-session"
else
  sudo tee /etc/sudoers.d/niri-shift-session > /dev/null <<'SUDOERS'
%video ALL=(ALL) NOPASSWD: /usr/local/bin/niri-shift-gaming-session-switch
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart sddm
%video ALL=(ALL) NOPASSWD: /usr/bin/chvt
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl mask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl unmask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl daemon-reload
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl start bluetooth.service
%video ALL=(ALL) NOPASSWD: /usr/bin/rfkill unblock bluetooth
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl start NetworkManager.service
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop NetworkManager.service
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/niri-shift-gamescope-nm-start
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/niri-shift-gamescope-nm-stop
SUDOERS
  sudo chmod 0440 /etc/sudoers.d/niri-shift-session
fi

# User config
mkdir -p "$NIRI_SHIFT_CONFIG_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
if [[ ! -f "$NIRI_SHIFT_CONFIG_DIR/config.env" ]]; then
  cp "$ROOT/config/config.env.example" "$NIRI_SHIFT_CONFIG_DIR/config.env"
fi

if [[ $DRY_RUN -eq 0 ]]; then
  bash "$ROOT/lib/patch-gamescope-session-plus.sh" || warn "gamescope-session-plus patch skipped"
  sudo install -m 755 "$ROOT/bin/niri-shift" /usr/local/bin/niri-shift
  sudo install -m 755 "$ROOT/settings/niri-shift-settings" /usr/local/bin/niri-shift-settings
fi

# Optional niri autostart
if [[ $WIRE_AUTOSTART -eq 1 && "$(backend_id)" == "niri" ]]; then
  autostart="${HOME}/.config/niri/modules/autostarts.kdl"
  snippet="$(backend_autostart_snippet)"
  if [[ -f "$autostart" ]] && ! grep -q "niri-shift-portal-recovery" "$autostart"; then
    echo "$snippet" >> "$autostart"
    info "Appended portal recovery to $autostart"
  fi
fi

echo ""
info "Installation complete (v${NIRI_SHIFT_VERSION})"
echo ""
backend_keybind_doc
echo ""
warn "Join the input group if not already: sudo usermod -aG input \$USER (re-login required)"
warn "Join the video group for passwordless session switch: sudo usermod -aG video \$USER"
info "Settings: niri-shift-settings"
info "Enter Gaming Mode: niri-shift-switch-to-gaming (bind in compositor)"
info "Exit Gaming Mode: Super+Shift+R inside gamescope session"
