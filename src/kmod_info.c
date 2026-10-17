// <wtl> project: mtkbt | file: src/kmod_info.c | author: watchthelight </wtl>
// The kmod_info block Xcode generates for every kext. KEXT_ID and KEXT_VERSION come from the Makefile.
#include <mach/mach_types.h>

extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

// KMOD_EXPLICIT_DECL stringifies its first argument; one extra macro level expands KEXT_ID first
#define LEGION_KMOD_DECL(id, ver, start, stop) KMOD_EXPLICIT_DECL(id, ver, start, stop)
__attribute__((visibility("default"))) LEGION_KMOD_DECL(KEXT_ID, KEXT_VERSION, _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = 0;
__private_extern__ kmod_stop_func_t *_antimain = 0;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
