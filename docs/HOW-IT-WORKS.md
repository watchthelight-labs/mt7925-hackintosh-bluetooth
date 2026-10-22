# How MtkBt works

## Why a loader is needed

The MT7925's Bluetooth function is a USB device (`0489:E111` on the Legion; other cards use other ids) with three interfaces: `BT_ACL_If` (interface 0: interrupt IN for HCI events, bulk IN and OUT for ACL), `BT_SCO_If` and `BT_ISO_If`. After power-on the chip runs only its boot ROM. It enumerates fine, but HCI commands get no answer until the RAM code has been written into it through the vendor WMT protocol. Linux does that in `btmtk.c` every time the device appears. macOS has no equivalent, so without a loader `bluetoothd` sees a controller that never answers Reset and gives up.

## Where it sits in the stack

Apple's `AppleUSBHostCompositeDevice` matches the device (class EF/02/01, interface association) and sets configuration 1, which publishes the three interfaces as `IOUSBHostInterface` nubs with no driver attached. On macOS 15 and 26 there is no in-kernel Bluetooth USB transport: `bluetoothd` opens the interface from user space through IOUSBLib. So MtkBt is an interface driver on `IOUSBHostInterface`, configuration 1, interface 0, with personalities that match every MT7925 Bluetooth id Linux `btusb` knows (the 0489, 13D3 and 0E8D families, listed in the README). It opens the interface, does its work, closes it, and stays attached but idle. Apple's normal path is untouched, and `bluetoothd` later opens the same interface as if nothing had happened. A device-level driver (the BrcmPatchRAM3 approach) would have to replace the composite driver and configure the device itself for no gain.

## The sequence

Everything runs in a kernel thread started from `start()`, so the boot is never held up, and every wait has a deadline.

1. Open interface 0, retrying for up to 10 s if something else holds it (`MtkBtOpenTries`).
2. Endpoints: walk the interface descriptor for the interrupt IN, bulk IN and bulk OUT pipes (`MtkBtEndpoints`). Start a read on the interrupt IN pipe and keep it running, dropping whatever arrives (`MtkBtIntrPackets`), so events cannot back up and stall the firmware during setup.
3. Identify: vendor request 0x63 reads the chip id (register 0x70010200), firmware version (0x80021004) and flavor (0x70010020). Anything but 0x7925 ends here.
4. Sleep protection bypass (0.2.2): read `0x18011100` through the uhw path, set bit 1, write it back. The MT7925 BT core ignores WMT commands while sleep protection is active, which is the state the `0E8D:0717` card wakes up in on AM5 desktop boards; the Linux fix for that card does the same read-modify-write here and again after activation. The step is repeated after each subsystem reset. A failed access is logged in `MtkBtSlpProt` and the start goes on without it.
5. Download `BT_RAM_CODE_MT7925_1_1_hdr.bin` (embedded at build time with its SHA-256). The blob has a 32-byte header, a 64-byte global descriptor and a section map of up to 16 entries; this one has 5 sections, 3 with payload (74,176, 332,224 and 41,472 bytes). For each section: a WMT PATCH_DWNLD query carrying the 52-byte section spec, which the firmware answers with download, already loaded, or busy. Already loaded is skipped (as Linux does), busy is retried every 100 ms up to 20 times, otherwise the section goes out in 250-byte blocks with a first / middle / last flag. Then 110 ms for activation.
6. Sleep protection bypass again: activation turns the protection back on, so the same write as step 4 goes out before FUNC_CTRL.
7. Endpoint reset option: register 0x74011890 = 0x00010001, as `btmtk_usb_setup` does for the 7925.
8. FUNC_CTRL 1: turn the Bluetooth function on; the status word from the event is recorded (`MtkBtFuncCtrlStatus`).
9. Close: stop the interrupt read, close the interface, `MtkBtState` = `ready`.

WMT commands are HCI vendor command 0xFC6F sent as a class request on the default control endpoint. The WMT event (HCI event 0xE4) is read back with a vendor IN request (bRequest 1, wValue 0x30), polled for at most 2 s per command.

## Warm reboots

macOS never turns the Bluetooth function off at shutdown (Linux does, in `btmtk_usb_shutdown`), so after a restart the chip may still be running the previous boot's firmware. Two forms were seen: sections 0 and 1 answered "already loaded" and then section 2 stopped answering at block 55, with about a thousand interrupt packets of firmware chatter in between; and a first WMT query that got no event at all. 0.2.0 handles that three ways:

- A pass that fails after the chip already holds part of the firmware (a section reported loaded or sent in this pass), any failed block, and a first query without an event that HCI does not explain all count as half-loaded. Then the MT7925 subsystem reset from `btmtk_usb_subsys_reset` runs (CONNV3 reset register, endpoint reset option, UDMA interrupt status clear, poll RST_DONE for 1 s, re-read the chip id), the interface 0 endpoints are resynced with CLEAR_FEATURE(ENDPOINT_HALT), and the whole download runs again. At most 3 passes per instance (`MtkBtTries`), and since 0.2.4 at most 2 resets per boot across all MtkBt instances. Linux follows the reset with a USB port reset and re-enumeration; MtkBt does not, but on some boards the reset itself drops the chip off the USB bus and it comes back as a new device with a new MtkBt instance. The per-boot cap is what stops that from turning into a reset loop (#1).
- If the very first WMT query gets no event, an HCI Read Local Version (0x1001) is sent. A Command Complete on the interrupt endpoint means the firmware is up: the device is left as it is and the state is `ready` (`MtkBtWarmPath` says so).
- At system power off and restart (IOPMrootDomain priority interest, `kIOMessageSystemWillPowerOff` / `kIOMessageSystemWillRestart`) and in `stop()`, the kext opens the interface again and sends WMT FUNC_CTRL 0, so the next boot starts with the function off and the WMT channel quiet. By then launchd has ended `bluetoothd`; if the interface is still taken, or the provider is going away, the step is skipped (`MtkBtFuncOff`).

Since 0.2.0 the laptop this runs on has booted with `MtkBtTries` = 1 every time, so the reset path is implemented from the Linux driver but not yet exercised on hardware.

## Failures and known risks

Any failure ends with `MtkBtState` = `error`, the step name in `MtkBtStep`, the error line in `MtkBtLastError`, the whole trace in `MtkBtLog`, and the interface closed. There are no deliberate panics.


- The uhw register reads (request type 0xDE) run on every start since 0.2.2 (the sleep protection bypass) and on the subsystem reset path. If IOUSBHost rejects the odd recipient bits, the bypass is skipped with a `uhw ... read failed` line and `MtkBtSlpProt` = `read failed`, and the reset path fails cleanly the same way.
- If `bluetoothd` opens the interface before MtkBt (it should not at boot, since kexts start first), MtkBt waits 10 s and gives up with `interface busy`.
- The FUNC_CTRL status word this firmware returns is `0xffff`, not the `0x0404` Linux checks for, and Bluetooth still comes on. The value is recorded, not acted on.
