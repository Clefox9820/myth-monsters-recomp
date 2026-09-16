#!/usr/bin/env bash
# Build the gb-recompiled toolchain, then regenerate and build the native
# Kid Icarus executable from a ROM you supply in roms/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROM="${1:-$ROOT/roms/Kid Icarus - Of Myths and Monsters (USA, Europe).gb}"
OUT="$ROOT/output/kid-icarus"

if [ ! -f "$ROM" ]; then
  echo "ROM not found: $ROM" >&2
  echo "Place your own legally-owned ROM dump in $ROOT/roms/ or pass its path as \$1." >&2
  exit 1
fi

cmake -G Ninja -B "$ROOT/tools/gb-recompiled/build" "$ROOT/tools/gb-recompiled"
ninja -C "$ROOT/tools/gb-recompiled/build"

"$ROOT/tools/gb-recompiled/build/bin/gbrecomp" "$ROM" -o "$OUT" --output-prefix kidicarus -j "$(nproc)"

cmake -G Ninja -S "$OUT" -B "$OUT/build"
ninja -C "$OUT/build"

echo
echo "Built: $OUT/build/kidicarus"
