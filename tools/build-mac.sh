#!/bin/bash
# <wtl> project: mtkbt | file: tools/build-mac.sh | author: watchthelight </wtl>
# Native build on macOS with the Command Line Tools SDK (no Xcode project). Output: out/MtkBt.kext
# The firmware C file comes from tools/gen_firmware.py (SHA-256 checked against firmware/SHA256SUMS).
# Nothing is loaded or installed. The build is reproducible with the same Apple clang.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist)
SDK=$(xcrun --sdk macosx --show-sdk-path)
K=$SDK/System/Library/Frameworks/Kernel.framework/Headers
OUT=out/MtkBt.kext/Contents
rm -rf out/MtkBt.kext
mkdir -p "$OUT/MacOS" out/obj out/gen
python3 -I tools/gen_firmware.py out/gen/MtkBtFirmware.c
FLAGS="-arch x86_64 -mmacosx-version-min=10.15 -mkernel -nostdinc -fno-builtin -fno-common -fno-stack-protector
 -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT -isystem $(clang -print-resource-dir)/include -I$K -O2 -Wall -Wno-unused-parameter"
clang++ $FLAGS -fapple-kext -std=gnu++17 -nostdinc++ -fno-exceptions -fno-rtti -fno-use-cxa-atexit -Wno-inconsistent-missing-override \
  -c src/MtkBt.cpp -o out/obj/MtkBt.o
clang $FLAGS -std=gnu11 -c out/gen/MtkBtFirmware.c -o out/obj/MtkBtFirmware.o
clang $FLAGS -std=gnu11 -DKEXT_ID=org.watchthelight.MtkBt -DKEXT_VERSION="\"$VERSION\"" \
  -c src/kmod_info.c -o out/obj/kmod_info.o
clang++ -arch x86_64 -mmacosx-version-min=10.15 -nostdlib -Xlinker -kext -Xlinker -export_dynamic \
  out/obj/MtkBt.o out/obj/MtkBtFirmware.o out/obj/kmod_info.o -L"$SDK/usr/lib" -lkmodc++ -lkmod -lcc_kext \
  -o "$OUT/MacOS/MtkBt"
cp Info.plist "$OUT/Info.plist"
BIN="$OUT/MacOS/MtkBt"
otool -hv "$BIN" | grep -q KEXTBUNDLE && echo "filetype: MH_KEXT_BUNDLE"
nm "$BIN" | grep -q ' _kmod_info' && echo "kmod_info: present"
if nm -u "$BIN" | grep -qE '^_{2,3}(cxa_|Unwind|gxx_)'; then echo "FAIL: C++ runtime symbols the kernel does not export"; exit 1; fi
echo "built org.watchthelight.MtkBt $VERSION: $BIN ($(stat -f %z "$BIN") bytes)"
echo "sha256: $(shasum -a 256 "$BIN" | cut -c1-64)"
