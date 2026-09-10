#!/usr/bin/env bash
set -euo pipefail

NIRI_SHIFT_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/niri-shift"
NIRI_SHIFT_CAPTURE="$NIRI_SHIFT_STATE/capture"
NIRI_SHIFT_CURRENT="$NIRI_SHIFT_STATE/current"

if [[ -f "$NIRI_SHIFT_CAPTURE" ]]; then
  mkdir -p "$NIRI_SHIFT_STATE"
  NIRI_SHIFT_LOG="$NIRI_SHIFT_STATE/session-$(date +%Y%m%d-%H%M%S).log"
  {
    echo "=== NiriShift switch-to-gaming ==="
    echo "started: $(date -Iseconds)"
    echo "user: ${USER:-}"
    ENV_CONF="$HOME/.config/environment.d/gamescope-session-plus.conf"
    if [[ -f "$ENV_CONF" ]]; then
      echo "--- gamescope-session-plus.conf ---"
      cat "$ENV_CONF"
      echo "---"
    fi
  } > "$NIRI_SHIFT_LOG"
  printf '%s\n' "$NIRI_SHIFT_LOG" > "$NIRI_SHIFT_CURRENT"
  shopt -s nullglob
  prune_files=("$NIRI_SHIFT_STATE"/session-*.log)
  if ((${#prune_files[@]} > 10)); then
    mapfile -t prune_sorted < <(printf '%s\n' "${prune_files[@]}" | sort)
    prune_drop=$((${#prune_sorted[@]} - 10))
    for ((i = 0; i < prune_drop; i++)); do
      rm -f "${prune_sorted[i]}"
    done
  fi
  if command -v stdbuf >/dev/null 2>&1; then
    exec > >(stdbuf -oL tee -a "$NIRI_SHIFT_LOG") 2>&1
  else
    exec > >(tee -a "$NIRI_SHIFT_LOG") 2>&1
  fi
fi

sudo -n systemctl mask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
sudo -n /usr/local/bin/niri-shift-gaming-session-switch gaming 2>/dev/null || {
  notify-send -u critical -t 3000 "Gaming Mode" "Failed to update session config" 2>/dev/null || true
}
notify-send -u normal -t 2000 "Gaming Mode" "Switching to Gaming Mode..." 2>/dev/null || true

pkill -9 gamescope 2>/dev/null || true
pkill -9 -f gamescope-session 2>/dev/null || true
sleep 1

# Backend hook (niri msg output off / hyprctl monitor disable)
if [[ -x /usr/local/lib/niri-shift/pre-gaming-switch ]]; then
  /usr/local/lib/niri-shift/pre-gaming-switch
fi

sudo -n chvt 2 2>/dev/null || true
sleep 0.3
sudo -n systemctl restart sddm
