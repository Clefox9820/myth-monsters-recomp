# Kid Icarus: Of Myths and Monsters — GB Static Recompilation

Static recompilation of *Kid Icarus: Of Myths and Monsters* (Game Boy) into a
native desktop executable, using [gb-recompiled](https://github.com/arcanite24/gb-recompiled)
as the underlying recompiler/runtime.

This repository contains **no copyrighted game data**. You must supply your
own legally-obtained ROM dump to build and run the game.

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

Copy your own legally-dumped ROM into `roms/`, e.g.:

```
roms/Kid Icarus - Of Myths and Monsters (USA, Europe).gb
```

### 5. Generate and build the native game

```bash
./tools/gb-recompiled/build/bin/gbrecomp \
  "roms/Kid Icarus - Of Myths and Monsters (USA, Europe).gb" \
  -o output/kid-icarus --output-prefix kidicarus -j 4

cmake -G Ninja -S output/kid-icarus -B output/kid-icarus/build
ninja -C output/kid-icarus/build

./output/kid-icarus/build/kidicarus
```

`scripts/build.sh` wraps steps 3–5.

## Running without a native desktop (Wine / GameNative / Proton)

If you don't have a PC to build/run on natively, cross-compile a Windows x64
build from Linux with MinGW-w64 and run it through a Windows compatibility
layer instead — this is exactly the approach [GameNative](https://github.com/GameNative/GameNative)
(a Winlator fork) uses to run Windows x86/x64 games on Android:

```bash
./scripts/build-windows.sh
```

This produces `dist/win64/kidicarus.exe` plus the DLLs it needs (`SDL2.dll`,
`libstdc++-6.dll`, `libgcc_s_seh-1.dll`). Copy that whole folder to wherever
you'll run it:

- **GameNative on Android**: import the folder as a game, same as any other
  Windows x86/x64 title.
- **Wine/Proton on Linux**: `wine kidicarus.exe`.
- **A real Windows PC**: just double-click it.

Verified in this sandbox: the cross-compiled `.exe` was launched under Wine
in a virtual framebuffer and correctly rendered the game's title screen
(SDL2 window/renderer init, no missing-DLL or API errors). Real-device
touch/controller input mapping through GameNative has not been verified —
report back if button mapping needs adjusting for a touchscreen/gamepad.

## Status

- Recompiler builds cleanly and generates a C project from the ROM (some
  functions fall back to the bundled interpreter — expected, see
  `tools/gb-recompiled/README.md`).
- Verified headless: the generated executable runs to completion under
  `--headless --limit-frames`, and frame dumps show correct native-resolution
  (160x144) rendering, including the game's intro story text — confirming the
  ROM is decoded and executed correctly end to end.
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

*Kid Icarus* and *Game Boy* are trademarks of Nintendo. This project is not
affiliated with or endorsed by Nintendo. No ROM or other copyrighted game
asset is included in this repository; you are responsible for legally owning
and dumping your own copy of the game.
