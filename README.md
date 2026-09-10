# NiriShift

Deck Mode for **Niri** and other Wayland compositors: SDDM session flip between your desktop and Steam Big Picture via ChimeraOS `gamescope-session`.

Inspired by [DeckShift](https://github.com/28allday/deckshift) (Omarchy/Hyprland), reimplemented without Omarchy dependencies.

## Features

- **Session flip**: desktop (Niri) ↔ Gaming Mode (`gamescope-session-steam`) through SDDM restart
- **Compositor backends**: `niri` (first-class), `hyprland` (adapter stub)
- **Exit shortcut**: Super+Shift+R inside Gaming Mode (evdev monitor)
- **Settings TUI**: `niri-shift-settings` (gum) for display, refresh, multi-monitor
- **Portal recovery**: optional autostart hook after returning from gaming

## Requirements

- Arch Linux (or derivative) with **SDDM**
- **Niri** (or Hyprland with `--backend hyprland`)
- AUR: `gamescope-session-git`, `gamescope-session-steam-git`
- Groups: `video` (session switch sudo), `input` (keybind monitor)

## Install

```bash
git clone https://github.com/ind4skylivey/niri-shift.git
cd niri-shift
./install.sh --backend niri --wire-autostart
```

Re-login after install if you were added to `input` or `video`.

## Keybind (Niri)

Add to `~/.config/niri/modules/keybinds.kdl`:

```kdl
Mod+Shift+G hotkey-overlay-title="Gaming Mode" { spawn-sh "niri-shift-switch-to-gaming"; }
```

## Usage

| Action | Command |
|--------|---------|
| Settings | `niri-shift-settings` |
| Enter Gaming Mode | `niri-shift-switch-to-gaming` or keybind |
| Exit Gaming Mode | Super+Shift+R (in gaming session) |
| CLI | `niri-shift help` |

## Uninstall

```bash
./uninstall.sh
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the DeckShift audit and Hyprland→Niri mapping.

## Contributing

Adapters for Sway and other compositors welcome: add `backends/your-compositor.sh` implementing the backend interface documented in `docs/ARCHITECTURE.md`.

## License

GNU General Public License v3.0 or later (GPL-3.0-or-later). See [LICENSE](LICENSE).

## Recovery

Black screen after switch: switch to TTY (Ctrl+Alt+F3), then:

```bash
sudo systemctl restart sddm
# or
loginctl terminate-user "$USER"
```
