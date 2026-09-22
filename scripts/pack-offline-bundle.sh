#!/usr/bin/env bash
# Build the Linux-x64 offline bundle for a sandbox that can neither clone this
# repository nor download anything: a single tar.gz, split into parts small
# enough for release assets / workflow artifacts, with a version manifest and
# SHA-256 checksums.
#
# Scope (Linux x64 only, per the consumer's request):
#   node, Chrome Headless Shell + its libraries, FFmpeg, HyperFrames (source +
#   CLI), the Remotion project tree including node_modules and the integrations
#   added here (@remotion/rive, @remotion/three, three, @react-three/fiber),
#   the official Rive CLI with its QEMU layer, local test assets, and the
#   scripts that verify all of it.
#
# Excluded on purpose: .git, .downloads (build scratch, ~1.1 GB), .verify
# (verification scratch), .archives (the repository's own committed archives —
# this bundle ships the extracted trees instead), rive-official/home (runtime
# state and where `rive login` writes credentials), and the linux-arm64 halves
# of everything.
#
# Usage:
#   bash scripts/pack-offline-bundle.sh              # build into .bundle/
#   bash scripts/pack-offline-bundle.sh --part-mib 1900
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly ROOT
cd "$ROOT"

PART_MIB=1900          # under GitHub's 2 GiB per-file limit for release assets
STAGE="$ROOT/.bundle"
NAME="tools-linux-x64-offline"

while [ $# -gt 0 ]; do
  case "$1" in
    --part-mib) PART_MIB="$2"; shift 2 ;;
    *) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
  esac
done

readonly PART_BYTES=$((PART_MIB * 1024 * 1024))

# --- staging ----------------------------------------------------------------
# Paths are relative to the repo root inside the tarball, so extracting the
# bundle wherever it lands reproduces the repository layout.
INCLUDE=(
  node/linux-x64
  vendor/chrome-headless-shell/linux-x64
  vendor/chrome-libs/linux-x64
  vendor/ffmpeg/linux-x64
  vendor/gsap
  vendor/chrome-launch.sh
  hyperframes/source
  hyperframes/cli
  hyperframes/bin
  hyperframes/LFS_STATUS.md
  remotion
  rive-official
  scripts
  fixtures
  ci
  setup.sh
  README.md
)

# Drop the arm64 halves and runtime state from what would otherwise be included
# wholesale, and never let the bundle pick up scratch directories.
EXCLUDE=(
  --exclude='.*/node_modules/.remotion/chrome-headless-shell/linux-arm64'
  --exclude='./remotion/node_modules/.remotion/chrome-headless-shell/linux-arm64'
  --exclude='./node/linux-arm64'
  --exclude='./vendor/*/linux-arm64'
  --exclude='./rive-official/home'
  --exclude='./.downloads'
  --exclude='./.verify'
  --exclude='./.bundle'
  --exclude='./.git'
  --exclude='*.core'
)

echo "== packing $NAME =="
rm -rf "$STAGE"
mkdir -p "$STAGE"

# Present the paths that exist; skip any that do not (keeps this runnable on a
# checkout where an optional piece was never vendored).
present=()
for p in "${INCLUDE[@]}"; do
  [ -e "$p" ] && present+=("$p") || echo "  skip (absent): $p"
done

# --- version manifest -------------------------------------------------------
# Every tool that matters, with the version that is actually installed, so the
# receiving side can tell what it got without running anything.
echo "-- writing VERSION-MANIFEST.txt"
MANIFEST="$STAGE/VERSION-MANIFEST.txt"
{
  echo "# tools — Linux x64 offline bundle"
  echo "# built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# host arch: $(uname -m)  builder: $(uname -sr)"
  echo "# commit: $(git rev-parse HEAD 2>/dev/null || echo '(not a git checkout)')"
  echo "# branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
  echo
  echo "## toolchain versions"
  [ -x node/linux-x64/bin/node ] && echo "node                $(node/linux-x64/bin/node --version 2>/dev/null)"
  [ -x node/linux-x64/bin/npm ]  && echo "npm                 $(node/linux-x64/bin/npm --version 2>/dev/null)"
  [ -x vendor/ffmpeg/linux-x64/bin/ffmpeg ] && \
    echo "ffmpeg              $(vendor/ffmpeg/linux-x64/bin/ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')"
  if [ -f remotion/node_modules/remotion/package.json ]; then
    echo "remotion            $(jq -r .version remotion/node_modules/remotion/package.json 2>/dev/null)"
  fi
  for p in "@remotion/cli" "@remotion/renderer" "@remotion/bundler" "@remotion/compositor-linux-x64-gnu" \
           "@remotion/rive" "@remotion/three" "three" "@react-three/fiber" "@rive-app/canvas-advanced" \
           "react" "react-dom" "zod" "typescript"; do
    f="remotion/node_modules/$p/package.json"
    if [ -f "$f" ]; then
      printf '%-28s %s\n' "$p" "$(jq -r .version "$f" 2>/dev/null)"
    else
      printf '%-28s %s\n' "$p" "ABSENT"
    fi
  done
  if [ -f hyperframes/cli/node_modules/hyperframes/package.json ]; then
    echo "hyperframes         $(jq -r .version hyperframes/cli/node_modules/hyperframes/package.json 2>/dev/null)"
  fi
  if [ -x rive-official/bin/rive ]; then
    printf 'rive-cli            %s\n' "$(timeout 120 rive-official/bin/rive --version 2>/dev/null | tail -1 || echo '(not runnable here)')"
  fi
  [ -f remotion/node_modules/.remotion/chrome-headless-shell/VERSION ] && \
    echo "chrome-headless-shell (remotion pin) $(cat remotion/node_modules/.remotion/chrome-headless-shell/VERSION)"
  echo
  echo "## browser pins"
  ls vendor/chrome-headless-shell/linux-x64/ 2>/dev/null | sed 's/^/chrome-headless-shell: /'
  echo
  echo "## bundled integrations"
  echo "remotion rive wasm:   remotion/public/rive.wasm"
  echo "remotion rive fallback: remotion/public/rive_fallback.wasm"
  echo "rive demo fixture:    remotion/public/rive-demo.riv"
  echo "rive smoke fixture:   fixtures/rive/neutral (source) + fixtures/rive/animated (source)"
  echo "gsap (offline):       vendor/gsap/"
  echo
  echo "## verify locally"
  echo "  ./setup.sh          # reports what is present (bundle ships payloads extracted)"
  echo "  bash scripts/verify.sh"
  echo "  bash scripts/verify-remotion-integrations.sh"
} > "$MANIFEST"
cat "$MANIFEST"

# --- build the tarball ------------------------------------------------------
echo
echo "-- creating tarball (this reads ~2-3 GB, expect a few minutes)"
TARBALL="$STAGE/$NAME.tar.gz"
# Deterministic-ish packing: sort names, drop ownership, keep permissions.
tar --sort=name \
    --owner=0 --group=0 --numeric-owner \
    "${EXCLUDE[@]}" \
    -czf "$TARBALL" \
    -C "$ROOT" "${present[@]}"

size=$(stat -c %s "$TARBALL")
printf '   %s: %.1f MiB\n' "$(basename "$TARBALL")" "$(echo "$size" | awk '{print $1/1048576}')"

# --- split if needed --------------------------------------------------------
if [ "$size" -gt "$PART_BYTES" ]; then
  echo "-- splitting into <= ${PART_MIB} MiB parts"
  ( cd "$STAGE" && split -b "$PART_MIB"M -d -a 2 "$NAME.tar.gz" "$NAME.tar.gz.part-" && rm -f "$NAME.tar.gz" )
  echo "   $(ls "$STAGE/$NAME.tar.gz.part-"* | wc -l) parts"
fi

# --- checksums --------------------------------------------------------------
echo
echo "-- SHA-256"
( cd "$STAGE" && {
    if compgen -G "$NAME.tar.gz.part-*" >/dev/null; then
      # Hash the logical archive by streaming the parts in order, so the
      # receiving side can verify the joined file against one value.
      echo "# logical archive: cat $NAME.tar.gz.part-* > $NAME.tar.gz"
      printf '%s  %s.tar.gz\n' "$(cat "$NAME.tar.gz.part-"* | sha256sum | awk '{print $1}')" "$NAME" | tee "$NAME.tar.gz.sha256"
      sha256sum "$NAME.tar.gz.part-"* > "$NAME.parts.sha256"
      cat "$NAME.parts.sha256"
    else
      sha256sum "$NAME.tar.gz" | tee "$NAME.tar.gz.sha256"
    fi
  } )

echo
echo "== done =="
echo "  staging:  $STAGE"
ls -lh "$STAGE" | sed 's/^/  /'
cat <<EOF

Next: publish and verify.
  release assets:  gh release create <tag> -R George-RD/tools $STAGE/$NAME.tar.gz.part-* $STAGE/$NAME.tar.gz.sha256
  artifact route:  dispatch .github/workflows/publish-bundle-artifact.yml with the part list
  receiving side:  cat $NAME.tar.gz.part-* > $NAME.tar.gz
                   sha256sum -c $NAME.tar.gz.sha256
                   tar -xzf $NAME.tar.gz
EOF
