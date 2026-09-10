#!/usr/bin/env bash
# Shared helpers for NiriShift installer and CLI.

NIRI_SHIFT_VERSION="0.1.0"
NIRI_SHIFT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/niri-shift"
NIRI_SHIFT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri-shift"
NIRI_SHIFT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-shift"
GAMESCOPE_ENV_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/gamescope-session-plus.conf"

info()  { echo "[niri-shift] $*"; }
warn()  { echo "[niri-shift] WARNING: $*" >&2; }
err()   { echo "[niri-shift] ERROR: $*" >&2; }
die()   { err "$*"; exit 1; }

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

check_package() {
  pacman -Qi "$1" &>/dev/null
}

check_aur_helper() {
  command -v yay &>/dev/null || command -v paru &>/dev/null
}

aur_install() {
  local pkgs=("$@")
  if command -v yay &>/dev/null; then
    yay -S --needed --noconfirm "${pkgs[@]}"
  elif command -v paru &>/dev/null; then
    paru -S --needed --noconfirm "${pkgs[@]}"
  else
    die "AUR helper (yay/paru) required for: ${pkgs[*]}"
  fi
}

require_root_for_install() {
  if [[ $EUID -eq 0 ]]; then
    die "Run install.sh as your normal user (it will call sudo when needed)"
  fi
}

load_backend() {
  local id="${1:-}"
  local root
  root="$(repo_root)"
  if [[ -z "$id" ]]; then
    # shellcheck source=../backends/niri.sh
    if [[ -f "$root/backends/niri.sh" ]] && command -v niri &>/dev/null; then
      id="niri"
    elif [[ -f "$root/backends/hyprland.sh" ]] && command -v hyprctl &>/dev/null; then
      id="hyprland"
    else
      id="niri"
    fi
  fi
  local backend_file="$root/backends/${id}.sh"
  [[ -f "$backend_file" ]] || die "Unknown backend: $id ($backend_file)"
  # shellcheck source=/dev/null
  source "$backend_file"
  BACKEND_ID="$id"
}
