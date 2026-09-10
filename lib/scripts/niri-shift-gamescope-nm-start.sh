#!/usr/bin/env bash
log() { logger -t niri-shift-nm "$*"; }
if systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
  log "NetworkManager already active"
  exit 0
fi
sudo -n systemctl start NetworkManager.service 2>/dev/null && log "NetworkManager started" || exit 1
