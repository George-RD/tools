#!/usr/bin/env bash
# Vendor a specific official Rive CLI release (default 1.0.2, linux x64) into
# rive-official/, relocatable.
#
# NOTE: for "always the latest release" use scripts/update-rive.sh instead —
# it queries Rive's manifest, verifies SHA-256, installs the payload and
# repoints the wrapper pin. This script pins explicit SHAs, so it is only
# correct for the version it names. Both share the same layout:
#   bin/rive (wrapper) + versions/<ver>/{rive,docs,samples}
#   + compat/ (multiarch static QEMU, glibc/gcc/zlib/glvnd/x11/wayland/xkbcommon
#     x86-64, pruned Mesa software stack) — compat is version-independent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${RIVE_SRC:-/var/lib/hermes/riv-tools/official}"
DEST="$ROOT/rive-official"
DL="${TOOLS_DOWNLOADS:-$ROOT/.downloads}"
RIVE_VERSION="1.0.2"
RIVE_ELF_SHA="4d7a219c00f6978b91fb3d4d7f2db694ffc11afe2f1ae7c2b6e7a386a3642fef"
ARCHIVE_SHA="9c8adbabf7ae6457bc01ea7d75a1f145ba51a99b67a69d9ac2bdcc6cf5363710"
mkdir -p "$DL"

have_src=0
[ -x "$SRC/versions/$RIVE_VERSION/rive" ] && [ -d "$SRC/compat" ] && have_src=1
if [ "$have_src" = 0 ]; then
  echo "local verified install not found; downloading official tarball"
  curl -fL --retry 3 -o "$DL/rive-linux-x64-$RIVE_VERSION.tar.gz" \
    "https://releases.rive.app/cli/v$RIVE_VERSION/rive-linux-x64.tar.gz"
  echo "$ARCHIVE_SHA  $DL/rive-linux-x64-$RIVE_VERSION.tar.gz" | sha256sum -c -
  rm -rf "$DL/rive-tar"; mkdir -p "$DL/rive-tar"
  tar -xzf "$DL/rive-linux-x64-$RIVE_VERSION.tar.gz" -C "$DL/rive-tar"
  SRCDIR="$DL/rive-tar"
else
  SRCDIR="$SRC/versions/$RIVE_VERSION"
fi

echo "== payload =="
mkdir -p "$DEST/versions/$RIVE_VERSION"
cp -L "$SRCDIR/rive" "$DEST/versions/$RIVE_VERSION/rive"
chmod 755 "$DEST/versions/$RIVE_VERSION/rive"
echo "$RIVE_ELF_SHA  $DEST/versions/$RIVE_VERSION/rive" | sha256sum -c -
for tree in docs samples; do
  [ -d "$SRCDIR/$tree" ] && { rm -rf "$DEST/versions/$RIVE_VERSION/$tree"; cp -RL "$SRCDIR/$tree" "$DEST/versions/$RIVE_VERSION/$tree"; }
done

echo "== provenance files =="
mkdir -p "$DEST/downloads"
if [ "$have_src" = 1 ]; then
  for f in install.sh manifest.json; do cp -L "$SRC/downloads/$f" "$DEST/downloads/$f" 2>/dev/null || true; done
fi
if [ -f "$DL/rive-linux-x64-$RIVE_VERSION.tar.gz" ]; then cp "$DL/rive-linux-x64-$RIVE_VERSION.tar.gz" "$DEST/downloads/"; fi

echo "== qemu (static, portable) =="
mkdir -p "$DEST/compat"
Q="$DEST/compat/qemu-x86_64-static"
if [ ! -x "$Q" ]; then
  curl -fL --retry 3 -o "$Q.part" \
    "https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static"
  mv "$Q.part" "$Q"; chmod 755 "$Q"
fi
"$Q" --version | head -1

echo "== x86-64 compat libraries (dereferenced from local Nix store) =="
copy_lib() { # copy_lib <src-dir> <dest-dir> <subdir?>
  local s="$1" d="$2" sub="${3:-lib}"
  rm -rf "$d"; mkdir -p "$(dirname "$d")"
  cp -RL "$s/$sub" "$d"
  find "$d" -type f -exec chmod u+w {} +
}
if [ "$have_src" = 1 ]; then
  for pair in glibc-x64 glibc gcc-libs-x64 gcc-libs zlib-x64 zlib libglvnd-x64 glvnd libx11-x64 x11 wayland-x64 wayland libxkbcommon-x64 xkbcommon; do
    set -- $pair
    [ -d "$SRC/compat/$1" ] && copy_lib "$SRC/compat/$1" "$DEST/compat/$2/lib"
  done
  mkdir -p "$DEST/compat/sysroot/lib64"
  cp -L "$SRC/compat/sysroot/lib64/ld-linux-x86-64.so.2" "$DEST/compat/sysroot/lib64/" 2>/dev/null || \
    cp -L "$SRC/compat/glibc-x64/lib/ld-linux-x86-64.so.2" "$DEST/compat/sysroot/lib64/"

  echo "== mesa (pruned: software EGL only) =="
  M="$DEST/compat/mesa-x64"
  rm -rf "$M"; mkdir -p "$M/lib/dri" "$M/share/glvnd/egl_vendor.d" "$M/share/drirc.d"
  for f in libEGL_mesa.so.0.0.0 libGLX_mesa.so.0.0.0 libgallium-26.1.5.so; do
    cp -L "$SRC/compat/mesa-x64/lib/$f" "$M/lib/$f"
  done
  ln -sf libEGL_mesa.so.0.0.0 "$M/lib/libEGL_mesa.so.0"
  ln -sf libEGL_mesa.so.0.0.0 "$M/lib/libEGL_mesa.so"
  ln -sf libGLX_mesa.so.0.0.0 "$M/lib/libGLX_mesa.so.0"
  ln -sf libGLX_mesa.so.0.0.0 "$M/lib/libGLX_mesa.so"
  for f in libdril_dri.so swrast_dri.so kms_swrast_dri.so; do
    cp -L "$SRC/compat/mesa-x64/lib/dri/$f" "$M/lib/dri/$f" 2>/dev/null || true
  done
  cp -L "$SRC/compat/mesa-x64/share/drirc.d/"*.conf "$M/share/drirc.d/" 2>/dev/null || true
  chmod -R u+w "$M"
else
  echo "WARNING: no local compat tree; run this script on George's NixOS host to populate compat libs" >&2
fi

echo "== wrapper =="
cat > "$DEST/bin/rive" <<'WRAPPER'
#!/usr/bin/env bash
# Relocatable launcher for the official Rive CLI (linux x64 payload).
#
# On aarch64 hosts the unmodified official x86-64 ELF runs under a static
# QEMU user emulator with vendored x86-64 libraries and Mesa software EGL.
# On x86_64 hosts the same vendored libraries are used via the vendored
# glibc loader (no system EGL/X11 packages required).
#
# Pinned to one version; automatic update/switch/uninstall is disabled.
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
readonly root
readonly version=1.0.2
case "${1-}" in
  update|switch|uninstall)
    printf '%s\n' 'This vendored copy is pinned to 1.0.2; automatic version management is disabled.' >&2
    printf '%s\n' 'Install/update from https://releases.rive.app/cli/install.sh on an x86-64 host instead.' >&2
    exit 2
    ;;
esac

# Scoped state so the CLI never writes into the caller's HOME.
export RIVE_HOME="${RIVE_VENDOR_STATE:-$root/home}"
export HOME="$RIVE_HOME/home"
mkdir -p "$HOME" "$RIVE_HOME/tmp" "$RIVE_HOME/work/egl_vendor.d" "$RIVE_HOME/work/logs"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$HOME/.runtime"
export TMPDIR="$RIVE_HOME/tmp"
export RIVE_DOCS_DIR="$root/versions/$version/docs"
export RIVE_SAMPLES_DIR="$root/versions/$version/samples"
export RIVE_ANALYTICS=off
export RIVE_NO_TUI=1
export NO_COLOR=1

# Software rendering (no display server needed).
export EGL_PLATFORM=surfaceless
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export LIBGL_DRIVERS_PATH="$root/compat/mesa-x64/lib/dri"
export XDG_DATA_DIRS="$root/compat/mesa-x64/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
# EGL vendor manifest is generated with the real repo path (relocatable).
vendor_json="$RIVE_HOME/work/egl_vendor.d/50_mesa.json"
printf '{\n  "file_format_version": "1.0.0",\n  "ICD": {\n    "library_path": "%s"\n  }\n}\n' \
  "$root/compat/mesa-x64/lib/libEGL_mesa.so.0" > "$vendor_json"
export __EGL_VENDOR_LIBRARY_FILENAMES="$vendor_json"

readonly guest_libs="$root/compat/glibc-x64/lib:$root/compat/gcc-libs-x64/lib:$root/compat/zlib-x64/lib:$root/compat/glvnd/lib:$root/compat/x11/lib:$root/compat/wayland/lib:$root/compat/xkbcommon/lib:$root/compat/mesa-x64/lib"
ulimit -c 0

case "$(uname -m)" in
  x86_64)
    exec "$root/compat/glibc-x64/lib/ld-linux-x86-64.so.2" \
      --library-path "$guest_libs" \
      "$root/versions/$version/rive" "$@"
    ;;
  *)
    exec "$root/compat/qemu-x86_64-static" \
      -L "$root/compat/sysroot" \
      -E "LD_LIBRARY_PATH=$guest_libs" \
      "$root/versions/$version/rive" "$@"
    ;;
esac
WRAPPER
chmod 755 "$DEST/bin/rive"

echo "== sizes =="
du -sh "$DEST" "$DEST"/* 2>/dev/null
echo done
