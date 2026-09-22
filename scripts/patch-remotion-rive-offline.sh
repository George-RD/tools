#!/usr/bin/env bash
# Make @remotion/rive work with no network.
#
# The package hardcodes its WASM location at build time:
#
#   locateFile: () => "https://unpkg.com/@rive-app/canvas-advanced@2.31.5/rive.wasm"
#
# so every render fetches the WASM from unpkg.com. That is the only network
# dependency in the Remotion Rive integration, and it makes offline rendering
# impossible. Upstream still does this in 4.0.527, so the fix lives here.
#
# What this does, idempotently:
#   1. copies rive.wasm out of @rive-app/canvas-advanced into remotion/public/,
#      so Remotion bundles it and serves it from the bundle root at render time
#   2. rewrites locateFile() in both the CJS and ESM builds to resolve that file
#      through Remotion's own staticFile(), which is correct in Studio, in
#      `remotion render`, and inside a bundle.
#
# Re-run after any npm install / Remotion upgrade — the dist files are
# overwritten by the package manager and the patch must be re-applied.
# `scripts/verify.sh` fails if the patch is missing, so this cannot be
# forgotten silently.
#
# Usage: bash scripts/patch-remotion-rive-offline.sh [--check]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly ROOT
readonly DIST="$ROOT/remotion/node_modules/@remotion/rive/dist"
readonly WASM_SRC="$ROOT/remotion/node_modules/@rive-app/canvas-advanced/rive.wasm"
readonly WASM_DST="$ROOT/remotion/public/rive.wasm"
readonly CHECK="${1-}"

if [ ! -f "$WASM_SRC" ]; then
  printf 'missing %s — run npm install in remotion/ first\n' "$WASM_SRC" >&2
  exit 1
fi
if [ ! -d "$DIST" ]; then
  printf 'missing %s — is @remotion/rive installed?\n' "$DIST" >&2
  exit 1
fi

if [ "$CHECK" = "--check" ]; then
  rc=0
  grep -rq 'unpkg.com/@rive-app' "$DIST" && { printf 'FAIL: @remotion/rive still points at unpkg\n' >&2; rc=1; }
  [ -f "$WASM_DST" ] || { printf 'FAIL: %s missing\n' "$WASM_DST" >&2; rc=1; }
  grep -rq 'staticFile(' "$DIST" || { printf 'FAIL: locateFile is not wired to staticFile\n' >&2; rc=1; }
  [ "$rc" = 0 ] && printf 'ok: @remotion/rive loads its WASM locally\n'
  exit "$rc"
fi

# 1. The WASM belongs to the Remotion project's public folder, so the bundler
#    emits it and the render server serves it from the bundle root.
mkdir -p "$(dirname "$WASM_DST")"
if [ -f "$WASM_DST" ] && cmp -s "$WASM_SRC" "$WASM_DST"; then
  printf 'have  remotion/public/rive.wasm\n'
else
  cp -f "$WASM_SRC" "$WASM_DST"
  printf 'copy  remotion/public/rive.wasm\n'
fi

# rive_fallback.wasm pairs with rive.wasm (browsers without WebAssembly
# SIMD/threading support); ship it too so no code path can reach for a CDN.
readonly FALLBACK_SRC="$ROOT/remotion/node_modules/@rive-app/canvas-advanced/rive_fallback.wasm"
if [ -f "$FALLBACK_SRC" ]; then
  cp -f "$FALLBACK_SRC" "$(dirname "$WASM_DST")/rive_fallback.wasm"
fi

# 2. Rewrite locateFile in place. Python does the edit so the multi-line ESM
#    import list stays valid.
python3 - "$DIST" <<'PY'
import re
import pathlib
import sys

dist = pathlib.Path(sys.argv[1])
patched = 0
already = 0
problems = []

CDN = re.compile(r'"https://unpkg\.com/@rive-app/canvas-advanced@[^"]*rive\.wasm"'
                 r"|'https://unpkg\.com/@rive-app/canvas-advanced@[^']*rive\.wasm'")

REMOTION_IMPORT = re.compile(r'import\s*\{([^}]*)\}\s*from\s*"remotion";')


def add_static_file_import(text):
    """Return text with `staticFile` present in the { ... } from "remotion"
    import list, rebuilding that list from its parsed names."""
    match = REMOTION_IMPORT.search(text)
    if match is None:
        return text
    names = [n.strip() for n in match.group(1).split(',')]
    names = [n for n in names if n]
    if 'staticFile' in names:
        return text
    names.append('staticFile')
    rebuilt = 'import {\n' + ''.join(f'  {n},\n' for n in names) + '} from "remotion";'
    return text[:match.start()] + rebuilt + text[match.end():]

for path in sorted(dist.rglob('*.mjs')) + sorted(dist.rglob('*.js')) + sorted(dist.rglob('*.cjs')):
    text = path.read_text(encoding='utf-8')

    if 'staticFile(' in text and 'unpkg.com/@rive-app' not in text:
        already += 1
        continue
    if not CDN.search(text):
        continue

    # ESM: needs staticFile added to the remotion import list. Rebuilding the
    # import from its parsed names is deterministic and idempotent, unlike
    # trying to splice a new element into the list with regex.
    if path.suffix == '.mjs':
        text = add_static_file_import(text)
        replacement = 'staticFile("rive.wasm")'
    else:
        # CJS: the module is already bound as remotion_1.
        replacement = 'remotion_1.staticFile("rive.wasm")'

    text = CDN.sub(replacement, text)
    path.write_text(text, encoding='utf-8')

    # Prove the file still parses: rewriting an import list is exactly the kind
    # of edit that silently produces a syntax error, and a broken dist file
    # would only surface later as a confusing render failure.
    import subprocess
    proc = subprocess.run(['node', '--check', str(path)],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        problems.append(f'{path}: patch produced invalid JS\n{proc.stderr.strip()}')
    patched += 1

if problems:
    print('\n'.join(problems), file=sys.stderr)
    sys.exit(1)
print(f'patch {patched} file(s)'
      + (f', {already} already patched' if already else ''))
PY

# 3. Prove it worked rather than assuming.
bash "$ROOT/scripts/patch-remotion-rive-offline.sh" --check
