#!/usr/bin/env bash
# Pack payloads that exceed GitHub's 100 MiB per-file limit into committed
# .archives/*.tar.gz bundles, record SHA-256 hashes, and optionally delete the
# raw copies from the worktree.
#
# Nothing is downloaded at clone time: the archives live in the repository, and
# setup.sh extracts them and verifies these hashes.
#
# Bundles are split per platform, and any archive that would itself exceed the
# 100 MiB limit is split into .part-NN chunks (setup.sh concatenates them back in
# order). The raw extraction paths are the ONLY entries in .gitignore, so the
# same bytes are never committed twice.
#
# Usage: pack-archives.sh [--prune]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AR="$ROOT/.archives"
mkdir -p "$AR"
cd "$ROOT"

PART_BYTES=$((90 * 1024 * 1024))   # split threshold for a single committed file

# src-path|bundle-name
BUNDLES=(
  "node/linux-x64|node-linux-x64"
  "node/linux-arm64|node-linux-arm64"
  "vendor/chrome-headless-shell/linux-x64|chrome-headless-shell-linux-x64"
  "vendor/chrome-headless-shell/linux-arm64|chrome-headless-shell-linux-arm64"
  "vendor/chrome-libs/linux-x64|chrome-libs-linux-x64"
  "vendor/chrome-libs/linux-arm64|chrome-libs-linux-arm64"
  "remotion/node_modules/.remotion/chrome-headless-shell/linux-arm64|remotion-browser-linux-arm64"
  "remotion/node_modules/.remotion/chrome-headless-shell/linux64|remotion-browser-linux64"
)

pack() {
  local src="$1" name="$2" out="$AR/$2.tar.gz"
  if [ ! -e "$src" ]; then echo "skip $name (absent)"; return; fi
  if compgen -G "$out*" >/dev/null; then echo "have $name"; return; fi
  echo "pack $name ($(du -sh "$src" | cut -f1))"
  # -C "$ROOT" keeps paths relative to the repo root.
  tar -czf "$out" -C "$ROOT" "$src"
  local sz; sz=$(stat -c %s "$out")
  printf '   -> %.1f MB' "$(echo "$sz" | awk '{print $1/1048576}')"
  if [ "$sz" -gt "$PART_BYTES" ]; then
    ( cd "$AR" && split -b 90M -d -a 2 "$2.tar.gz" "$2.tar.gz.part-" && rm -f "$2.tar.gz" )
    echo " (split into $(ls "$AR/$2.tar.gz.part-"* | wc -l) parts)"
  else
    echo ""
  fi
}

for pair in "${BUNDLES[@]}"; do
  pack "${pair%%|*}" "${pair##*|}"
done

echo "== hashes (of the logical, pre-split archives) =="
# Hash logical archives by streaming parts in order, so setup.sh can verify a
# reassembled file against this exact value.
# Only regenerate the manifest when asked (--manifest) so re-packing one bundle
# does not invalidate hashes for the others.
if [ "${1-}" = "--manifest" ] || [ ! -s "$AR/MANIFEST.sha256" ]; then
  LOGICAL="$AR/MANIFEST.sha256"
  : > "$LOGICAL"
  for pair in "${BUNDLES[@]}"; do
    name="${pair##*|}"
    if [ -f "$AR/$name.tar.gz" ]; then
      h="$(sha256sum "$AR/$name.tar.gz" | awk '{print $1}')"
    elif compgen -G "$AR/$name.tar.gz.part-*" >/dev/null; then
      h="$(cat "$AR/$name.tar.gz.part-"* | sha256sum | awk '{print $1}')"
    else
      continue
    fi
    # Relative name: setup.sh resolves it against .archives/ or .verify/.
    printf '%s  %s.tar.gz\n' "$h" "$name" >> "$LOGICAL"
  done
fi
cat "$AR/MANIFEST.sha256"

# Raw extraction paths must not be committed as well (their bytes are in the
# archives). This .gitignore lists ONLY those duplicates — nothing else is
# ignored: node_modules, sources and small binaries are committed directly.
cat > "$ROOT/.gitignore" <<'EOF'
# Raw payloads whose exact bytes are committed as .archives/*.tar.gz.
# setup.sh restores them (with hash verification).
node/linux-x64/
node/linux-arm64/
vendor/chrome-headless-shell/linux-x64/
vendor/chrome-headless-shell/linux-arm64/
vendor/chrome-libs/linux-x64/
vendor/chrome-libs/linux-arm64/
remotion/node_modules/.remotion/chrome-headless-shell/linux-arm64/
remotion/node_modules/.remotion/chrome-headless-shell/linux64/
.downloads/
.verify/

# Rive wrapper runtime state (HOME for the CLI: caches, logs, and the auth token
# that `rive login` writes). Regenerated automatically; never commit it.
rive-official/home/

# Crash artefacts: QEMU/Chrome core dumps are large, meaningless, and would
# otherwise be swept into a commit by `git add -A`.
*.core
EOF
echo "wrote .gitignore (extraction paths only)"

if [ "${1-}" = "--prune" ]; then
  for pair in "${BUNDLES[@]}"; do
    src="${pair%%|*}"
    [ -e "$src" ] && { rm -rf "$src"; echo "pruned $src"; }
  done
  echo "NOTE: run ./setup.sh to restore the payloads locally."
fi
echo done
