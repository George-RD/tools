#!/usr/bin/env bash
# One-shot setup for a fresh clone: extract committed archives, verify the
# payloads, and report what is ready. Requires only bash, tar, and one of
# zstd/gzip — plus the vendored Node for the toolchains themselves.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$ROOT"

echo "== tools setup =="

# --- extraction -------------------------------------------------------------
# .archives/*.tar.gz hold payloads too large for a single GitHub file; oversized
# ones are split into .part-NN chunks that must be concatenated in order first.
if [ -d .archives ]; then
  shopt -s nullglob
  # Reassemble any split archives into .verify/ (kept out of git).
  mkdir -p .verify
  for first in .archives/*.tar.gz.part-00; do
    [ -e "$first" ] || continue
    base="${first%.tar.gz.part-00}"
    logical="$(basename "$base").tar.gz"
    if [ ! -f ".verify/$logical" ]; then
      echo "-- reassembling $logical"
      cat "$base.tar.gz.part-"* > ".verify/$logical"
    fi
  done

  archives=(.archives/*.tar.gz .verify/*.tar.gz)
  if [ "${#archives[@]}" -gt 0 ]; then
    # Hash-check BEFORE extracting. A corrupt or truncated archive must be
    # rejected, not unpacked into the tree: a half-extracted payload would then
    # look "present" to the marker check below and poison every later run.
    declare -A WANT=()
    if [ -f .archives/MANIFEST.sha256 ]; then
      while read -r want name; do
        [ -n "${want:-}" ] && WANT["$name"]="$want"
      done < .archives/MANIFEST.sha256
    fi
    verified=0; missing_manifest=0
    for a in "${archives[@]}"; do
      name="$(basename "$a" .tar.gz)"
      want="${WANT["$name.tar.gz"]:-}"
      if [ -z "$want" ]; then
        missing_manifest=1
        printf '   no manifest entry for %s.tar.gz (cannot verify)\n' "$name"
        continue
      fi
      got="$(sha256sum "$a" | awk '{print $1}')"
      if [ "$got" != "$want" ]; then
        printf '   BAD  %s.tar.gz (hash mismatch)\n' "$name" >&2
        printf '        expected %s\n        got      %s\n' "$want" "$got" >&2
        printf 'Refusing to extract: the archives do not match MANIFEST.sha256.\n' >&2
        exit 1
      fi
      verified=$((verified+1))
    done
    [ "$verified" -gt 0 ] && echo "-- verified $verified archive(s) against MANIFEST.sha256"
    [ "$missing_manifest" = 1 ] && printf '   (some archives had no manifest entry; they are skipped, not extracted)\n'

    echo "-- extracting archive(s)"
    for a in "${archives[@]}"; do
      name="$(basename "$a" .tar.gz)"
      [ -n "${WANT["$name.tar.gz"]:-}" ] || continue   # unverifiable: refuse
      # Both Remotion browser bundles extract into the same .remotion tree, so
      # check a per-platform marker rather than the shared parent directory.
      case "$name" in
        node-linux-x64)        target=node/linux-x64 ;;
        node-linux-arm64)      target=node/linux-arm64 ;;
        chrome-headless-shell-*) target="vendor/chrome-headless-shell/${name#chrome-headless-shell-}" ;;
        chrome-libs-*)         target="vendor/chrome-libs/${name#chrome-libs-}" ;;
        remotion-browser-linux64)    target=remotion/node_modules/.remotion/chrome-headless-shell/linux64 ;;
        remotion-browser-linux-arm64) target=remotion/node_modules/.remotion/chrome-headless-shell/linux-arm64 ;;
        *)                     target="" ;;
      esac
      if [ -n "$target" ] && [ -e "$target/." ]; then
        echo "   have $name"
        continue
      fi
      echo "   extract $name"
      tar -xzf "$a" -C . || {
        printf '   FAILED to extract %s (archive corrupt?)\n' "$name" >&2
        exit 1
      }
    done
  fi
fi

# --- fix executable bits (tar preserves them, but be safe) ------------------
chmod 755 rive-official/bin/rive 2>/dev/null || true
chmod 755 rive-official/compat/qemu-x86_64-static 2>/dev/null || true
chmod 755 hyperframes/bin/hyperframes 2>/dev/null || true
chmod 755 remotion/bin/remotion 2>/dev/null || true
chmod 755 vendor/chrome-libs/run-chrome-with-vendored-libs.sh 2>/dev/null || true
for p in linux-x64 linux-arm64; do
  for c in vendor/chrome-headless-shell/$p/*/chrome-headless-shell \
           vendor/ffmpeg/$p/bin/ffmpeg vendor/ffmpeg/$p/bin/ffprobe \
           node/$p/bin/node node/$p/bin/npm node/$p/bin/npx; do
    [ -e "$c" ] && chmod 755 "$c"
  done
done
find remotion/node_modules/.remotion -type f -name 'chrome-headless-shell' -o -type f -name 'headless_shell' 2>/dev/null | while read -r f; do
  chmod 755 "$f"
done

# --- verify hashes ----------------------------------------------------------
if [ -f .archives/MANIFEST.sha256 ]; then
  echo "-- verifying archive hashes"
  # Logical archives may live in .archives/ or (after reassembly) in .verify/.
  failed=0
  while read -r want name; do
    for cand in ".archives/$name" ".verify/$name"; do
      [ -f "$cand" ] || continue
      got="$(sha256sum "$cand" | awk '{print $1}')"
      if [ "$got" = "$want" ]; then
        echo "   ok   $name"
      else
        echo "   BAD  $name (hash mismatch)"
        failed=1
      fi
      break
    done
  done < .archives/MANIFEST.sha256
  [ "$failed" = 0 ] && echo "   all archives match MANIFEST.sha256"
fi

# --- report -----------------------------------------------------------------
echo
echo "== platforms present =="
for d in node vendor/ffmpeg vendor/chrome-headless-shell; do
  for p in linux-x64 linux-arm64; do
    if [ -e "$d/$p" ]; then echo "   $d/$p"; fi
  done
done

echo
echo "== quick checks =="
detect_platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo linux-x64 ;;
    Linux-aarch64|Linux-arm64) echo linux-arm64 ;;
    *) echo unknown ;;
  esac
}
P="$(detect_platform)"
echo "   host platform: $P"
if [ -x "node/$P/bin/node" ]; then
  echo "   node: $("node/$P/bin/node" --version)"
fi
if [ -x vendor/ffmpeg/$P/bin/ffmpeg ]; then
  echo "   ffmpeg: $(vendor/ffmpeg/$P/bin/ffmpeg -version 2>/dev/null | head -1 | cut -c1-40)"
fi
if [ -x rive-official/bin/rive ]; then
  printf '   rive: '; rive-official/bin/rive --version 2>/dev/null || echo '(check failed)'
fi

cat <<'EOF'

== start here ==
  hyperframes:  ./hyperframes/bin/hyperframes --help
  remotion:     ./remotion/bin/remotion --help
  rive:         ./rive-official/bin/rive --help
  full checks:  bash scripts/verify.sh
EOF
