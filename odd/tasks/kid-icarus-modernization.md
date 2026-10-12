# Kid Icarus modernization (runtime enhancements)

## Objective
Make the recompiled Kid Icarus: Of Myths and Monsters feel modern on an Android phone in
portrait (GameSir Pocket or touch), without touching game logic.

## Problem / why
The runtime reproduces DMG limits faithfully: sprite flicker (10 sprites/line), raw 4-shade
image, no rewind, and in portrait the area below the 10:9 image is wasted while there are no
touch controls.

## Scope (authorized by user, 2026-10-12: "haz las 4")
1. Unlimited sprites per scanline (no flicker), toggleable.
2. Image: new palettes incl. per-layer colorization (BG / OBJ0 / OBJ1), LCD-grid filter,
   persisted video settings.
3. Rewind (hold to rewind) with in-memory snapshots.
4. Android portrait touch controls in the area below the game image.

Out of scope: widescreen (counterproductive in portrait; runtime support is prototype-only),
gameplay native patches.

## Constraints
- All changes live in the `tools/gb-recompiled` submodule and ship as
  `patches/gb-recompiled-runtime-modernization.patch` (applied last, alphabetical), generated
  with `rtk proxy git diff <baseline>` (plain `git diff` is mangled by the rtk hook).
  Baseline = `git stash create` of the submodule after the 5 existing patches.
- Do not change `GBPPU` / savestate layout (savestates embed `sizeof(GBPPU)`).
- Keep `visible_sprite_count` capped at 10 for mode-3 timing; extra sprites are render-only.
- Android builds from a copied runtime (`output/kid-icarus/runtime`); rebuild via
  `source ~/toolchains/env.sh && bash scripts/build-android.sh`.
- No commits: user declined committing on 2026-10-12; changes stay in the working tree.

## Tasks
- [x] T1 Unlimited sprites (ppu.c render-only overflow list, `gbrt_unlimited_sprites` flag,
      menu toggle, setting `video.unlimited_sprites`, default on). Route: delegated writer.
- [x] T2 Palettes + colorization + LCD grid + persist palette/filter/scale/LCD settings.
      Route: delegated writer.
- [x] T3 Rewind: buffer-based state save/load, ring buffer (~10 s), hold binding
      (keyboard Backspace, controller left trigger), audio reset after rewind.
      Route: delegated writer.
- [x] T4 Portrait touch controls: game image anchored to top in portrait, D-pad/A/B/
      Start/Select + rewind/fast-forward buttons below, SDL finger events -> touch joypad mask,
      auto-hide when a controller is attached. Route: delegated writer.
- [ ] T5 Build APK, install on phone, verify on device (screenshots + logcat).

## Acceptance criteria
- Builds cleanly for Android (assembleDebug) with all 6 patches applied.
- Game boots to title on the moto g86 without crash; each feature visible/usable on device.
- Existing savestate files remain loadable (GBPPU unchanged).

## Checks
- Test-first exception: runtime tests need SDL2 on host CMake (tests/CMakeLists.txt gates on
  `TARGET gbrt`), unavailable on this Windows host; verification is the Android build plus
  on-device functional checks.

## Progress / evidence
(updated per task)
- T1: ppu.c file-static render sprite list (up to 40, owner/ly-guarded fallback to the
  10-cap timing list), `gbrt_unlimited_sprites` (gbrt.c/gbrt.h, default true), menu checkbox
  + `video.unlimited_sprites`. NDK clang -fsyntax-only (aarch64-linux-android24) on ppu.c,
  gbrt.c, platform_sdl.cpp: exit 0.
- T2: palettes "Kid Icarus Sky", "Pocket Gray", "Colorized (BG / OBJ0 / OBJ1)" (per-pixel
  layer from ppu.c file-static `ppu_layer_buffer` via `ppu_get_layer_buffer()`, snapshotted
  with each guest frame; DMG only). "LCD Grid" checkbox draws translucent pixel-boundary
  rects over the viewport when scale >= 3. Persisted `video.palette`, `video.filter`,
  `video.scaling`, `video.lcd_grid` (Reset Display now also saves). Syntax check
  platform_sdl.cpp, ppu.c: exit 0.
- T3: gbrt.c savestate refactored to `gb_context_state_size` / `gb_context_save_state_buffer` /
  `gb_context_load_state_buffer` (header validated before any state change); file functions
  reuse them (same on-disk format). platform_sdl.cpp ring of 150 lazily malloc'd slots,
  snapshot every 4 guest frames in `gb_platform_render_frame`, hold action "Rewind (Hold)"
  (`rewind`, Backspace / left trigger) restores newest snapshot per frame, mutes the audio
  callback and resets the output buffer; cleared on slot load / context register, freed on
  disable / shutdown. Defaults moved: Select keyboard = Right Shift only, Toggle Max Speed
  controller = none (keyboard ` kept); legacy prefs without a `rewind` entry drop Select=Backspace
  and MaxSpeed=LT. Setting `rewind.enabled` (default 1) + menu checkbox. Syntax check
  platform_sdl.cpp, gbrt.c: exit 0.
- T4: platform_sdl.cpp touch block (before `update_game_viewport`): portrait + touch enabled
  -> image gets the top 60% of the window, anchored at y=0 (no SDL2 safe-area API), controls
  below: D-pad (8-way, sticky per finger), A/B (slide), SELECT/START pills, REW/FF hold
  buttons and a MENU button. SDL_FINGERDOWN/MOTION/UP tracked by finger id (10 max) ->
  `g_touch_joypad_dpad/buttons` ANDed in `update_effective_joypad_state`, joypad IRQ on new
  presses; REW/FF drive the same hold state as the bindings. Drawn with the ImGui
  background draw list; hidden while the menu is open. Synthesized touch->mouse events are
  kept for the ImGui menu and never used for game input. Setting `touch.controls`
  (auto|on|off, default auto = Android without a controller). Syntax check
  platform_sdl.cpp (Android aarch64, -Wall -Wextra): exit 0, only the pre-existing
  `has_content` warning.
- Patch: `patches/gb-recompiled-runtime-modernization.patch` regenerated with
  `rtk proxy git diff refs/odd/modernization-baseline` (5 files, +1026/-197, LF). All 6
  patches applied in alphabetical order on a pristine `git worktree` of submodule HEAD: ok.
  No new source files, so runtime/CMakeLists.txt and the JNI CMake generator are unchanged.

- T5 (partial): `scripts/build-android.sh` with all 6 patches: BUILD SUCCESSFUL, EXIT=0
  (log ~/toolchains/build2.log). Device install/verification pending (phone not connected).

- T5: adb over WiFi too unstable for install; APK served on LAN
  (python http.server 192.168.20.6:8765) and installed manually by user. User confirmed
  on device: "se ve bien" (palettes, touch controls, features working).
- T6 (user request: Colorized less monochromatic): new PPU_LAYER_WIN (window/HUD) tagged in
  ppu.c, multi-hue 4x4 ramps per layer, BG lightest shade drawn as vertical sky gradient.
  NDK syntax check ppu.c + platform_sdl.cpp ok; patch regenerated (+1050/-197); Android
  build EXIT=0. Device check pending (user).

- [x] T5 Build APK, install, verify on device.
- [ ] T6 Improved Colorized (multi-hue, HUD layer, sky gradient) — awaiting user check.

- T6 rev2 (user: "se ve verde", Pit green): BG ramp -> sand marble / periwinkle / indigo;
  OBJ1 (Pit) -> white/skin/gold/brown; OBJ0 -> white/lavender/crimson/plum. Clean rebuild
  OK, published to LAN server. Note: stopping a background build leaves gradle/gbrecomp
  running and corrupts the next build; never overlap builds.

## Next step
User verifies T6 rev2. Then, per user approval ("Si, estan bien todas esas mejoras"):
runtime batch (Palette higher in menu, hq2x/xBRZ filter, more palettes) + RAM search tool;
modernization plan Phase 0 (tile dumper + RAM finder) and Phase 1 (per-tile colorization)
pending user go-ahead.
