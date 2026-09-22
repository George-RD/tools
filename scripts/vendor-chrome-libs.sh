#!/usr/bin/env bash
# Vendor a shared-library bundle so the vendored chrome-headless-shell runs on
# hosts without Chrome's system dependencies (minimal containers, sandboxes, NixOS).
#
# Strategy: take the ELF dependency closure of the host's Chromium build (which
# already knows exactly which libraries Chrome needs), copy each library's real
# files into vendor/chrome-libs/<arch>/lib, and write a launcher that runs the
# browser with this directory on the loader path.
#
# Requires a host Chromium and its closure (NixOS store) to copy from; on other
# hosts install chromium first. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBS="$ROOT/vendor/chrome-libs"
mkdir -p "$LIBS"

CHROMIUM_BIN="${CHROMIUM_BIN:-$(command -v chromium || command -v chromium-browser || true)}"
[ -n "$CHROMIUM_BIN" ] || { echo "No host chromium found; set CHROMIUM_BIN"; exit 1; }
CHROMIUM_REAL="$(readlink -f "$CHROMIUM_BIN")"
# NixOS/Chrome packaging wraps the real ELF in a shell script; follow to the ELF.
if ! file -b "$CHROMIUM_REAL" | grep -q 'ELF'; then
  for cand in $(ldd "$CHROMIUM_REAL" 2>/dev/null | awk '/=>/ {print $3}'); do :; done
  # Look for the unwrapped binary alongside/in the closure.
  found="$(find "$(dirname "$(dirname "$CHROMIUM_REAL")")" -maxdepth 4 -type f -name chromium 2>/dev/null | xargs -r file -b 2>/dev/null | grep -c ELF || true)"
  unwrapped="$(find /nix/store -maxdepth 4 -path '*chromium-unwrapped*/libexec/chromium/chromium' -type f 2>/dev/null | head -1)"
  if [ -n "$unwrapped" ]; then CHROMIUM_REAL="$unwrapped"; fi
fi
echo "host chromium: $CHROMIUM_REAL"

# Resolve the interpreter + all shared libs the browser loads.
mapfile -t NEEDED < <(ldd "$CHROMIUM_REAL" 2>/dev/null | awk '/=>/ && $3 ~ /^\// {print $3}' | sort -u)
echo "direct deps: ${#NEEDED[@]}"

# Expand transitively: each copied library's own deps (libs reference more libs,
# e.g. libatk-bridge -> libatspi -> libdbus).
declare -A seen=()
queue=("${NEEDED[@]}")
all=()
while [ "${#queue[@]}" -gt 0 ]; do
  lib="${queue[0]}"; queue=("${queue[@]:1}")
  [ -n "${seen[$lib]:-}" ] && continue
  seen[$lib]=1; all+=("$lib")
  while IFS= read -r dep; do
    [ -n "${seen[$dep]:-}" ] || queue+=("$dep")
  done < <(ldd "$lib" 2>/dev/null | awk '/=>/ && $3 ~ /^\// {print $3}')
done
echo "closure: ${#all[@]} libraries"

copy_one() {
  local src="$1" arch="$2"
  local dest="$LIBS/$arch/lib"
  mkdir -p "$dest"
  # Copy the real file plus every symlink alias pointing at it (soname links).
  local real; real="$(readlink -f "$src")"
  local base; base="$(basename "$real")"
  cp -fL "$real" "$dest/$base"
  # Recreate soname symlinks found next to the source.
  local dir; dir="$(dirname "$src")"
  local alias
  for alias in "$dir"/*.so*; do
    [ -L "$alias" ] || continue
    if [ "$(readlink -f "$alias")" = "$real" ]; then
      ln -sf "$base" "$dest/$(basename "$alias")"
    fi
  done
  # The name the loader asked for.
  local want; want="$(basename "$src")"
  [ -e "$dest/$want" ] || ln -sf "$base" "$dest/$want"
}

mapfile -t ARM64 < <(printf '%s\n' "${all[@]}" | while read -r l; do file -b "$l" | grep -q 'aarch64' && echo "$l"; done)
mapfile -t X64 < <(printf '%s\n' "${all[@]}" | while read -r l; do file -b "$l" | grep -q 'x86-64' && echo "$l"; done)

for l in "${ARM64[@]}"; do copy_one "$l" linux-arm64; done
for l in "${X64[@]}"; do copy_one "$l" linux-x64; done

# The dynamic loader itself.
cp -fL /nix/store/*-glibc-*/lib/ld-linux-aarch64.so.1 "$LIBS/linux-arm64/lib/" 2>/dev/null || true
echo "arm64 libs: $(ls "$LIBS/linux-arm64/lib" | wc -l)  x64 libs: $(ls "$LIBS/linux-x64/lib" 2>/dev/null | wc -l)"
du -sh "$LIBS" "$LIBS"/* 2>/dev/null

# Launcher: runs a chrome binary with the vendored libs on the loader path.
cat > "$LIBS/run-chrome-with-vendored-libs.sh" <<'EOS'
#!/usr/bin/env bash
# Run a chrome binary with the vendored system libraries.
# Usage: run-chrome-with-vendored-libs.sh <platform> <chrome-binary> [args...]
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
platform="${1:?platform: linux-x64|linux-arm64}"; shift
bin="${1:?chrome binary}"; shift
libdir="$here/$platform/lib"
export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$bin" "$@"
EOS
chmod 755 "$LIBS/run-chrome-with-vendored-libs.sh"
echo done
