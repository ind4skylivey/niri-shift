#!/usr/bin/env python3
"""Evdev keybind monitor: Super+Shift+R exits Gaming Mode."""
import subprocess
import sys
import syslog
import time

def log(msg, error=False):
    print(msg, file=sys.stderr if error else sys.stdout)
    syslog.syslog(syslog.LOG_ERR if error else syslog.LOG_INFO, msg)

syslog.openlog("niri-shift-keybind-monitor", syslog.LOG_PID)

try:
    import evdev
    from evdev import ecodes
except ImportError:
    log("FATAL: python-evdev not installed", error=True)
    sys.exit(1)

def find_keyboards():
    keyboards = []
    permission_errors = 0
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
            caps = device.capabilities()
            if ecodes.EV_KEY in caps:
                keys = caps[ecodes.EV_KEY]
                if ecodes.KEY_A in keys and ecodes.KEY_R in keys:
                    keyboards.append(device)
        except PermissionError:
            permission_errors += 1
        except Exception:
            continue
    if permission_errors and not keyboards:
        log(f"FATAL: Permission denied on input devices ({permission_errors})", error=True)
    return keyboards

def monitor_keyboards(keyboards):
    meta_pressed = False
    shift_pressed = False
    from selectors import DefaultSelector, EVENT_READ
    selector = DefaultSelector()
    for kbd in keyboards:
        selector.register(kbd, EVENT_READ)
    log(f"Monitoring {len(keyboards)} keyboard(s) for Super+Shift+R...")
    try:
        while True:
            for key, _mask in selector.select():
                device = key.fileobj
                try:
                    for event in device.read():
                        if event.type != ecodes.EV_KEY:
                            continue
                        if event.code in (ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA):
                            meta_pressed = event.value > 0
                        elif event.code in (ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT):
                            shift_pressed = event.value > 0
                        elif event.code == ecodes.KEY_R and event.value == 1:
                            if meta_pressed and shift_pressed:
                                log("Super+Shift+R detected! Switching to desktop...")
                                subprocess.run(["/usr/local/bin/niri-shift-switch-to-desktop"], check=False)
                                return
                except Exception as e:
                    log(f"Read error: {e}", error=True)
    except KeyboardInterrupt:
        pass
    finally:
        selector.close()

def main():
    time.sleep(2)
    keyboards = find_keyboards()
    if not keyboards:
        log("FATAL: No accessible keyboards found!", error=True)
        sys.exit(1)
    monitor_keyboards(keyboards)

if __name__ == "__main__":
    main()
