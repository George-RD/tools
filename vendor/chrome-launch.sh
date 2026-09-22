#!/usr/bin/env bash
# Launcher for the vendored chrome-headless-shell, usable directly or as a
# puppeteer-style `executablePath` (arguments are passed through unchanged).
#
# Design (verified on a host with no FHS /lib and no Chrome system libraries):
#
#   * The browser is exec'd *directly*, not through an alternate loader. Chrome
#     re-executes /proc/self/exe to spawn its child processes, so invoking a
#     loader binary would make /proc/self/exe point at the loader and break
#     zygote/GPU startup.
#   * LD_LIBRARY_PATH points at vendor/chrome-libs/<platform>/lib-nocore: symlinks
#     to the vendored system libraries, deliberately EXCLUDING the core C runtime
#     (libc, ld-linux, libstdc++, libgcc_s, ...). The host's own runtime stays
#     authoritative, so only libraries the host is genuinely missing (libnss3,
#     libgbm, libatk, ...) are supplied — no glibc mixing.
#
# Environment:
#   TOOLS_PLATFORM   linux-x64 | linux-arm64 (default: detected)
#   TOOLS_CHROME     browser binary to run (default: vendored chrome-headless-shell)
#
# Examples:
#   ./vendor/chrome-launch.sh --headless --no-sandbox --dump-dom file:///tmp/a.html
#   HYPERFRAMES_BROWSER_PATH=$PWD/vendor/chrome-launch.sh ./hyperframes/bin/hyperframes check
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

platform="${TOOLS_PLATFORM:-}"
if [ -z "$platform" ]; then
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) platform=linux-x64 ;;
    Linux-aarch64|Linux-arm64) platform=linux-arm64 ;;
    *) printf 'unsupported platform %s-%s\n' "$(uname -s)" "$(uname -m)" >&2; exit 1 ;;
  esac
fi

# Extracted directory names differ per platform.
case "$platform" in
  linux-x64)   dir="$root/vendor/chrome-headless-shell/linux-x64/chrome-headless-shell-linux64" ;;
  linux-arm64) dir="$root/vendor/chrome-headless-shell/linux-arm64/chrome-headless-shell-linux-arm64" ;;
  *) printf 'unsupported platform %s\n' "$platform" >&2; exit 1 ;;
esac
bin="${TOOLS_CHROME:-$dir/chrome-headless-shell}"
[ -x "$bin" ] || { printf 'browser not found: %s\n' "$bin" >&2; exit 1; }

libdir="$root/vendor/chrome-libs/$platform/lib-nocore"
[ -d "$libdir" ] || libdir="$root/vendor/chrome-libs/$platform/lib"

export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Chrome resolves icudtl.dat/.pak relative to its own directory.
cd "$(dirname "$(readlink -f "$bin")")"
exec "./$(basename "$bin")" "$@"
