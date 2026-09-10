## Summary

<!-- What does this PR change and why? -->

**Type:** <!-- fix | feat | docs | backend | chore -->

## Compositor tested

- [ ] Niri
- [ ] Hyprland
- [ ] Other (describe):

## Test plan

- [ ] `bash tests/run.sh`
- [ ] Round-trip Desktop → Gaming → Desktop (if session logic changed)
- [ ] Settings TUI (`niri-shift-settings`) if display/backend config touched

## Checklist

- [ ] No hardcoded user paths (`/home/...`, `$HOME` assumptions in shipped scripts)
- [ ] No Omarchy-specific dependencies or tooling
- [ ] GPL-3.0-or-later compatible (no proprietary or incompatible license additions)
- [ ] Docs updated if behavior or install steps changed
