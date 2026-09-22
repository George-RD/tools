#!/usr/bin/env bash
# Fetch + extract third-party runtimes into vendor/ and node/.
# Idempotent: skips anything already extracted. Downloads land in .downloads/ (not committed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="${TOOLS_DOWNLOADS:-$ROOT/.downloads}"
mkdir -p "$DL" "$ROOT/vendor/chrome-headless-shell/linux-x64" "$ROOT/vendor/chrome-headless-shell/linux-arm64" \
  "$ROOT/vendor/ffmpeg/linux-x64" "$ROOT/vendor/ffmpeg/linux-arm64" "$ROOT/node/linux-x64" "$ROOT/node/linux-arm64"

NODE_VERSION="v22.23.2"

dl() { # dl <url> <dest>
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then echo "have $(basename "$dest")"; return; fi
  echo "fetch $(basename "$dest")"
  curl -fL --retry 3 --retry-delay 2 -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
}

# ---------- Node.js (both linux arches) ----------
for arch in x64 arm64; do
  tar="$DL/node-$arch.tar.xz"
  dl "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-$arch.tar.xz" "$tar"
  dest="$ROOT/node/linux-$arch"
  if [ ! -d "$dest/lib/node_modules" ]; then
    echo "extract node linux-$arch"
    tmpd="$DL/node-extract-$arch"; rm -rf "$tmpd"; mkdir -p "$tmpd"
    tar -xJf "$tar" -C "$tmpd"
    rm -rf "$dest"; mv "$tmpd/node-$NODE_VERSION-linux-$arch" "$dest"
  fi
done

# ---------- Chrome Headless Shell (stable, both linux arches) ----------
CJ="$DL/cft-lkg.json"
dl "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" "$CJ"
CVER=$(jq -r '.channels.Stable.version' "$CJ")
echo "Chrome-for-Testing stable: $CVER"
for plat in linux64 linux-arm64; do
  dirname="chrome-headless-shell-$plat"
  url=$(jq -r --arg p "$plat" '.channels.Stable.downloads["chrome-headless-shell"] | map(select(.platform==$p))[0].url' "$CJ")
  z="$DL/$dirname-$CVER.zip"
  dl "$url" "$z"
  case "$plat" in linux64) dest="$ROOT/vendor/chrome-headless-shell/linux-x64";; *) dest="$ROOT/vendor/chrome-headless-shell/linux-arm64";; esac
  if [ ! -x "$dest/$dirname/chrome-headless-shell" ]; then
    echo "extract $dirname"
    rm -rf "$dest/$dirname"
    unzip -q -o "$z" -d "$dest"
  fi
done
echo "$CVER" > "$ROOT/vendor/chrome-headless-shell/VERSION"

# ---------- FFmpeg (static, both linux arches) ----------
for arch in amd64 arm64; do
  case "$arch" in amd64) dest="$ROOT/vendor/ffmpeg/linux-x64";; arm64) dest="$ROOT/vendor/ffmpeg/linux-arm64";; esac
  tar="$DL/ffmpeg-release-$arch-static.tar.xz"
  dl "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-$arch-static.tar.xz" "$tar"
  if [ ! -x "$dest/bin/ffmpeg" ]; then
    echo "extract ffmpeg $arch"
    tmpd="$DL/extract-ffmpeg-$arch"; rm -rf "$tmpd"; mkdir -p "$tmpd"
    tar -xJf "$tar" -C "$tmpd"
    inner="$(find "$tmpd" -mindepth 1 -maxdepth 1 -type d -name 'ffmpeg-[0-9]*' | head -1)"
    rm -rf "$dest"; mkdir -p "$dest/bin"
    cp "$inner/ffmpeg" "$inner/ffprobe" "$dest/bin/"
    cp "$inner/LICENSE" "$dest/" 2>/dev/null || true
  fi
done

# ---------- HyperFrames source (working tree, no history, no LFS smudge) ----------
if [ ! -d "$ROOT/hyperframes/source/packages" ]; then
  echo "clone hyperframes source"
  tmpd="$DL/hf-clone"; rm -rf "$tmpd"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/heygen-com/hyperframes "$tmpd"
  HF_SHA=$(git -C "$tmpd" rev-parse HEAD)
  rm -rf "$tmpd/.git"
  rm -rf "$ROOT/hyperframes/source"
  mkdir -p "$ROOT/hyperframes"
  mv "$tmpd" "$ROOT/hyperframes/source"
  echo "$HF_SHA" > "$ROOT/hyperframes/source/COMMIT_SHA"
fi

echo "--- sizes ---"
du -sh "$ROOT/node" "$ROOT/vendor" "$ROOT/hyperframes/source" 2>/dev/null
echo "--- big files (>95M) ---"
find "$ROOT/node" "$ROOT/vendor" "$ROOT/hyperframes/source" -type f -size +95M -exec ls -lh {} \; 2>/dev/null || true
echo done
