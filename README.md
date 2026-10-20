# MtkBt: MediaTek MT7925 Bluetooth firmware loader for macOS Hackintosh

> **Heads up:** a good portion of this code is AI generated. I do understand how it works,
> and I'm happy to explain any of it. If something looks wrong or you have a question,
> open an issue or ping me on Discord (`watchthelight`).

Bluetooth for the MediaTek MT7925 (Filogic 360, the Wi-Fi 7 card in many 2025 laptops and the AMD RZ717 on AM5
boards) on a Hackintosh. The card's Bluetooth half is a USB device (`0489:E111` on the Legion, 20 other ids below)
that enumerates as a normal HCI controller but answers nothing until its RAM code has been downloaded. macOS has no
loader for MediaTek parts, so `bluetoothd` sees an empty controller. MtkBt downloads the firmware, turns the Bluetooth
function on and then lets go of the interface, and from there `bluetoothd` (with BlueToolFixup) drives it from user
space like any third-party USB dongle: pairing, AirPods, LE devices. For OpenCore on macOS Sequoia 15 and Tahoe 26;
written for a Lenovo Legion 5 15IAX10, confirmed on an ASRock X870 too.

## The MT7925 set

| Repo | What it does |
|---|---|
| [mt7925-hackintosh-wifi](https://github.com/watchthelight-labs/mt7925-hackintosh-wifi) | the Wi-Fi driver for the same card (cards table, comparison with SimpleMtkWlan) |
| [mt7925-hackintosh-wifi-native](https://github.com/watchthelight-labs/mt7925-hackintosh-wifi-native) | macOS's own Wi-Fi menu on top of the driver, no client app |
| mt7925-hackintosh-bluetooth (this one) | the Bluetooth firmware loader |
| [LegionBtFix](https://github.com/watchthelight-labs/LegionBtFix) | on Tahoe 26.7.1: two `bluetoothd` patches the MT7925 needs (crash loop on LE connect, silent AirPods) |

A complete EFI that uses the set: [Legion-5-15IAX10-OpenCore](https://github.com/watchthelight-labs/Legion-5-15IAX10-OpenCore).

## Status

| Version | Tested on | Result |
|---|---|---|
| 0.2.0 | Legion 5 15IAX10, macOS 26.7.1 (25G241), OpenCore 1.0.8, BlueToolFixup 2.7.2 | controller on at every boot since 2026-10-16; AirPods Pro pair, connect and play; `MtkBtState` = `ready`, 3 sections and 447,872 bytes sent, about 20 s from open to close on the current boot |
| 0.1.0 | same laptop, macOS 15.8.1 (24H32) | first version that brought the controller up on cold boots |

What the firmware answers for the FUNC_CTRL status word is not what Linux expects: this chip and firmware (build 20260813113236) return `0xffff` and Bluetooth still comes on, so the value is only recorded.

The MT7925 has two things `bluetoothd` on macOS 26.7.1 does not expect (an LE connection quirk that crash-loops `bluetoothd`, and a Read Clock reply that leaves AirPods silent). Those are not firmware loading problems and live in a separate Lilu plugin, [LegionBtFix](https://github.com/watchthelight-labs/LegionBtFix). You want both.

## What it can't do

- It only loads firmware. Everything after that (pairing, audio, LE) is Apple's `bluetoothd` with BlueToolFixup's patches, and whatever the MT7925 firmware does with it.
- Only chip id 0x7925 is touched; anything else on that USB id is left alone.
- The half-loaded recovery path (subsystem reset after a warm reboot that left the firmware running) is implemented from the Linux driver but has not been seen to trigger on this laptop since 0.2.0, so it is untested on real hardware.
- No sleep and wake handling (the laptop this runs on has sleep disabled). At power off and restart it sends FUNC_CTRL 0 so the next boot starts clean.
- Tested on one laptop and one firmware build.

## Which cards match

MT7925 cards from different makers carry different USB ids for the Bluetooth half. 0.2.2 matches every id the Linux
`btusb` driver lists for the MT7925 (2026-10): Foxconn `0489:E111 E113 E118 E11E E124 E139 E13A E0FA E10F E110 E116 E14E
E14F E150 E151`, IMC Networks `13D3:3588 3602 3603 3604`, MediaTek `0E8D:8C38`, plus MediaTek `0E8D:0717`, the AMD RZ717
card on AM5 desktop boards (ASRock X870 Steel Legend WiFi and others). Tested: `0489:E111` (the Legion 5 15IAX10) and
`0E8D:0717` (ASRock X870 Steel Legend WiFi, macOS 26.7.1, controller On as THIRD_PARTY_DONGLE). The firmware and the
loading protocol are the same for all of them. To see what your card reports:

```
ioreg -p IOUSB -l -w0 | grep -E '"USB Product Name"|"idVendor"|"idProduct"'
```

(ids print in decimal: 1161 = 0x0489, 5075 = 0x13D3, 3725 = 0x0E8D; 0x0717 is 1815). No MediaTek device in that list
means the USB port it sits on is not in your USB map, not a driver problem: fix the map first. On AMD desktop boards
check that USBToolBox actually attached to the chipset controller (a `UTB Version` property on it in ioreg); a map made
on Windows can name the controller by an ACPI path macOS never exposes, and then the chipset ports stay at defaults.
A MediaTek id that is not in the list above: open an issue with the output and I will add it.

0.2.2 also sets the MT7925 sleep protection bypass that Linux added for the `0E8D:0717` flavour (see the changelog):
with the protection active the chip takes the WMT download command and never answers. It is written for every card as a
precaution; the Legion's `0489:E111` and the first `0717` report both loaded their firmware without it, and a card that
does not answer the register read simply carries on.

If `MtkBtState` is `ready` and `system_profiler SPBluetoothDataType` still shows the placeholder controller (Chipset
`BCM_4350C2`, Address NULL), the loader did its job and `bluetoothd` is not adopting the dongle: check the two NVRAM
keys from the installation steps (`nvram -p | grep -i bluetooth` must list both), then the BlueToolFixup load.

## Installation

1. Get `MtkBt.kext` from the [releases](../../releases), or build it (below). The release zip carries `LICENSE`, `NOTICE.md` and `LICENSES/` because the licences require them next to the binary.
2. Install BlueToolFixup (from acidanthera's BrcmPatchRAM release), which needs Lilu. Its changelog for 2.7.0 asks for two NVRAM keys so `bluetoothd` accepts a third-party controller; add them to `NVRAM > Add` and `NVRAM > Delete` under `7C436110-AB2A-4BBB-A880-FE41995C9F82`:

   ```
   bluetoothExternalDongleFailed      Data  00
   bluetoothInternalControllerInfo    Data  0000000000000000000000000000 (exactly 14 zero bytes, 28 hex digits; 16 bytes makes bluetoothd log "CFDataGetLength(internalControllerInfoRef) != 14" and fall back to the UART placeholder)
   ```

3. Copy the kext to `EFI/OC/Kexts/` and add it to `config.plist`, `Kernel > Add`, after Lilu and BlueToolFixup:

   ```
   BundlePath      MtkBt.kext
   ExecutablePath  Contents/MacOS/MtkBt
   PlistPath       Contents/Info.plist
   MinKernel       21.0.0
   MaxKernel       (empty)
   Enabled         true
   ```

   It depends only on IOUSBHostFamily and the kernel KPIs, not on Lilu.
   On macOS 26.7.1 (25G241) also add [LegionBtFix](https://github.com/watchthelight-labs/LegionBtFix) after BlueToolFixup. Without it `bluetoothd` crashes every few seconds once an LE device is around (the MT7925 rejects an LE connection that uses a random address `bluetoothd` never set), and Bluetooth turns itself off a moment after it comes up. Seen on the Legion and on an ASRock X870.

4. Make sure the USB port the Bluetooth device sits on is enabled in your USB map. On the Legion 5 15IAX10 it is `HS14`, which Lenovo's firmware marks as not connectable, so the port needs a `_UPC` patch (in the OpenCore config of [Legion-5-15IAX10-OpenCore](https://github.com/watchthelight-labs/Legion-5-15IAX10-OpenCore)).
5. Reboot and check:

   ```
   kmutil showloaded | grep -E 'MtkBt|BlueToolFixup'
   ioreg -rc MtkBt -l | grep MtkBt
   system_profiler SPBluetoothDataType | head -20
   ```

   Expected on a cold boot: `MtkBtState` = `ready`, `MtkBtChipId` ending in 7925 (31013 decimal), `MtkBtSectionsSent` = 3, `MtkBtBytesSent` = 447872, and `system_profiler` shows a real address, State On and Chipset `THIRD_PARTY_DONGLE` instead of a placeholder controller with Address NULL. After a restart, skipped sections or a `MtkBtWarmPath` value are normal.
6. If `MtkBtState` is `error`, `MtkBtLog` and `MtkBtStep` say where it stopped. Rollback: set `Enabled` to false on the MtkBt entry (and BlueToolFixup). Nothing is written to flash or to the chip's non-volatile storage.

## Registry properties

`ioreg -rc MtkBt -l | grep MtkBt`

| Property | Meaning |
|---|---|
| `MtkBtState` | `starting`, `loading`, `ready`, `error`, `stopped`, `off` (FUNC_CTRL 0 sent) |
| `MtkBtTries` | download passes in this start (1 normally, up to 3 with the half-loaded recovery) |
| `MtkBtLastError` | last error line; kept after a successful recovery, so it shows what triggered it |
| `MtkBtStep` | last step entered: `open`, `chip id`, `slpprot bypass`, `download`, `hci probe`, `subsys reset`, `ep reset option`, `func ctrl`, `close`, `done` |
| `MtkBtLog` | every step and error, `;` separated (first 1.5 KB kept) |
| `MtkBtVersion` | kext version |
| `MtkBtFirmware`, `MtkBtFirmwareSha256`, `MtkBtFirmwareBytes` | the embedded blob |
| `MtkBtFirmwareBuild`, `MtkBtFirmwareHwSw` | build time and hw/sw version from the blob header |
| `MtkBtChipId`, `MtkBtFwVersion`, `MtkBtFwFlavor` | read from the chip |
| `MtkBtEndpoints` | interrupt IN, bulk IN, bulk OUT addresses of interface 0 |
| `MtkBtOpenTries` | attempts until the interface opened |
| `MtkBtSections`, `MtkBtSectionsSent`, `MtkBtSectionsSkipped`, `MtkBtBytesSent`, `MtkBtBlocksSent` | download counters |
| `MtkBtFuncCtrlStatus` | status word of the FUNC_CTRL event |
| `MtkBtWarmPath`, `MtkBtSubsysReset` | only set when the warm-reboot handling ran |
| `MtkBtSlpProt` | sleep protection bypass: `bypass set`, `was already bypassed`, `read failed`, `write failed` |
| `MtkBtFuncOff` | where FUNC_CTRL 0 was sent (`stop`, `restart`, `power off`) or `failed` |
| `MtkBtIntrPackets` | HCI event packets read and dropped during setup |
| `MtkBtElapsedMs` | time from open to close |

## Building

```
tools/build-mac.sh      # macOS with the Xcode Command Line Tools; out/MtkBt.kext, prints the sha256
```

`tools/gen_firmware.py` embeds `firmware/BT_RAM_CODE_MT7925_1_1_hdr.bin` after checking it against `firmware/SHA256SUMS`. The 0.2.0 release binary (sha256 `4f982556a6dd0edc...`, full value in the release notes) is the file that has been running on the test laptop; a clean build of this tree with Apple clang 17 reproduces it.

## How it works

On start, in its own kernel thread so boot is never held up: open interface 0, keep a read running on the interrupt endpoint so events cannot back up, read the chip id, send each firmware section through WMT PATCH_DWNLD (skipping sections the chip reports as already loaded), write the endpoint reset option, send WMT FUNC_CTRL 1, close the interface. WMT commands are HCI vendor command 0xFC6F as a class request on the control endpoint; the WMT event is polled with a vendor IN request. The warm-reboot handling and the exact sequence are in [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Credits

- Linux **btmtk** (`drivers/bluetooth/btmtk.c`, MediaTek, ISC): the whole procedure and every register and opcode.
- **itlmt7925 / MtkBtFw** by thanhnndev and contributors (Clear BSD): the interface match, the open / work / close shape and the interrupt drain were adapted from it; their notice stays in `src/MtkBt.cpp`.
- **BlueToolFixup** (acidanthera BrcmPatchRAM, Dhinak G): what makes `bluetoothd` accept the controller afterwards.
- MediaTek firmware from linux-firmware, unmodified.

## Licence

ISC, except the parts adapted from MtkBtFw (Clear BSD, notice in `src/MtkBt.cpp` and `LICENSES/`). The firmware is MediaTek's under `LICENSES/LICENCE.mediatek`. `LICENSE`, `NOTICE.md` and `LICENSES/` must travel with any built copy of the kext.
