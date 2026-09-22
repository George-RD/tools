#!/usr/bin/env bash
# Verify the Remotion Rive and three.js integrations specifically.
#
# Covers what scripts/verify.sh does not: whether each integration actually
# produces a correct render, from local assets only.
#
#   * Rive  — the .riv fixture loads, the WASM comes from the project (not a
#             CDN), and successive frames differ (the animation is really
#             advancing, not frozen on one frame)
#   * three — the scene renders through @remotion/three and the cube is seen
#             from a changing angle across frames
#
# Usage: bash scripts/verify-remotion-integrations.sh [--network-offline]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly ROOT
cd "$ROOT"
WORK="${TMPDIR:-/tmp}/remotion-integration-check.$$"
mkdir -p "$WORK"
pass=0; fail=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "== Remotion integrations =="

echo "-- local assets (no CDN may be involved) --"
if bash scripts/patch-remotion-rive-offline.sh --check >/dev/null 2>&1; then
  ok "rive WASM patched to a local path"
else
  bad "rive WASM still resolves to a CDN — run scripts/patch-remotion-rive-offline.sh"
fi
[ -f remotion/public/rive.wasm ] && ok "remotion/public/rive.wasm present" || bad "remotion/public/rive.wasm missing"
[ -f remotion/public/rive-demo.riv ] && ok "remotion/public/rive-demo.riv present" || bad "remotion/public/rive-demo.riv missing"

# A .riv must begin with the "RIVE" magic; a truncated or mis-built fixture
# would otherwise only fail deep inside the browser.
if [ -f remotion/public/rive-demo.riv ]; then
  hdr="$(od -An -N4 -tx1 remotion/public/rive-demo.riv | tr -d ' ')"
  [ "$hdr" = "52495645" ] && ok "rive fixture header (RIVE)" || bad "rive fixture header ($hdr)"
fi

for pkg in "@remotion/rive" "@remotion/three" "three" "@react-three/fiber" "@rive-app/canvas-advanced"; do
  f="remotion/node_modules/$pkg/package.json"
  if [ -f "$f" ]; then
    ok "installed $pkg@$(jq -r .version "$f" 2>/dev/null)"
  else
    bad "missing $pkg"
  fi
done

echo "-- render RiveShowcase --"
if remotion/bin/remotion render src/index.ts RiveShowcase "$WORK/rive.mp4" >"$WORK/rive.log" 2>&1; then
  ok "render completed"
  # Extract frames spread across the clip; identical frames would mean the
  # animation never advanced even though the render "succeeded".
  a="$WORK/rive-a.png"; b="$WORK/rive-b.png"
  ffmpeg -v error -ss 0.2 -i "$WORK/rive.mp4" -frames:v 1 -y "$a" 2>/dev/null || true
  ffmpeg -v error -ss 2.8 -i "$WORK/rive.mp4" -frames:v 1 -y "$b" 2>/dev/null || true
  if [ -f "$a" ] && [ -f "$b" ]; then
    if [ "$(md5sum < "$a")" != "$(md5sum < "$b")" ]; then
      ok "frames differ (animation is advancing)"
    else
      bad "frames identical (animation frozen)"
    fi
  else
    bad "could not extract frames"
  fi
else
  bad "render failed"
  tail -10 "$WORK/rive.log" | sed 's/^/       /'
fi

echo "-- render ThreeShowcase --"
if remotion/bin/remotion render src/index.ts ThreeShowcase "$WORK/three.mp4" >"$WORK/three.log" 2>&1; then
  ok "render completed"
  a="$WORK/three-a.png"; b="$WORK/three-b.png"
  ffmpeg -v error -ss 0.2 -i "$WORK/three.mp4" -frames:v 1 -y "$a" 2>/dev/null || true
  ffmpeg -v error -ss 2.8 -i "$WORK/three.mp4" -frames:v 1 -y "$b" 2>/dev/null || true
  if [ -f "$a" ] && [ -f "$b" ]; then
    if [ "$(md5sum < "$a")" != "$(md5sum < "$b")" ]; then
      ok "frames differ (cube is rotating)"
    else
      bad "frames identical (scene static)"
    fi
  else
    bad "could not extract frames"
  fi
else
  bad "render failed"
  tail -10 "$WORK/three.log" | sed 's/^/       /'
fi

# Optional: rerun both inside a network namespace with no route off the machine.
if [ "${1-}" = "--network-offline" ]; then
  echo "-- re-running with network isolation --"
  if bash scripts/verify-offline-render.sh; then
    ok "both integrations render with no network"
  else
    case $? in
      3) ok "skipped: network namespaces unavailable on this host (not a failure)";;
      *) bad "offline render failed";;
    esac
  fi
fi

echo
printf '== remotion integrations: %d passed, %d failed ==\n' "$pass" "$fail"
rm -rf "$WORK"
[ "$fail" -eq 0 ]
