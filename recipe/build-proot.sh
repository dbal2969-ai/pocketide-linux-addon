#!/usr/bin/env bash
# Cross-builds PRoot (+ its loader) and talloc for arm64-v8a Android, into runtime/out/.
# Adapted from MobileCoder's scripts/build-android-runtime-launcher.sh (same author, GPL).
#
# Output:
#   runtime/out/jniLibs/arm64-v8a/libproot.so         PRoot itself (an executable named like a library,
#   runtime/out/jniLibs/arm64-v8a/libproot-loader.so  so Android extracts it to nativeLibraryDir, the
#   runtime/out/jniLibs/arm64-v8a/libtalloc.so        only app folder it lets apps execute from)
#   runtime/out/assets/licenses/                      notices copied into the APK
#
# Needs: an Android NDK (ANDROID_NDK_HOME, ANDROID_NDK_LATEST_HOME, or ANDROID_HOME/ndk/<ver>),
# git, curl, make, patch, readelf, awk, python3 (talloc's waf).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API=26
PROOT_URL="https://github.com/termux/proot.git"
PROOT_TAG="v5.1.107.96"
PROOT_REVISION="a179d3e8a4e045aaa1fb8cc3284f23509d96d353"
TALLOC_VERSION="2.5.0"
TALLOC_SHA256="912afa237510ae542a7733998eb18a12bcda35ab6729c8e2ddb43e8d0ebab007"
WORK="${POCKETIDE_RUNTIME_WORK:-$HERE/work}"
OUT="$HERE/out"
JOBS="${JOBS:-2}"

NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_LATEST_HOME:-}}"
if [[ -z "$NDK" ]]; then
    SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
    NDK="$(ls -d "$SDK"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
fi
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="$TOOLCHAIN/aarch64-linux-android$API-clang"
[[ -x "$CC" ]] || { echo "No usable Android NDK found (looked for $CC)." >&2; exit 1; }
echo "Using NDK: $NDK"

mkdir -p "$WORK" "$OUT"
WORK="$(cd "$WORK" && pwd)"

# --- sources -------------------------------------------------------------
PROOT_SRC="$WORK/proot-src"
if [[ ! -d "$PROOT_SRC/.git" ]]; then
    rm -rf "$PROOT_SRC"
    git clone --quiet --depth 1 --branch "$PROOT_TAG" "$PROOT_URL" "$PROOT_SRC"
fi
[[ "$(git -C "$PROOT_SRC" rev-parse HEAD)" == "$PROOT_REVISION" ]] || { echo 'Unexpected PRoot revision.' >&2; exit 1; }

TALLOC_TGZ="$WORK/talloc-$TALLOC_VERSION.tar.gz"
if [[ ! -f "$TALLOC_TGZ" ]]; then
    curl --fail --location --retry 3 --proto '=https' \
        "https://www.samba.org/ftp/talloc/talloc-$TALLOC_VERSION.tar.gz" -o "$TALLOC_TGZ.partial"
    mv "$TALLOC_TGZ.partial" "$TALLOC_TGZ"
fi
printf '%s  %s\n' "$TALLOC_SHA256" "$TALLOC_TGZ" | sha256sum --check --status || {
    echo 'talloc checksum mismatch.' >&2; rm -f "$TALLOC_TGZ"; exit 1; }

# --- talloc --------------------------------------------------------------
TALLOC_DIR="$WORK/talloc-$TALLOC_VERSION"
PREFIX="$WORK/talloc-prefix"
rm -rf "$TALLOC_DIR" "$PREFIX"
tar -xzf "$TALLOC_TGZ" -C "$WORK"
mkdir -p "$PREFIX/include"
export CC STRIP="$TOOLCHAIN/llvm-strip"
export CFLAGS="-O2 -fPIC"
export LDFLAGS='-Wl,-z,max-page-size=16384'
(
    cd "$TALLOC_DIR"
    ./configure --prefix="$PREFIX" --disable-rpath --disable-python --cross-compile \
        --cross-answers="$HERE/talloc-cross-answers.txt"
    make -j"$JOBS"
)
cp "$TALLOC_DIR/talloc.h" "$PREFIX/include/talloc.h"
TB="$TALLOC_DIR/bin/default"
"$CC" -shared -Wl,-soname,libtalloc.so -Wl,-z,max-page-size=16384 -Wl,-z,noexecstack \
    -o "$TB/libtalloc.so" "$TB/talloc.c.6.o" "$TB/lib/replace/replace.c.2.o" -ldl
[[ -f "$TB/libtalloc.so" ]] || { echo 'talloc did not produce libtalloc.so.' >&2; exit 1; }

# --- proot ---------------------------------------------------------------
BUILD="$WORK/proot-build"
rm -rf "$BUILD"; mkdir -p "$BUILD"
(
    cd "$BUILD"
    export LOADER_LDFLAGS='-Wl,-z,max-page-size=16384'
    make -f "$PROOT_SRC/src/GNUmakefile" -f "$HERE/proot-build.mk" -j"$JOBS" \
        CC="$CC" STRIP="$TOOLCHAIN/llvm-strip" OBJCOPY="$TOOLCHAIN/llvm-objcopy" OBJDUMP="$TOOLCHAIN/llvm-objdump" \
        'COMPILE=$(CC) $(CPPFLAGS) $(CFLAGS) -MD -c $< -o $@' \
        HAS_LOADER_32BIT= \
        "POCKETIDE_RUNTIME_ROOT=$HERE" \
        "POCKETIDE_PROOT_SOURCE=$PROOT_SRC" \
        "GIT=sh '$HERE/proot-git-version.sh'" \
        "CPPFLAGS=-D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -DARG_MAX=131072 -I. -I$PROOT_SRC/src -I$PREFIX/include" \
        "LDFLAGS=-L$TB -ltalloc -pie -Wl,-rpath,'\$\$ORIGIN' -Wl,-z,max-page-size=16384,-z,noexecstack" \
        "PROOT_UNBUNDLE_LOADER=/pocketide-runtime-loader"
)

# --- output --------------------------------------------------------------
rm -rf "$OUT"
LIBS="$OUT/jniLibs/arm64-v8a"
mkdir -p "$LIBS" "$OUT/assets/licenses"
cp "$BUILD/proot" "$LIBS/libproot.so"
cp "$BUILD/loader/loader" "$LIBS/libproot-loader.so"
cp "$TB/libtalloc.so" "$LIBS/libtalloc.so"
cp "$PROOT_SRC/COPYING" "$OUT/assets/licenses/proot-COPYING.txt"
cp "$TALLOC_DIR/LICENSE" "$OUT/assets/licenses/talloc-LICENSE.txt"

RE="$TOOLCHAIN/llvm-readelf"
# Capture readelf's output before searching it. Piping into "grep -q" under pipefail can fail at
# random: grep stops at the first match, readelf gets SIGPIPE on its next write, and the pipe reports an error.
for b in "$LIBS"/*.so; do
    hdr="$("$RE" -h "$b")"
    [[ "$hdr" == *"Machine:"*"AArch64"* ]] || { echo "$b is not AArch64:" >&2; echo "$hdr" >&2; exit 1; }
done
phdrs="$("$RE" -l "$LIBS/libproot.so")"
[[ "$phdrs" == *"/system/bin/linker64"* ]] || { echo 'libproot.so is not a PIE executable' >&2; exit 1; }
dyn="$("$RE" -d "$LIBS/libproot.so")"
[[ "$dyn" == *"[libtalloc.so]"* ]] || { echo 'libproot.so does not link libtalloc.so' >&2; exit 1; }
echo "Built:"; ls -l "$LIBS"
