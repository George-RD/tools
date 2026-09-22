#!/usr/bin/env bash
# Vendor (or update to) the newest official Rive CLI.
#
# The official CLI ships linux-x64 only; on aarch64 the payload runs under the
# static QEMU + vendored x86-64 libraries already in compat/. This script swaps
# the payload and repoints the wrapper pin; compat/ is version-independent.
#
# Usage:
#   bash scripts/update-rive.sh              # latest published version
#   bash scripts/update-rive.sh 1.1.1        # a specific version
#   bash scripts/update-rive.sh --check      # report installed vs latest, change nothing
#
# The download is verified against the SHA-256 in Rive's own manifest before it
# is installed, so a truncated or tampered artifact cannot land in versions/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${RIVE_BASE_URL:-https://releases.rive.app/cli}"
DEST="$ROOT/rive-official/versions"
WRAPPER="$ROOT/rive-official/bin/rive"
PLATFORM_KEY=linux-x64

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- what is installed now? -------------------------------------------------
installed="$(ls -1 "$DEST" 2>/dev/null | sort -V | tail -1 || true)"
[ -n "$installed" ] || installed="(none)"

# --- what is latest? -------------------------------------------------------
manifest_url="$BASE/latest/manifest.json"
[ "${1-}" = "" ] || { [ "${1-}" = "--check" ] || manifest_url="$BASE/v${1#v}/manifest.json"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL --max-time 120 -o "$tmp/manifest.json" "$manifest_url" \
  || die "could not fetch $manifest_url"

read -r latest tar_path expect_sha < <(uv run --no-project python3 - "$tmp/manifest.json" "$PLATFORM_KEY" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
a = m["artifacts"].get(sys.argv[2])
if not a:
    raise SystemExit(f"no {sys.argv[2]} artifact in manifest (has: {sorted(m['artifacts'])})")
print(m["version"], a["path"], a["sha256"])
PY
) || die "manifest does not offer $PLATFORM_KEY"

echo "installed: $installed"
echo "latest:    $latest"

if [ "${1-}" = "--check" ]; then
  [ "$installed" = "$latest" ] && echo "up to date" || echo "update available"
  exit 0
fi

if [ "$installed" = "$latest" ] && [ -x "$DEST/$latest/rive" ]; then
  echo "already at $latest — nothing to do"
  exit 0
fi

# --- fetch + verify --------------------------------------------------------
tarball="$(basename "$tar_path")"
echo "fetching $latest ($PLATFORM_KEY)"
curl -fsSL --max-time 600 -o "$tmp/$tarball" "$BASE/$tar_path" || die "download failed"
got="$(sha256sum "$tmp/$tarball" | awk '{print $1}')"
[ "$got" = "$expect_sha" ] || die "sha256 mismatch: expected $expect_sha, got $got"
echo "sha256 verified"

# --- install ---------------------------------------------------------------
new="$DEST/$latest"
rm -rf "$new"; mkdir -p "$new"
tar -xzf "$tmp/$tarball" -C "$new"
[ -x "$new/rive" ] || die "archive did not contain an executable 'rive'"
chmod 755 "$new/rive"

# --- repoint the wrapper pin ----------------------------------------------
grep -q '^readonly version=' "$WRAPPER" || die "cannot find the version pin in $WRAPPER"
sed -i "s/^readonly version=.*/readonly version=$latest/" "$WRAPPER"

for f in "$new/docs" "$new/samples"; do
  [ -d "$f" ] && printf '  %-8s %s\n' "$(basename "$f")" "$(du -sh "$f" | cut -f1)"
done

echo
echo "installed $latest -> $new (wrapper pinned to $latest)"
echo "previous versions kept: $(ls -1 "$DEST" | tr '\n' ' ')"
echo
echo "verify with:  bash scripts/verify.sh"
