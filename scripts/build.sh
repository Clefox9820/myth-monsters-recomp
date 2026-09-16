#!/usr/bin/env bash
# Build the gb-recompiled toolchain, then regenerate and build a native
# executable from a ROM you supply (in roms/, or pass a path as $1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROM="${1:-}"
OUT="$ROOT/output/game"

if [ -z "$ROM" ]; then
  ROM="$(find "$ROOT/roms" -maxdepth 1 -type f \( -iname '*.gb' -o -iname '*.gbc' \) 2>/dev/null | head -n1)"
fi

if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
  echo "No ROM found. Place your own legally-owned ROM dump in $ROOT/roms/ or pass its path as \$1." >&2
  exit 1
fi

cmake -G Ninja -B "$ROOT/tools/gb-recompiled/build" "$ROOT/tools/gb-recompiled"
ninja -C "$ROOT/tools/gb-recompiled/build"

"$ROOT/tools/gb-recompiled/build/bin/gbrecomp" "$ROM" -o "$OUT" --output-prefix game -j "$(nproc)"

cmake -G Ninja -S "$OUT" -B "$OUT/build"
ninja -C "$OUT/build"

echo
echo "Built: $OUT/build/game"
