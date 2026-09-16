# Myths & Monsters — GB Static Recompilation

Static recompilation of a Game Boy title into a native desktop executable,
using [gb-recompiled](https://github.com/arcanite24/gb-recompiled) as the
underlying recompiler/runtime.

This repository contains **no copyrighted game data**. You must supply your
own legally-obtained ROM dump to build and run a game.

## How it works

```
your .gb ROM -> gbrecomp (decoder/analyzer) -> generated C project
                                             -> CMake + SDL2 -> native executable
```

`gbrecomp` decodes the SM83/LR35902 machine code, analyzes control flow, and
emits reviewable C that is linked against a shared runtime (`gbrt`) providing
the PPU, APU, input, MBC/save handling, and SDL2 presentation layer. Code
paths the static analyzer can't resolve fall back to a bundled interpreter,
so the game still runs correctly even where translation is incomplete.

## Repository layout

- `tools/gb-recompiled/` — git submodule, the recompiler + runtime (MIT).
- `roms/` — **gitignored**. Put your own ROM dump here.
- `output/` — **gitignored**. Generated C project + build output (embeds the
  ROM bytes, so it must never be committed or shared).
- `scripts/` — helper scripts to (re)build the toolchain and regenerate the game.

## Setup

### 1. Dependencies

```bash
sudo apt-get install -y cmake ninja-build g++ libsdl2-dev
```

### 2. Clone with submodules

```bash
git clone --recurse-submodules <this-repo-url>
# or, if already cloned:
git submodule update --init --recursive
```

### 3. Build the recompiler

```bash
cmake -G Ninja -B tools/gb-recompiled/build tools/gb-recompiled
ninja -C tools/gb-recompiled/build
```

### 4. Provide your ROM

Copy your own legally-dumped ROM into `roms/`, e.g. `roms/mygame.gb`.

### 5. Generate and build the native game

```bash
./tools/gb-recompiled/build/bin/gbrecomp \
  "roms/mygame.gb" \
  -o output/game --output-prefix game -j 4

cmake -G Ninja -S output/game -B output/game/build
ninja -C output/game/build

./output/game/build/game
```

`scripts/build.sh <path-to-rom>` wraps steps 3–5.

## Running without a native desktop (Wine / GameNative / Proton)

If you don't have a PC to build/run on natively, cross-compile a Windows x64
build from Linux with MinGW-w64 and run it through a Windows compatibility
layer instead — this is exactly the approach [GameNative](https://github.com/GameNative/GameNative)
(a Winlator fork) uses to run Windows x86/x64 games on Android:

```bash
./scripts/build-windows.sh
```

This produces `dist/win64/game.exe` plus the DLLs it needs (`SDL2.dll`,
`libstdc++-6.dll`, `libgcc_s_seh-1.dll`). Copy that whole folder to wherever
you'll run it:

- **GameNative on Android**: import the folder as a game, same as any other
  Windows x86/x64 title.
- **Wine/Proton on Linux**: `wine game.exe`.
- **A real Windows PC**: just double-click it.

Verified in a sandboxed test environment: a cross-compiled `.exe` was
launched under Wine in a virtual framebuffer and correctly rendered a
target game's title screen (SDL2 window/renderer init, no missing-DLL or
API errors). Real-device touch/controller input mapping through GameNative
has not been verified — report back if button mapping needs adjusting for a
touchscreen/gamepad.

## Native Android build (portrait, for clip-on controllers)

`gb-recompiled --android` generates a real ARM64 Android project, but its
manifest hardcodes `android:screenOrientation="landscape"` with no CLI flag
to change it. `patches/android-portrait-orientation.patch` flips that one
line to `portrait`, for use with clip-on portrait controllers (e.g. the
GameSir Pocket Taco, which clips to the bottom of the phone in portrait and
expects the screen upright, not sideways).

```bash
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_NDK_HOME=/path/to/android-ndk
export SDL2_SOURCE_DIR=/path/to/SDL-source-checkout   # needs android-project/
./scripts/build-android.sh
```

This produces `output/game/android/app/build/outputs/apk/debug/app-debug.apk`.
No touch controls are added — it's controller/keyboard input only, matching
upstream's "controller-first" Android scope.

**Known limitation**: building this requires downloading the Android SDK/NDK
from `dl.google.com`, which some network policies block outright (including
the sandbox this project was originally scaffolded in — see
`tools/gb-recompiled/ANDROID.md` for the full requirement list). If
`build-android.sh` can't reach `dl.google.com`, run it from a machine/environment
without that restriction.

## Status

- Recompiler builds cleanly and generates a C project from a ROM (some
  functions fall back to the bundled interpreter — expected, see
  `tools/gb-recompiled/README.md`).
- Verified headless: a generated executable runs to completion under
  `--headless --limit-frames`, and frame dumps show correct native-resolution
  (160x144) rendering, including in-game text — confirming a ROM can be
  decoded and executed correctly end to end.
- Not yet verified: full playthrough with real input/graphics on a real
  display, audio, and save/RTC persistence.

## Controls (default)

| Action | Key |
| --- | --- |
| D-pad | Arrow keys / WASD |
| A / B | Z / X |
| Start / Select | Enter / Backspace |
| Settings menu | F10 / Escape |

Full list in `tools/gb-recompiled/RUNTIME.md`.

## Legal

"Game Boy" is a trademark of its respective platform holder. This project is
not affiliated with or endorsed by any platform or game publisher. No ROM or
other copyrighted game asset is included in this repository; you are
responsible for legally owning and dumping your own copy of any game you
recompile with it.
