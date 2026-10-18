# Changelog

## 0.2.1 (2026-10-18)

- Matches every MT7925 Bluetooth USB id the Linux `btusb` driver knows (Foxconn 0489 family, IMC Networks 13D3 family, MediaTek 0E8D:8C38), as three personalities with `idProductArray`. 0.2.0 matched only `0489:E111`. No code change.

## 0.2.0 (2026-10-17)

- Warm-reboot handling: sections the chip reports as loaded are skipped; a half-loaded chip gets the MT7925 subsystem reset and a fresh download (at most 3 passes); a firmware that already answers HCI is left alone.
- WMT FUNC_CTRL 0 at power off, restart and `stop()`, so the next boot starts with the function off.
- More registry properties (`MtkBtStep`, `MtkBtLog`, `MtkBtTries`, `MtkBtWarmPath`, `MtkBtFuncOff`).
- Running daily on macOS 26.7.1 since 2026-10-16.

## 0.1.0 (2026-10-16)

- First version: firmware download, endpoint reset option, FUNC_CTRL 1, close. Brought the controller up on cold boots of macOS 15.8.1.
