# Notices and sources

## Linux btmtk (ISC)
The procedure in `src/MtkBt.cpp` is ported from `drivers/bluetooth/btmtk.c` and `btmtk.h` in Linux v6.18 (https://github.com/torvalds/linux, tag v6.18), SPDX ISC, Copyright (C) 2021 MediaTek Inc.: `btmtk_usb_setup` (the 0x7925 case), `btmtk_setup_firmware_79xx`, `btmtk_usb_hci_wmt_sync`, `btmtk_usb_reg_read`, `btmtk_usb_uhw_reg_read` / `_write`, `btmtk_usb_subsys_reset`, and the register and opcode constants.

## itlmt7925 / MtkBtFw (BSD-3-Clause-Clear)
Cross-checked against and partly adapted from `kexts/MtkBtFw/MtkBtFw.cpp` of https://github.com/thanhnndev/ga403wm-hackintosh, Copyright (c) 2026 thanhnndev and contributors, The Clear BSD License. Adapted parts: the `IOUSBHostInterface` match on interface 0, the open / work / close pattern, the descriptor walk for the interrupt endpoint and the interrupt drain. Their notice is kept in full at the top of `src/MtkBt.cpp` and in `LICENSES/BSD-3-Clause-Clear-itlmt7925.txt`; any binary distribution of MtkBt must carry it.

## Firmware
`firmware/BT_RAM_CODE_MT7925_1_1_hdr.bin` is MediaTek's, from linux-firmware (https://gitlab.com/kernel-firmware/linux-firmware, commit d5455717ead0, `mediatek/mt7925/`), unmodified, sha256 `be7c18e37221e277baaef853be3a0ba930138ee879f336ff7b185e79ab09a5c9`, redistributable under `LICENSES/LICENCE.mediatek` (for use with MediaTek devices). It is not under ISC or Clear BSD. The build embeds it in the kext.

## Related
- BlueToolFixup (acidanthera/BrcmPatchRAM, created by Dhinak G, GPL-2.0) is what lets `bluetoothd` use the controller after MtkBt has loaded its firmware. Nothing from it is in this repository.
- `src/kmod_info.c` reproduces the `kmod_info` block Xcode generates, using Apple's `KMOD_EXPLICIT_DECL` macro.

## Everything else
Copyright (C) 2026 watchthelight, ISC (`LICENSE`). A good portion of the code was written with Claude Code (Anthropic); see the note at the top of the README.
