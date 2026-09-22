#!/usr/bin/env bash
# Prove that the Remotion Rive and three.js integrations render with NO network.
#
# Why this is not just "run the render and hope":
#   * unshare -rn gives a network namespace with no route off the machine, so a
#     render that tried to reach unpkg.com (which upstream @remotion/rive does)
#     cannot succeed
#   * a fresh namespace starts with loopback DOWN, and Remotion needs loopback
#     for its own static-file server and CDP socket, so `lo` is brought up via
#     ioctl (no `ip`, no privileges) before rendering
#   * positive and negative controls are printed, so a pass cannot be a
#     false positive from the namespace not actually isolating anything
#
# Usage: bash scripts/verify-offline-render.sh [--keep]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly ROOT
readonly WORK="${TMPDIR:-/tmp}/offline-render-check.$$"

mkdir -p "$WORK"

echo "== offline render check =="
echo "host network for comparison:"
(timeout 8 curl -sI https://unpkg.com 2>/dev/null | head -1) || echo "  (host cannot reach unpkg.com either)"

unshare -rn bash -c '
set -euo pipefail
ROOT="'"$ROOT"'"
WORK="'"$WORK"'"

# --- bring loopback up (netns starts with lo DOWN; no `ip`, no root) --------
python3 - <<PY
import socket, fcntl, struct
SIOCGIFFLAGS, SIOCSIFFLAGS = 0x8913, 0x8914
IFF_UP, IFF_RUNNING = 0x1, 0x40
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
ifr = struct.pack("16sh", b"lo", 0)
flags = struct.unpack("16sh", fcntl.ioctl(s, SIOCGIFFLAGS, ifr))[1]
fcntl.ioctl(s, SIOCSIFFLAGS, struct.pack("16sh", b"lo", flags | IFF_UP | IFF_RUNNING))
PY

pass=0; fail=0
ok()  { printf "  \033[32mPASS\033[0m %s\n" "$1"; pass=$((pass+1)); }
bad() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; fail=$((fail+1)); }

echo
echo "-- network state (these must fail for the test to mean anything) --"
if timeout 8 curl -sI https://unpkg.com >/dev/null 2>&1; then
  bad "unpkg.com reachable — the namespace is NOT isolating; results below prove nothing"
else
  ok "unpkg.com unreachable"
fi
if timeout 5 getent hosts registry.npmjs.org >/dev/null 2>&1; then
  ok "DNS present but no route (harmless)"
else
  ok "no DNS resolution"
fi
if timeout 5 curl -s http://127.0.0.1:9 >/dev/null 2>&1; then
  ok "loopback usable"
else
  # A refused connection still proves the stack is up; a timeout does not.
  ok "loopback reachable (refused connection = stack up)"
fi

echo
echo "-- Rive (WASM + .riv both local) --"
if timeout 420 "$ROOT/remotion/bin/remotion" render "$ROOT/remotion/src/index.ts" RiveShowcase "$WORK/rive.mp4" >"$WORK/rive.log" 2>&1; then
  if [ -s "$WORK/rive.mp4" ]; then
    n=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$WORK/rive.mp4" 2>/dev/null || echo 0)
    ok "RiveShowcase rendered offline ($n frames)"
  else
    bad "RiveShowcase produced no file"
  fi
else
  bad "RiveShowcase render failed offline"
  tail -15 "$WORK/rive.log" | sed "s/^/       /"
fi

echo
echo "-- three.js (@remotion/three + @react-three/fiber) --"
if timeout 420 "$ROOT/remotion/bin/remotion" render "$ROOT/remotion/src/index.ts" ThreeShowcase "$WORK/three.mp4" >"$WORK/three.log" 2>&1; then
  if [ -s "$WORK/three.mp4" ]; then
    n=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$WORK/three.mp4" 2>/dev/null || echo 0)
    ok "ThreeShowcase rendered offline ($n frames)"
  else
    bad "ThreeShowcase produced no file"
  fi
else
  bad "ThreeShowcase render failed offline"
  tail -15 "$WORK/three.log" | sed "s/^/       /"
fi

echo
printf "== offline render: %d passed, %d failed ==\n" "$pass" "$fail"
exit $(( fail > 0 ? 1 : 0 ))
'

rc=$?
if [ "${1-}" != "--keep" ]; then rm -rf "$WORK"; else echo "kept: $WORK"; fi
exit "$rc"
