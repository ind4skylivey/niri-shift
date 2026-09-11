#!/usr/bin/env bash
# @DESKTOP_SESSION@ and @GAMING_SESSION@ replaced at install time.
set -euo pipefail

CONF="/etc/sddm.conf.d/zzzz-niri-shift-autologin.conf"
DESKTOP_SESSION="@DESKTOP_SESSION@"
GAMING_SESSION="gamescope-session-steam-nm"

if [[ ! -f "$CONF" ]]; then
  echo "Error: Config file not found: $CONF" >&2
  exit 1
fi

case "${1:-}" in
  gaming)
    sed -i "s/^Session=.*/Session=${GAMING_SESSION}/" "$CONF"
    echo "Session set to: gaming mode"
    ;;
  desktop)
    sed -i "s/^Session=.*/Session=${DESKTOP_SESSION}/" "$CONF"
    echo "Session set to: desktop mode"
    ;;
  *)
    echo "Usage: $0 {gaming|desktop}" >&2
    exit 1
    ;;
esac
