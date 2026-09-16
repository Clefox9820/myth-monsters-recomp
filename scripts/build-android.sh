#!/usr/bin/env bash
# Build an Android APK from a user-supplied ROM using gb-recompiled's
# --android output, patched to lock the app in portrait orientation
# (for clip-on portrait controllers like the GameSir Pocket Taco; the
# upstream default is landscape-only with no CLI flag to change it).
#
# Requirements (not installed by this script):
#   - Android SDK (platform-tools, platform android-34, build-tools) with
#     ANDROID_HOME/ANDROID_SDK_ROOT set
#   - Android NDK, with ANDROID_NDK_HOME set
#   - Gradle 8.x+ on PATH (the generated project has no Gradle wrapper)
#   - An SDL2 *source* checkout (not the mingw devel package) with its
#     android-project/ directory, e.g.:
#       git clone --branch release-2.30.9 https://github.com/libsdl-org/SDL SDL2-src
#     Set SDL2_SOURCE_DIR to that checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROM="${1:-}"
PACKAGE="${ANDROID_PACKAGE:-com.mythmonstersrecomp.game}"
APP_NAME="${ANDROID_APP_NAME:-Myths and Monsters Recomp}"
GEN="$ROOT/output/game"
PATCH="$ROOT/patches/android-portrait-orientation.patch"
SUBMODULE="$ROOT/tools/gb-recompiled"

if [ -z "$ROM" ]; then
  ROM="$(find "$ROOT/roms" -maxdepth 1 -type f \( -iname '*.gb' -o -iname '*.gbc' \) 2>/dev/null | head -n1)"
fi
if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
  echo "No ROM found. Place your own legally-owned ROM dump in $ROOT/roms/ or pass its path as \$1." >&2
  exit 1
fi

: "${SDL2_SOURCE_DIR:?Set SDL2_SOURCE_DIR to an SDL2 source checkout (with android-project/). See script header.}"
: "${ANDROID_HOME:?Set ANDROID_HOME (or ANDROID_SDK_ROOT) to your Android SDK path.}"
: "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to your Android NDK path.}"

# Apply the portrait-orientation patch to the vendored recompiler if not
# already applied, then (re)build it.
if ! git -C "$SUBMODULE" apply --reverse --check "$PATCH" 2>/dev/null; then
  echo "Applying portrait-orientation patch to gb-recompiled..."
  git -C "$SUBMODULE" apply "$PATCH"
fi

cmake -G Ninja -B "$SUBMODULE/build" "$SUBMODULE"
ninja -C "$SUBMODULE/build"

"$SUBMODULE/build/bin/gbrecomp" "$ROM" -o "$GEN" --output-prefix game \
  --android --android-package "$PACKAGE" --android-app-name "$APP_NAME" -j "$(nproc)"

SDL2_SOURCE_DIR="$SDL2_SOURCE_DIR" gradle -p "$GEN/android" :app:assembleDebug

APK="$GEN/android/app/build/outputs/apk/debug/app-debug.apk"
echo
echo "APK ready: $APK"
echo "Install with: adb install -r \"$APK\""
