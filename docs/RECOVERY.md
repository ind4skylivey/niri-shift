# Recovery

## Black screen after session flip

1. Switch to TTY: `Ctrl+Alt+F3`
2. Restart display manager: `sudo systemctl restart sddm`
3. If still stuck: `loginctl terminate-user "$USER"` then log in again

## Gaming Mode won't exit

- Try Super+Shift+R (evdev monitor)
- TTY: `sudo systemctl restart sddm`
- Force desktop session: `sudo sed -i 's/^Session=.*/Session=niri/' /etc/sddm.conf.d/zz-niri-shift-session.conf && sudo systemctl restart sddm`

## Keybind monitor not working

```bash
groups | grep input          # must include input
python3 -c "import evdev"    # python-evdev installed
```

Re-login after `sudo usermod -aG input "$USER"`.

## Portal / screen share broken after return

Run manually: `niri-shift-portal-recovery`

Ensure autostart includes (niri):

```kdl
spawn-sh-at-startup "niri-shift-portal-recovery"
```

## Uninstall

```bash
cd /path/to/niri-shift && ./uninstall.sh
sudo systemctl restart sddm
```
