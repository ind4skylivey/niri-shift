# Compositor backend interface

Add `backends/<name>.sh` and pass `--backend <name>` to `install.sh`.

## Required functions

```bash
backend_id()                    # echo short id
backend_desktop_sddm_session()  # echo SDDM Session= for desktop
backend_validate()              # die on missing tools
backend_pre_gaming_switch()     # disable extra outputs before SDDM restart
backend_portal_wait()           # wait until compositor env is ready (exit 0/1)
backend_portal_backends()       # echo systemd units to stop before portal restart
backend_keybind_doc()           # print keybind instructions to stdout
```

## Optional

```bash
backend_autostart_snippet()     # one-line compositor autostart for portal-recovery
```

## Install wiring

`install.sh` copies the selected backend to `/usr/local/lib/niri-shift/backend.sh` and installs hooks:

- `pre-gaming-switch` → `backend_pre_gaming_switch`
- `portal-wait` → `backend_portal_wait`
- `portal-backends` → `backend_portal_backends`

## SDDM session names

| Backend | Typical `Session=` value |
|---------|--------------------------|
| niri | `niri` |
| hyprland | `hyprland` or `hyprland-uwsm` |
| gaming | `gamescope-session-steam-nm` (NiriShift desktop file) |
