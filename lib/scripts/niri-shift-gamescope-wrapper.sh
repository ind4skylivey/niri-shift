#!/usr/bin/env bash
log() { logger -t niri-shift-wrapper "$*"; echo "$*"; }

SAVED_STATE_FILE="$HOME/.cache/niri-shift/saved-state"
NIRI_SHIFT_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/niri-shift"
NIRI_SHIFT_CAPTURE="$NIRI_SHIFT_STATE/capture"
NIRI_SHIFT_CURRENT="$NIRI_SHIFT_STATE/current"
DECKSHIFT_LOG=""
NIRI_SHIFT_LOG=""

niri_shift_capture_on() { [[ -f "$NIRI_SHIFT_CAPTURE" ]]; }

niri_shift_prune_logs() {
  shopt -s nullglob
  local files=("$NIRI_SHIFT_STATE"/session-*.log)
  (( ${#files[@]} > 10 )) || return 0
  mapfile -t sorted < <(printf '%s\n' "${files[@]}" | sort)
  local drop=$((${#sorted[@]} - 10)) i
  for (( i = 0; i < drop; i++ )); do rm -f "${sorted[i]}"; done
}

niri_shift_begin_session_log() {
  niri_shift_capture_on || return 0
  mkdir -p "$NIRI_SHIFT_STATE" || return 0
  local log=""
  if [[ -f "$NIRI_SHIFT_CURRENT" ]]; then
    log=$(tr -d '\n' < "$NIRI_SHIFT_CURRENT")
  fi
  if [[ -z "$log" || ! -f "$log" ]]; then
    log="$NIRI_SHIFT_STATE/session-$(date +%Y%m%d-%H%M%S).log"
    printf '%s\n' "$log" > "$NIRI_SHIFT_CURRENT"
    {
      echo "=== NiriShift session ==="
      echo "started: $(date -Iseconds)"
      echo "user: ${USER:-}"
    } > "$log"
    niri_shift_prune_logs
  fi
  { echo "=== gamescope session start ==="; echo "started: $(date -Iseconds)"; } >> "$log"
  NIRI_SHIFT_LOG="$log"
  exec >>"$log" 2>&1
}

niri_shift_begin_session_log

save_pre_gaming_state() {
  mkdir -p "$(dirname "$SAVED_STATE_FILE")"
  {
    echo "PRE_GAMING_CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
    echo "PRE_GAMING_POWER_PROFILE=$(powerprofilesctl get 2>/dev/null)"
  } > "$SAVED_STATE_FILE"
  log "Saved pre-Gaming-Mode state"
}

enable_performance_mode() {
  log "Enabling performance mode..."
  save_pre_gaming_state
  for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$gov" 2>/dev/null || true
  done
  if command -v nvidia-smi &>/dev/null; then
    sudo -n nvidia-smi -pm 1 2>/dev/null || true
    local max_power
    max_power=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null | head -1 | cut -d'.' -f1)
    [[ -n "$max_power" && "$max_power" -gt 0 ]] && sudo -n nvidia-smi -pl "$max_power" 2>/dev/null || true
  fi
  if command -v powerprofilesctl &>/dev/null; then
    sudo -n powerprofilesctl set performance 2>/dev/null || powerprofilesctl set performance 2>/dev/null || true
  fi
}

restore_balanced_mode() {
  log "Restoring pre-Gaming-Mode state..."
  local saved_cpu_gov="" saved_pp="" have_saved_state=0
  if [[ -f "$SAVED_STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SAVED_STATE_FILE"
    saved_cpu_gov="${PRE_GAMING_CPU_GOVERNOR:-}"
    saved_pp="${PRE_GAMING_POWER_PROFILE:-}"
    have_saved_state=1
  fi
  if (( have_saved_state )); then
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo "${saved_cpu_gov:-powersave}" > "$gov" 2>/dev/null || true
    done
    if command -v powerprofilesctl &>/dev/null; then
      sudo -n powerprofilesctl set "${saved_pp:-balanced}" 2>/dev/null || \
        powerprofilesctl set "${saved_pp:-balanced}" 2>/dev/null || true
    fi
    rm -f "$SAVED_STATE_FILE"
  fi
  if command -v nvidia-smi &>/dev/null; then
    local default_power
    default_power=$(nvidia-smi --query-gpu=power.default_limit --format=csv,noheader,nounits 2>/dev/null | head -1 | cut -d'.' -f1)
    [[ -n "$default_power" ]] && sudo -n nvidia-smi -pl "$default_power" 2>/dev/null || true
    sudo -n nvidia-smi -pm 0 2>/dev/null || true
  fi
}

cleanup() {
  [[ -n "${NIRI_SHIFT_CLEANUP_DONE:-}" ]] && return 0
  NIRI_SHIFT_CLEANUP_DONE=1
  pkill -f niri-shift-steam-library-mount 2>/dev/null || true
  pkill -f gaming-keybind-monitor 2>/dev/null || true
  pkill -f niri-shift-keybind-monitor 2>/dev/null || true
  sudo -n /usr/local/bin/niri-shift-gamescope-nm-stop 2>/dev/null || true
  restore_balanced_mode
  rm -f /tmp/.gaming-session-active
  [[ -n "$NIRI_SHIFT_LOG" ]] && echo "=== gamescope session end ===" >> "$NIRI_SHIFT_LOG" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

enable_performance_mode

if /usr/bin/lspci 2>/dev/null | grep -qi nvidia; then
  [[ -d /usr/local/lib/gamescope-nvidia ]] && export PATH="/usr/local/lib/gamescope-nvidia:$PATH"
fi

sudo -n /usr/local/bin/niri-shift-gamescope-nm-start 2>/dev/null || log "Warning: Could not start NetworkManager"

echo "gamescope" > /tmp/.gaming-session-active

keybind_ok=true
python3 -c "import evdev" 2>/dev/null || keybind_ok=false
groups | grep -qw input || keybind_ok=false

if $keybind_ok; then
  /usr/local/bin/niri-shift-keybind-monitor &
  log "Keybind monitor started (Super+Shift+R to exit)"
else
  log "Keybind monitor NOT started (install python-evdev, join input group)"
fi

export QT_IM_MODULE=steam
export GTK_IM_MODULE=Steam
export STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
export STEAM_ENABLE_VOLUME_HANDLER=1

if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL /usr/share/gamescope-session-plus/gamescope-session-plus steam
else
  /usr/share/gamescope-session-plus/gamescope-session-plus steam
fi
