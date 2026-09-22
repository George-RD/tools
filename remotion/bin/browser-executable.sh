#!/usr/bin/env bash
# Browser entry point for Remotion: runs the pinned chrome-headless-shell that
# lives in this project's node_modules, supplying the vendored system libraries
# so it also works on hosts that lack Chrome's dependencies.
#
# LD_LIBRARY_PATH is set only for the browser process — never for the Node.js
# process that spawns it, which would break Node's own OpenSSL linkage.
#
# Wired in via remotion.config.ts (Config.setBrowserExecutable).
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"   # remotion/
root="$(cd "$here/.." && pwd)"                              # repo root

case "$(uname -m)" in
  x86_64)         platform=linux64;    libplatform=linux-x64 ;;
  aarch64|arm64)  platform=linux-arm64; libplatform=linux-arm64 ;;
  *) printf 'unsupported arch %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

basedir="$here/node_modules/.remotion/chrome-headless-shell/$platform"
if [ "$platform" = "linux-arm64" ]; then
  bin="$basedir/chrome-headless-shell-linux-arm64/headless_shell"
else
  bin="$basedir/chrome-headless-shell-linux64/chrome-headless-shell"
fi
[ -x "$bin" ] || { printf 'pinned browser missing: %s\n' "$bin" >&2; exit 1; }

libdir="$root/vendor/chrome-libs/$libplatform/lib-nocore"
[ -d "$libdir" ] || libdir="$root/vendor/chrome-libs/$libplatform/lib"
if [ -d "$libdir" ]; then
  export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

cd "$(dirname "$bin")"
exec "./$(basename "$bin")" "$@"
