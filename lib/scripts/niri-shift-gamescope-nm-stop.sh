#!/usr/bin/env bash
log() { logger -t niri-shift-nm "$*"; }
if ! systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
  exit 0
fi
sudo -n systemctl stop NetworkManager.service 2>/dev/null && log "NetworkManager stopped" || true
if systemctl is-enabled --quiet iwd.service 2>/dev/null; then
  sudo -n systemctl start iwd.service 2>/dev/null || true
fi
