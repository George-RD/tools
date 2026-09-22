#!/usr/bin/env bash
# End-to-end checks for the vendored toolchain: Rive CLI, HyperFrames, Remotion.
# Runs from the repo root; exits non-zero if any check fails.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
WORK="$ROOT/.verify"
rm -rf "$WORK"; mkdir -p "$WORK"
pass=0; fail=0

ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
check() { # check <name> <command...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi
}

echo "== Rive CLI =="
if [ -x rive-official/bin/rive ]; then
  v="$(rive-official/bin/rive --version 2>/dev/null | tail -1 || true)"
  # Do not hardcode a version: scripts/update-rive.sh moves this to the latest
  # release. Check instead that the CLI runs and that its reported version
  # matches the pin in the wrapper — a mismatch means a botched update.
  pin="$(sed -n 's/^readonly version=//p' rive-official/bin/rive | head -1)"
  case "$v" in
    "rive $pin") ok "rive --version ($v, matches wrapper pin)";;
    rive\ *)     bad "rive --version (got '$v' but wrapper pins '$pin')";;
    *)           bad "rive --version (got: ${v:-<no output>})";;
  esac

  mkdir -p "$WORK/rive" && cp -r fixtures/rive/neutral "$WORK/rive/" 2>/dev/null || true
  if [ -d "$WORK/rive/neutral" ]; then
    rm -rf "$WORK/rive/neutral/build"
    check "rive verify"  rive-official/bin/rive "$WORK/rive/neutral" --verify --format=json
    check "rive build"   rive-official/bin/rive "$WORK/rive/neutral" --once --format=json
    if [ -f "$WORK/rive/neutral/build/neutral.riv" ]; then
      hdr="$(od -An -N4 -tx1 "$WORK/rive/neutral/build/neutral.riv" | tr -d ' ')"
      [ "$hdr" = "52495645" ] && ok "rive artifact header (RIVE)" || bad "rive artifact header ($hdr)"
    else
      bad "rive artifact missing"
    fi
    check "rive screenshot" rive-official/bin/rive "$WORK/rive/neutral" \
      --screenshot="$WORK/rive/neutral/build/shot.png" --viewport=128x128 --advance=1
    if [ -f "$WORK/rive/neutral/build/shot.png" ]; then
      dims="$(file -b "$WORK/rive/neutral/build/shot.png")"
      case "$dims" in *"128 x 128"*) ok "rive screenshot 128x128";; *) bad "rive screenshot ($dims)";; esac
    else
      bad "rive screenshot missing"
    fi
  else
    bad "rive smoke fixture unavailable"
  fi
else
  bad "rive-official/bin/rive missing"
fi

echo "== vendored library overlays =="
if [ -x scripts/audit-libs.sh ]; then
  if out="$(bash scripts/audit-libs.sh 2>&1)"; then
    ok "lib-nocore overlays complete (both arches)"
  else
    bad "lib-nocore overlays incomplete"
    printf '%s\n' "$out" | sed 's/^/       /'
  fi
else
  bad "scripts/audit-libs.sh missing"
fi

# The Rive wrapper uses rive-official/home/ as the CLI's HOME: caches and the
# auth token that `rive login` writes land there, so it must stay untracked.
if [ -n "$(git ls-files rive-official/home 2>/dev/null)" ]; then
  bad "rive-official/home is tracked (runtime state/credentials must not be committed)"
else
  ok "rive-official/home untracked (runtime state)"
fi

echo "== HyperFrames =="
if [ -x hyperframes/bin/hyperframes ]; then
  v="$(hyperframes/bin/hyperframes --version 2>/dev/null | tail -1)"
  [ -n "$v" ] && ok "hyperframes --version ($v)" || bad "hyperframes --version"
  check "hyperframes doctor runs" hyperframes/bin/hyperframes doctor
  # Author a composition with real seeked motion and render it.
  # The GSAP script is served from the repository's own copy (vendor/gsap), not a
  # CDN, so this check also fails if an offline render would need the network.
  mkdir -p "$WORK/hf"
  cp vendor/gsap/gsap-3.14.2.min.js "$WORK/hf/gsap.min.js"
  cat > "$WORK/hf/index.html" <<'HTML'
<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<script src="./gsap.min.js"></script>
<style>html,body{margin:0;background:#101010}#stage{position:relative;width:320px;height:180px;overflow:hidden}
.clip{position:absolute}.box{width:40px;height:40px;background:#b98d3f;top:70px;left:20px}</style></head>
<body><div id="stage" data-composition-id="verify" data-start="0" data-width="320" data-height="180">
<div class="box clip" id="box" data-start="0" data-duration="2" data-track-index="0"></div></div>
<script>window.__timelines=window.__timelines||{};
const tl=gsap.timeline({paused:true});tl.to("#box",{x:240,duration:2,ease:"none"},0);
window.__timelines["verify"]=tl;tl.seek(0);</script></body></html>
HTML
  cat > "$WORK/hf/meta.json" <<'JSON'
{"id":"verify","name":"verify","createdAt":"2026-01-01T00:00:00.000Z"}
JSON
  if [ -x vendor/chrome-launch.sh ]; then
    check "hyperframes browser (dump-dom)" vendor/chrome-launch.sh --version
    check "hyperframes CDP smoke" node scripts/cdp-smoke.mjs "$(pwd)/vendor/chrome-launch.sh" "$(pwd)/hyperframes/cli/node_modules"
    check "hyperframes seek changes pixels" node scripts/seek-test.mjs "$WORK/hf/index.html"
  fi
  if (cd "$WORK/hf" && "$ROOT/hyperframes/bin/hyperframes" lint >/dev/null 2>&1); then
    ok "hyperframes lint"
  else
    bad "hyperframes lint"
  fi
  if (cd "$WORK/hf" && "$ROOT/hyperframes/bin/hyperframes" render --output out/verify.mp4 >/dev/null 2>&1); then
    f="$WORK/hf/out/verify.mp4"
    if [ -s "$f" ]; then
      n="$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$f" 2>/dev/null || echo 0)"
      [ "${n:-0}" -gt 0 ] && ok "hyperframes render ($n frames)" || bad "hyperframes render frames ($n)"
      # Distinct frames prove seeked motion reached the encoder.
      ffmpeg -v error -ss 0.2 -i "$f" -frames:v 1 -y "$WORK/hf/a.png" 2>/dev/null || true
      ffmpeg -v error -ss 1.8 -i "$f" -frames:v 1 -y "$WORK/hf/b.png" 2>/dev/null || true
      if [ -f "$WORK/hf/a.png" ] && [ -f "$WORK/hf/b.png" ]; then
        if [ "$(md5sum < "$WORK/hf/a.png")" != "$(md5sum < "$WORK/hf/b.png")" ]; then
          ok "hyperframes rendered frames differ (motion captured)"
        else
          bad "hyperframes rendered frames identical (no motion)"
        fi
      fi
    else
      bad "hyperframes render produced no file"
    fi
  else
    bad "hyperframes render failed"
  fi
else
  bad "hyperframes/bin/hyperframes missing"
fi

echo "== Remotion =="
if [ -x remotion/bin/remotion ]; then
  check "remotion --version" remotion/bin/remotion versions
  out="$WORK/remotion.mp4"
  if remotion/bin/remotion render src/index.ts HelloWorld "$out" >/dev/null 2>&1; then
    if [ -s "$out" ]; then
      n="$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames,width,height -of csv=p=0 "$out" 2>/dev/null || echo 0)"
      ok "remotion render ($n)"
    else
      bad "remotion render produced no file"
    fi
  else
    bad "remotion render failed"
  fi

  # The Rive integration must not reach for a CDN: upstream @remotion/rive
  # hardcodes an unpkg.com URL for its WASM, and this repository patches it to
  # load a local copy instead (scripts/patch-remotion-rive-offline.sh).
  if bash scripts/patch-remotion-rive-offline.sh --check >/dev/null 2>&1; then
    ok "remotion rive WASM is local (no CDN)"
  else
    bad "remotion rive WASM still points at a CDN — run scripts/patch-remotion-rive-offline.sh"
  fi
  for pkg in "@remotion/rive" "@remotion/three" "three" "@react-three/fiber"; do
    if [ -f "remotion/node_modules/$pkg/package.json" ]; then
      ok "remotion integration present ($pkg@$(jq -r .version "remotion/node_modules/$pkg/package.json" 2>/dev/null))"
    else
      bad "remotion integration missing ($pkg)"
    fi
  done
else
  bad "remotion/bin/remotion missing"
fi

echo
printf '== summary: %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
