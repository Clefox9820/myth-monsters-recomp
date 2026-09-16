#!/usr/bin/env bash
# Generate and build a native Android APK for Kid Icarus from a ROM you
# supply in roms/. The generated activity is locked to PORTRAIT orientation
# (gbrecomp defaults to landscape) so the game is usable with a portrait
# clip-on controller such as the GameSir Pocket.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROM="${1:-$ROOT/roms/Kid Icarus - Of Myths and Monsters (USA, Europe).gb}"
OUT="$ROOT/output/kid-icarus"
ANDROID_DIR="$OUT/android"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-io.gbrecompiled.kidicarus}"
ANDROID_APP_NAME="${ANDROID_APP_NAME:-Kid Icarus}"

if [ ! -f "$ROM" ]; then
  echo "ROM not found: $ROM" >&2
  echo "Place your own legally-owned ROM dump in $ROOT/roms/ or pass its path as \$1." >&2
  exit 1
fi

if [ -z "${SDL2_SOURCE_DIR:-}" ] || [ ! -f "$SDL2_SOURCE_DIR/CMakeLists.txt" ]; then
  echo "SDL2_SOURCE_DIR must point at an SDL2 source checkout (containing its root CMakeLists.txt)." >&2
  exit 1
fi

if ! command -v gradle >/dev/null; then
  echo "gradle not found on PATH. Install Gradle to build the APK." >&2
  exit 1
fi

if [ -z "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ]; then
  echo "ANDROID_HOME (or ANDROID_SDK_ROOT) is not set. Install the Android SDK/NDK first." >&2
  exit 1
fi

# 1. Apply local fixes to the gb-recompiled submodule, then build the
#    recompiler:
#    - gb-recompiled-android-jni-missing-runtime-sources.patch: upstream's
#      --android generator omits gbrt_data_mod.c, gbrt_hash.c,
#      gbrt_host_configuration.c, gbrt_port.c, gbrt_presentation.c and
#      gbrt_semantic.c from the JNI CMakeLists it writes (present in the
#      desktop CMakeLists it also emits), which fails the native link with
#      undefined gbrt_data_mod_*/gbrt_port_* symbols.
#    - gb-recompiled-android-16kb-page-size.patch: the generated JNI
#      CMakeLists doesn't force 16 KB-aligned ELF segments, so the built
#      libmain.so/libSDL2.so fail to dlopen ("unsupported page size") and
#      crash on launch on Android 15+ devices with a 16 KB kernel page size.
for PATCH in "$ROOT"/patches/gb-recompiled-*.patch; do
  [ -f "$PATCH" ] || continue
  if ! git -C "$ROOT/tools/gb-recompiled" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$ROOT/tools/gb-recompiled" apply "$PATCH"
  fi
done

cmake -G Ninja -B "$ROOT/tools/gb-recompiled/build" "$ROOT/tools/gb-recompiled"
ninja -C "$ROOT/tools/gb-recompiled/build"

# 2. Generate the Android project (desktop project is also (re)generated as
#    a side effect; only the android/ subtree is used here).
"$ROOT/tools/gb-recompiled/build/bin/gbrecomp" "$ROM" \
  -o "$OUT" --output-prefix kidicarus -j "$(nproc)" \
  --android \
  --android-package "$ANDROID_PACKAGE" \
  --android-app-name "$ANDROID_APP_NAME"

# 3. Lock the activity to portrait. gbrecomp v1 only emits
#    android:screenOrientation="landscape"; a GameSir Pocket (and similar
#    clip-on pads) hold the phone in portrait, so flip it here.
MANIFEST="$ANDROID_DIR/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "Generated manifest not found: $MANIFEST" >&2
  exit 1
fi
if grep -q 'android:screenOrientation="landscape"' "$MANIFEST"; then
  sed -i 's/android:screenOrientation="landscape"/android:screenOrientation="portrait"/' "$MANIFEST"
else
  echo "Warning: could not find the expected landscape orientation string in $MANIFEST." >&2
  echo "Check it manually and set android:screenOrientation=\"portrait\" if needed." >&2
fi

# 4. Build the debug APK.
SDL2_SOURCE_DIR="$SDL2_SOURCE_DIR" gradle -p "$ANDROID_DIR" :app:assembleDebug

APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
echo
echo "Built (portrait): $APK"
echo "Install with: adb install -r \"$APK\""
