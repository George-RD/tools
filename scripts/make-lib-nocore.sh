#!/usr/bin/env bash
# Build the "lib-nocore" overlay for each platform.
#
# vendor/chrome-libs/<platform>/lib holds Chrome's system libraries extracted
# from Debian packages. Pointing the loader at that whole directory also shadows
# the host's core C runtime (libc/ld-linux/openssl/libstdc++), which breaks
# process re-exec (Chrome spawns children via /proc/self/exe) and can break
# unrelated programs (a Node.js process with that path set fails on OpenSSL
# symbols). lib-nocore is a directory of RELATIVE symlinks to everything except
# the core runtime, so it is safe on LD_LIBRARY_PATH: the host's own runtime
# stays authoritative and only genuinely missing libraries are supplied.
#
# Symlinks are relative ("../lib/<name>") so the whole tree survives being
# cloned or moved.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Core runtime files never to be overlaid.
#
# NOTE: libz (zlib) must NOT be in this list. It is a general-purpose
# compression library, not part of the C runtime, and several vendored
# libraries depend on it (libcairo, libcups, libfreetype, libgio, libpng16).
# Excluding it left `libz.so.1 => not found` for the browser on hosts that do
# not ship zlib in the default library path. The genuinely host-specific
# entries are the glibc family and libstdc++/libgcc_s/libssl/libcrypto.
EXCLUDE='ld-linux.*|libc\.so\.6|libc-.*\.so|libcrypt\.so.*|libm\.so\.6|libm-.*\.so|libmvec\.so.*|libpthread\.so.*|libdl\.so.*|librt\.so.*|libgcc_s\.so.*|libstdc\+\+\.so.*|libutil\.so.*|libresolv\.so.*|libnsl\.so.*|libanl\.so.*|libthread_db\.so.*|libBrokenLocale\.so.*|libc_malloc_debug\.so.*|libcrypto\.so.*|libssl\.so.*'

for p in linux-x64 linux-arm64; do
  lib="$ROOT/vendor/chrome-libs/$p/lib"
  nc="$ROOT/vendor/chrome-libs/$p/lib-nocore"
  [ -d "$lib" ] || { echo "skip $p (no lib)"; continue; }
  rm -rf "$nc"; mkdir -p "$nc"
  n=0
  for f in "$lib"/*; do
    b="$(basename "$f")"
    if printf '%s' "$b" | grep -Eq "^($EXCLUDE)$"; then continue; fi
    ln -sf "../lib/$b" "$nc/$b"
    n=$((n + 1))
  done
  echo "$p: $n relative links -> $nc"
done
