#!/usr/bin/env bash
# Run a chrome-headless-shell binary with the vendored system libraries.
#
# Needed on hosts that lack Chrome's shared-library dependencies (minimal
# containers, sandboxes, NixOS without an FHS /lib). Uses the matching Debian
# loader from vendor/chrome-libs/<platform>/lib so no system loader is required.
#
# Usage: run-chrome-with-vendored-libs.sh <linux-x64|linux-arm64> <chrome-binary> [args...]
#   e.g. run-chrome-with-vendored-libs.sh linux-arm64 \
#          vendor/chrome-headless-shell/linux-arm64/chrome-headless-shell-linux-arm64/chrome-headless-shell \
#          --headless --no-sandbox --screenshot=out.png file:///tmp/page.html
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

platform="${1:?platform: linux-x64 or linux-arm64}"; shift
bin="${1:?path to chrome binary}"; shift

libdir="$here/$platform/lib"
case "$platform" in
  linux-x64)   loader="$libdir/ld-linux-x86-64.so.2" ;;
  linux-arm64) loader="$libdir/ld-linux-aarch64.so.1" ;;
  *) printf 'unknown platform %s\n' "$platform" >&2; exit 1 ;;
esac

# Chrome reads its data files (icudtl.dat, .pak) from its own directory when the
# path is absolute and the cwd matches; keep both explicit.
bindir="$(cd "$(dirname "$(readlink -f "$bin")")" && pwd)"
binname="$(basename "$bin")"

export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$bindir"
exec "$loader" --library-path "$libdir" "./$binname" "$@"
