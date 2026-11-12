# Overlay included after PRoot's own src/GNUmakefile (see build-proot.sh).
# Adapted from MobileCoder's runtime/proot-build.mk (GPL), by the same author.

extension/ashmem_memfd/ashmem_memfd.o: override CPPFLAGS += -include string.h

# Also kill all tracees when PRoot itself gets SIGTERM, so stopping a command never leaves orphans.
tracee/event-pocketide.c: $(POCKETIDE_PROOT_SOURCE)/src/tracee/event.c $(POCKETIDE_RUNTIME_ROOT)/proot-termination.patch
	mkdir -p tracee
	patch -o $@ $< < $(POCKETIDE_RUNTIME_ROOT)/proot-termination.patch

tracee/event.o: tracee/event-pocketide.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -MD -c tracee/event-pocketide.c -o $@

# Upstream runs a relative awk path that only exists inside the source tree.
loader/loader-info.c: loader/loader
	readelf -s $< | awk -f $(POCKETIDE_RUNTIME_ROOT)/proot-loader-info.awk > $@
