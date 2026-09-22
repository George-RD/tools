#!/bin/bash
# Install rive-cli from https://releases.rive.app/cli
#
#   curl -fsSL https://releases.rive.app/cli/install.sh | sh
#
# Optional env:
#   RIVE_VERSION       pin a release (e.g. 0.1.0); default is latest
#   RIVE_HOME          install home (versions/, current, default); default $HOME/.rive
#   RIVE_INSTALL_DIR   muxer path's directory; default $RIVE_HOME/bin
#   RIVE_BASE_URL      override the CDN (tests / mirrors)
#
# Trust: SHA-256 the tarball against the manifest, extract only `rive`,
# reject a symlink. After that ~/.rive is user-owned — no sidecar, no
# world-writable fail-closed, no hash of a copied PATH muxer.
set -euo pipefail

BASE_URL="${RIVE_BASE_URL:-https://releases.rive.app/cli}"

HOME_DIR="${RIVE_HOME:-${HOME:-.}/.rive}"
INSTALL_DIR="${RIVE_INSTALL_DIR:-$HOME_DIR/bin}"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
Darwin)
    case "$uname_m" in
    arm64) artifact_key="darwin-arm64" ;;
    *)
        echo "rive-cli is not shipped for macOS $uname_m yet (Apple Silicon only)." >&2
        exit 1
        ;;
    esac
    ;;
Linux)
    case "$uname_m" in
    x86_64 | amd64) artifact_key="linux-x64" ;;
    *)
        echo "rive-cli is not shipped for Linux $uname_m yet (x86_64 only)." >&2
        exit 1
        ;;
    esac
    ;;
MINGW* | MSYS* | CYGWIN*)
    echo "Use install.ps1 on Windows:" >&2
    echo "  irm https://releases.rive.app/cli/install.ps1 | iex" >&2
    exit 1
    ;;
*)
    echo "rive-cli is not shipped for $uname_s yet." >&2
    exit 1
    ;;
esac

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "install.sh needs '$1' on PATH" >&2
        exit 1
    }
}
need_cmd curl
need_cmd tar
need_cmd python3

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

install_binary() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    local tmp_bin="$dest.new"
    cp "$src" "$tmp_bin"
    chmod 755 "$tmp_bin"
    mv -f "$tmp_bin" "$dest"
    if [[ "$uname_s" == "Darwin" ]]; then
        xattr -d com.apple.quarantine "$dest" 2>/dev/null || true
    fi
}

if [[ -n "${RIVE_VERSION:-}" ]]; then
    manifest_url="$BASE_URL/v${RIVE_VERSION}/manifest.json"
else
    manifest_url="$BASE_URL/latest/manifest.json"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching $manifest_url"
curl -fsSL "$manifest_url" -o "$tmp/manifest.json"

parsed="$(
    python3 - "$tmp/manifest.json" "$artifact_key" <<'PY'
import json, re, sys

path, key = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    manifest = json.load(f)
art = manifest.get("artifacts", {}).get(key)
if not art:
    raise SystemExit(f"manifest has no artifact '{key}'")

def emit(name, value, pattern):
    if not isinstance(value, str) or not re.fullmatch(pattern, value):
        raise SystemExit(f"invalid {name} in manifest")
    print(value)

def safe_segment(value):
    return (
        isinstance(value, str)
        and 0 < len(value) <= 64
        and ".." not in value
        and re.fullmatch(r"[0-9A-Za-z._-]+", value) is not None
    )

version = manifest["version"]
if not safe_segment(version):
    raise SystemExit("invalid version in manifest")
print(version)

rel_path = art["path"]
prefix = f"v{version}/"
name = rel_path[len(prefix) :] if isinstance(rel_path, str) else ""
if not isinstance(rel_path, str) or not rel_path.startswith(prefix) or not safe_segment(name):
    raise SystemExit("invalid artifact path in manifest")
print(rel_path)

sha = art["sha256"]
if isinstance(sha, str):
    sha = sha.lower()
emit("expect_sha", sha, r"[0-9a-f]{64}")
PY
)" || exit 1

{
    IFS= read -r version
    IFS= read -r rel_path
    IFS= read -r expect_sha
} <<< "$parsed"

if [[ -z "$version" || -z "$rel_path" || -z "$expect_sha" ]]; then
    echo "failed to parse $manifest_url" >&2
    exit 1
fi
if [[ -n "${RIVE_VERSION:-}" && "$version" != "$RIVE_VERSION" ]]; then
    echo "manifest version $version does not match requested $RIVE_VERSION" >&2
    exit 1
fi

tarball_url="$BASE_URL/$rel_path"
archive="$tmp/rive.tar.gz"

echo "Downloading rive $version ($artifact_key)"
curl -fsSL "$tarball_url" -o "$archive"

got_sha="$(sha256_file "$archive")"
if [[ "$got_sha" != "$expect_sha" ]]; then
    echo "checksum mismatch for $tarball_url" >&2
    echo "  expected $expect_sha" >&2
    echo "  got      $got_sha" >&2
    exit 1
fi

# Validate the member list before writing anything. Selecting `-- docs` matches
# by prefix, so `docs/../../x` is inside the selection; tar refuses those itself,
# but relying on that makes a rejection indistinguishable from an absent member.
members="$(tar -tzf "$archive")"
if printf '%s\n' "$members" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\|:)'; then
    echo "archive contains an unsafe path" >&2
    exit 1
fi
tar -xzf "$archive" -C "$tmp" -- rive
# Absent, not hostile: anything hostile was refused above.
for tree in docs samples; do
    # Two patterns rather than an alternation: "\$" is a literal dollar in BRE
    # by spec, so an escaped end-of-line anchor is implementation-dependent.
    if printf '%s\n' "$members" | grep -q -e "^$tree/" -e "^$tree\$"; then
        tar -xzf "$archive" -C "$tmp" -- "$tree"
    fi
done
if [[ -L "$tmp/rive" || ! -f "$tmp/rive" ]]; then
    echo "tarball did not contain a 'rive' binary" >&2
    exit 1
fi
# A symlink anywhere under docs -- including docs itself -- would be followed
# by the copy below. Test -L before -d, since -d follows the link and would
# happily report a link to /etc as a directory.
for tree in docs samples; do
    if [[ -L "$tmp/$tree" ]]; then
        echo "refusing $tree: not a directory" >&2
        exit 1
    fi
    if [[ -d "$tmp/$tree" ]] && find "$tmp/$tree" -type l | read -r _; then
        echo "refusing $tree containing symlinks" >&2
        exit 1
    fi
done

# Payload in the version cache. PATH muxer is a hardlink to that file
# (copy if the filesystem cannot hardlink). A copy is not hashed against
# the payload; replacing the PATH binary is already past that boundary.
payload="$HOME_DIR/versions/$version/rive"
install_binary "$tmp/rive" "$payload"

# Docs sit beside the payload, which is where `rive docs` looks. An older
# tarball has none; the command then reports that rather than failing here.
for tree in docs samples; do
    if [[ -d "$tmp/$tree" ]]; then
        rm -rf "$HOME_DIR/versions/$version/$tree"
        cp -R "$tmp/$tree" "$HOME_DIR/versions/$version/$tree"
    fi
done
mkdir -p "$INSTALL_DIR"
muxer="$INSTALL_DIR/rive"
# Hardlink via a temp name, then rename, so PATH `rive` is never unlinked
# out from under a concurrent exec (same pattern as install_binary).
if ln -f "$payload" "$muxer.new" 2>/dev/null; then
    mv -f "$muxer.new" "$muxer"
    if [[ "$uname_s" == "Darwin" ]]; then
        xattr -d com.apple.quarantine "$muxer" 2>/dev/null || true
    fi
else
    rm -f "$muxer.new"
    install_binary "$payload" "$muxer"
fi
mkdir -p "$HOME_DIR"
printf '%s\n' "$version" >"$HOME_DIR/current.new"
mv -f "$HOME_DIR/current.new" "$HOME_DIR/current"
printf '%s\n' "$version" >"$HOME_DIR/default.new"
mv -f "$HOME_DIR/default.new" "$HOME_DIR/default"

echo "Installed rive $version to $INSTALL_DIR/rive"
echo "Version cache: $HOME_DIR/versions/$version/rive"

case ":$PATH:" in
*":$INSTALL_DIR:"*) ;;
*)
    echo
    echo "Add $INSTALL_DIR to your PATH:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac

if [[ "$uname_s" == "Linux" ]]; then
    echo
    echo "Watch mode needs libEGL, libGLESv2, and libX11 at runtime."
    echo "--once / --test do not."
fi

# Every row of the card a bare `rive` prints, plus `rive login` -- this is the
# one moment we know they have never signed in, and watch / --once / --publish
# all need it -- and `rive --help`, which the card carries as a footer line
# rather than a row. Keep the shared rows in step with printFirstRun().
echo
echo "Get started:"
echo "  rive login              sign in with your Rive account"
echo "  rive create myproject   scaffold a project in ./myproject"
echo "  rive myproject          build and watch it"
echo "  rive docs               documentation; new to Rive, start here"
echo "  rive samples            runnable examples to copy from"
echo "  rive --help             every command and flag"
