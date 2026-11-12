# PocketIDE Linux add-on

A small Android app (`dev.pocketide.linux`) with no code of its own. It holds three files that let
[PocketIDE](https://github.com/dbal2969-ai)'s MIT edition run Alpine Linux on the phone:

| File | What it is | Licence |
|---|---|---|
| `libproot.so` | [PRoot](https://github.com/termux/proot) (Termux's fork), runs Linux programs without root | GPL-2.0-or-later |
| `libproot-loader.so` | PRoot's loader | GPL-2.0-or-later |
| `libtalloc.so` | [talloc](https://talloc.samba.org/), a memory library PRoot uses, linked as a shared library | LGPL-3.0-or-later |

They are named like libraries only because Android 10 and later let apps run programs only from an installed APK's library
folder. PocketIDE's GPL edition carries the same files inside its own APK. The MIT edition carries no GPL code, so it downloads
this add-on when you tap **Tools & Linux → Get the Linux add-on**.

## Download

The newest APK is in [Releases](../../releases/latest) as `PocketIDE-Linux-addon.apk`; PocketIDE downloads it from there.
PocketIDE uses the add-on only when it is signed with the same key as PocketIDE itself, so a copy signed by anyone else is
ignored.

## Source

Each release carries `PocketIDE-Linux-addon-source.tar.gz`: the exact PRoot source (revision
`a179d3e8a4e045aaa1fb8cc3284f23509d96d353`, tag `v5.1.107.96`), the talloc 2.5.0 release tarball, and the recipe that built
them. The same recipe is in this repository:

- `recipe/` — `build-proot.sh` cross-builds PRoot, its loader and talloc for arm64-v8a with the Android NDK (API 26);
  `SOURCES.json` pins every source with its revision or SHA-256; the `.mk`, `.patch`, `.awk` and `.txt` files are the changes
  and build answers it applies.
- `linux-addon/` — the Gradle module that packs the three files into the APK (`hasCode="false"`).

To rebuild: install the Android NDK, run `bash recipe/build-proot.sh` (output in `recipe/out/`), then build `linux-addon` with
`recipe/out/jniLibs` as its `jniLibs` folder. An add-on you build and sign yourself works with a PocketIDE build signed with
the same key.

## Licences

`LICENSES/` holds PRoot's `COPYING` (GPL-2.0), the GPL-2.0, LGPL-3.0 and GPL-3.0 texts. The APK also carries PRoot's and
talloc's notices. The recipe files in this repository are GPL-2.0-or-later, like PRoot.
