#!/usr/bin/env bash
# Cross-compile the generated Kid Icarus project into a native Windows x64
# executable using MinGW-w64. Useful for running the game through a Windows
# compatibility layer (Wine, Proton, GameNative on Android, etc.) when you
# don't have a native Linux/macOS/Windows desktop handy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/output/kid-icarus"
OUT="$GEN/build-win64"
SDL2_MINGW_VERSION="${SDL2_MINGW_VERSION:-2.30.9}"
SDL2_MINGW_DIR="${SDL2_MINGW_DIR:-/opt/sdl2-mingw}"

if [ ! -d "$GEN" ]; then
  echo "Generated project not found at $GEN. Run scripts/build.sh first." >&2
  exit 1
fi

if ! command -v x86_64-w64-mingw32-g++ >/dev/null; then
  echo "Installing MinGW-w64 cross toolchain..." >&2
  sudo apt-get install -y mingw-w64
fi

if [ ! -f "$SDL2_MINGW_DIR/x86_64-w64-mingw32/lib/cmake/SDL2/SDL2Config.cmake" ]; then
  echo "Fetching SDL2 mingw devel package..." >&2
  TMP_TGZ="$(mktemp --suffix=.tar.gz)"
  curl -sSL -o "$TMP_TGZ" \
    "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_MINGW_VERSION}/SDL2-devel-${SDL2_MINGW_VERSION}-mingw.tar.gz"
  sudo mkdir -p "$SDL2_MINGW_DIR"
  sudo tar -xzf "$TMP_TGZ" -C "$SDL2_MINGW_DIR" --strip-components=1
  rm -f "$TMP_TGZ"
fi

cmake -G Ninja -S "$GEN" -B "$OUT" \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/scripts/mingw-w64-toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release
ninja -C "$OUT"

DIST="$ROOT/dist/win64"
mkdir -p "$DIST"
cp "$OUT/kidicarus.exe" "$DIST/"
cp "$SDL2_MINGW_DIR/x86_64-w64-mingw32/bin/SDL2.dll" "$DIST/"
MINGW_RT_DIR="$(dirname "$(x86_64-w64-mingw32-g++ -print-file-name=libstdc++-6.dll)")"
cp "$MINGW_RT_DIR/libstdc++-6.dll" "$DIST/" 2>/dev/null || true
cp "$MINGW_RT_DIR/libgcc_s_seh-1.dll" "$DIST/" 2>/dev/null || true

echo
echo "Windows build ready: $DIST/kidicarus.exe (+ DLLs in the same folder)"
echo "Copy the whole '$DIST' folder to run it under Wine/Proton/GameNative."
