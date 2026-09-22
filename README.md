# tools — a self-contained toolchain for agent sandboxes

Vendored, fully-installed toolchain so an environment **without network access or
package managers** (e.g. a ChatGPT container that can only `git clone`) can run:

| Tool | What it does | Where |
|---|---|---|
| **HyperFrames** | HTML → deterministic MP4 video framework (HeyGen, Apache-2.0) | `hyperframes/` |
| **Remotion** | React → programmatic video (Remotion license, see `remotion/`) | `remotion/` |
| **Rive CLI** | Official Rive authoring CLI (RML → `.riv`), latest release | `rive-official/` |

Everything needed at runtime is in the repository: `node_modules/`, vendored
Node.js, Chrome Headless Shell + the system libraries it needs, FFmpeg, and (for
the Rive CLI) an x86-64 emulation layer.

```
node/                   vendored Node.js 22 (linux-x64 + linux-arm64)
vendor/
  chrome-headless-shell/  Chrome-for-Testing headless shell (both linux arches)
  chrome-libs/            system libraries Chrome needs (both arches)
    <platform>/lib          full set extracted from Debian packages
    <platform>/lib-nocore   relative symlinks to all of it except the core C
                            runtime — the safe thing to put on LD_LIBRARY_PATH
  chrome-launch.sh        browser entry point (puppeteer-compatible)
  ffmpeg/                 static FFmpeg + FFprobe (both linux arches)
hyperframes/
  source/                 upstream repo tree (no git history; real skill media,
                          see LFS_STATUS.md)
  cli/                    npm-installed hyperframes CLI + node_modules
  bin/hyperframes         wrapper: vendored node + browser + ffmpeg
remotion/                 Remotion template project, node_modules installed
  bin/remotion            wrapper for the installed CLI
  bin/browser-executable.sh  runs the project's pinned browser with vendored libs
rive-official/
  bin/rive                wrapper: official x86-64 payload (QEMU on aarch64)
  versions/<ver>/         official payload + bundled docs/samples (the version
                          the wrapper is pinned to; see scripts/update-rive.sh)
  compat/                 static QEMU + x86-64 libraries + Mesa software renderer
scripts/                  fetch/vendor/pack/verify scripts (reproducible rebuild)
.archives/                large payloads as committed .tar.gz + SHA-256 manifest
```

## Quick start

```bash
git clone https://github.com/George-RD/tools
cd tools
./setup.sh                # extracts .archives payloads, verifies hashes, reports
bash scripts/verify.sh    # end-to-end checks of all three toolchains
```

`setup.sh` is only needed when the payload directories are absent — i.e. on any
fresh clone. It extracts the committed archives into their normal locations and
verifies them against `.archives/MANIFEST.sha256`.

### HyperFrames

```bash
./hyperframes/bin/hyperframes init my-video
cd my-video
../../hyperframes/bin/hyperframes lint
../../hyperframes/bin/hyperframes render --output out/video.mp4
```

The wrapper pins the vendored Node, sets `HYPERFRAMES_BROWSER_PATH` to
`vendor/chrome-launch.sh` (vendored browser + libraries), and puts the vendored
FFmpeg on `PATH`. Renders use the `beginframe` capture path, which is what the
vendored chrome-headless-shell is for.

### Remotion

```bash
cd remotion
../remotion/bin/remotion render src/index.ts HelloWorld out/helloworld.mp4
../remotion/bin/remotion studio src/index.ts
```

The project's pinned browser is pre-seeded for both linux arches in
`remotion/node_modules/.remotion/chrome-headless-shell/`, and
`remotion.config.ts` points Remotion at `bin/browser-executable.sh`, which runs
it with the vendored libraries. Nothing downloads on first render.
Set `REMOTION_USE_DEFAULT_BROWSER=1` to use Remotion's own browser management.

#### Rive and three.js integrations

`@remotion/rive`, `@remotion/three`, `three` and `@react-three/fiber` are
installed at the matching Remotion version, with two ready compositions:

```bash
../remotion/bin/remotion render src/index.ts RiveShowcase out/rive.mp4
../remotion/bin/remotion render src/index.ts ThreeShowcase out/three.mp4
```

**Rive is the one part of this repository that upstream ships broken for
offline use.** `@remotion/rive` hardcodes its WASM at

```
https://unpkg.com/@rive-app/canvas-advanced@2.31.5/rive.wasm
```

so every render fetches from unpkg.com — and upstream still does this in
4.0.527. `scripts/patch-remotion-rive-offline.sh` fixes it in place: it copies
the WASM into `remotion/public/` and repoints `locateFile()` at Remotion's own
`staticFile()` in both the CJS and ESM builds, syntax-checking each file it
rewrites. It is idempotent, so re-run it after any `npm install` or Remotion
upgrade — and `scripts/verify.sh` fails if the patch is missing, so a silent
regression is not possible.

three.js needs no patching: `@remotion/three` is clean, and Remotion's headless
Chrome supplies WebGL in software, so the scene renders with no GPU and no
network.

`bash scripts/verify-remotion-integrations.sh` renders both and checks that
successive frames actually differ — a render that succeeded but showed one
frozen frame would otherwise look like a pass.

### Rive CLI

```bash
./rive-official/bin/rive --version          # e.g. rive 1.1.1
./rive-official/bin/rive create mygame
./rive-official/bin/rive mygame --verify --format=json
./rive-official/bin/rive mygame --once                    # → build/*.riv
./rive-official/bin/rive mygame --screenshot=out.png --advance=1
```

On x86-64 hosts the official binary runs natively; on aarch64 a static QEMU user
emulator runs it (no binfmt, no root). The wrapper scopes `HOME` and all state
under `rive-official/home/` and disables analytics. `rive login`, `--publish`
and `--rev` need a Rive account and network; everything else is offline.

The vendored payload tracks the **latest official release**. Check or update:

```bash
bash scripts/update-rive.sh --check    # installed vs latest, changes nothing
bash scripts/update-rive.sh            # install latest, verified by SHA-256
bash scripts/update-rive.sh 1.1.1      # or a specific version
```

Rive publishes `linux-x64` only (no linux-arm64), so aarch64 hosts always go
through the QEMU layer; `compat/` is version-independent and survives updates.
The wrapper is deliberately pinned to one version, so the CLI's own
`update`/`switch`/`uninstall` are refused — use `scripts/update-rive.sh`, which
verifies the artifact against the SHA-256 in Rive's own manifest before
installing it and repoints the pin.

## Platform support

Both linux-x64 and linux-arm64 are committed for Node, Chrome, the Chrome
libraries, FFmpeg and Remotion's browser and compositor. Each wrapper autodetects
from `uname`; `TOOLS_PLATFORM=linux-x64|linux-arm64` overrides it.

## Notes for sandboxed or unusual hosts

- **Chrome's system libraries.** Minimal containers often lack them, and some
  hosts (NixOS) have no FHS `/lib` at all. `vendor/chrome-libs/<platform>/lib`
  carries the libraries extracted from Debian packages, and `lib-nocore` is a
  relative-symlink overlay of everything except the core C runtime. Put
  `lib-nocore` — never `lib` — on `LD_LIBRARY_PATH` for a browser process: a
  full set would shadow the host's libc/loader and break process re-exec, and
  would break any Node.js process sharing that environment (OpenSSL symbols).
  `vendor/chrome-launch.sh` already does the right thing.
- **Never set the browser's `LD_LIBRARY_PATH` for Node.js.** Use
  `vendor/chrome-launch.sh` as the browser executable instead, which is exactly
  what the HyperFrames and Remotion wrappers do.
- **`os.networkInterfaces()` failures.** The Remotion wrapper preloads
  `scripts/shims/os-network-interfaces.cjs`, which only takes effect when the
  real call throws (restricted kernels reject `uv_interface_addresses`).
- **Archives.** Payload files above GitHub's 100 MiB limit are committed as
  `.archives/*.tar.gz` with a SHA-256 manifest; `setup.sh` restores them. The
  raw extraction paths are the only entries in `.gitignore` — everything else in
  this repository is committed directly, including `node_modules`.

## Rebuilding

```bash
bash scripts/fetch-vendor.sh          # Node, Chrome, FFmpeg, HyperFrames source
uv run python3 scripts/vendor-chrome-libs-debian.py --arch arm64   # and amd64
bash scripts/make-lib-nocore.sh       # build the lib-nocore overlays
bash scripts/audit-libs.sh            # check the overlays are self-sufficient
bash scripts/vendor-rive.sh           # Rive payload + QEMU + x86-64 libs + Mesa
bash scripts/update-rive.sh           # move the Rive payload to the latest release
bash scripts/fetch-hf-lfs.sh          # real LFS media for skills/src assets
bash scripts/patch-remotion-rive-offline.sh   # local Rive WASM (re-run after npm install)
bash scripts/pack-archives.sh         # .archives bundles + manifest
bash scripts/verify.sh                # end-to-end verification
```

## Offline bundle (Linux x64)

For a consumer that can neither clone this repository nor download anything,
`scripts/pack-offline-bundle.sh` builds a single self-contained archive:

```bash
bash scripts/pack-offline-bundle.sh              # -> .bundle/
bash scripts/pack-offline-bundle.sh --part-mib 1900
```

It ships the linux-x64 halves of everything (Node, Chrome Headless Shell and
its libraries, FFmpeg, HyperFrames, Remotion including `node_modules` and the
Rive/three integrations, the Rive CLI with its QEMU layer), the local test
assets, a `VERSION-MANIFEST.txt` naming every tool version, and SHA-256
checksums. It excludes the arm64 halves, `.git`, the `.downloads`/`.verify`
scratch trees, and `rive-official/home` — the Rive CLI's runtime state, which
is where `rive login` writes credentials.

Parts above the chosen size are split, and the checksum file hashes the
*logical* joined archive so the receiving side verifies the reassembled file:

```bash
cat tools-linux-x64-offline.tar.gz.part-* > tools-linux-x64-offline.tar.gz
sha256sum -c tools-linux-x64-offline.tar.gz.sha256
tar -xzf tools-linux-x64-offline.tar.gz
./setup.sh && bash scripts/verify.sh
```

`.bundle/` is gitignored: ~2 GB parts are far above GitHub's 100 MiB per-file
limit, so they are published as release assets and mirrored to a workflow
artifact (`.github/workflows/publish-bundle-artifact.yml`) rather than
committed. Two routes are maintained deliberately — a connector-only
environment can only download Actions artifacts, while release assets are the
better permanent copy (anonymous, no expiry, 2 GiB per file).

**The packer verifies its own exclusions.** tar's `--exclude` matches the member
name as spelled in the archive and fails silently when a pattern does not match,
so a first build quietly shipped `rive-official/home` and an arm64 browser.
`pack-offline-bundle.sh` now lists the finished archive and refuses to publish
if any excluded path is present; `VERSION-MANIFEST.txt` is appended inside the
archive so the receiving side needs no second download.

## Proving the integrations work offline

```bash
bash scripts/verify-offline-render.sh
```

Renders both Remotion integrations inside a network namespace with no route off
the machine, printing positive and negative controls first so a pass cannot be
a false positive. It needs unprivileged network namespaces; where those are
unavailable it exits 3 with a SKIP rather than reporting a misleading failure.

## Transfer tests

`.github/workflows/artifact-transfer-test.yml` is a manual, deliberately cheap
probe of the transfer route for environments that can neither clone nor download:

```
GitHub Actions run -> workflow artifact -> connector download -> extraction
```

Dispatch it from the Actions tab (or `gh workflow run artifact-transfer-test.yml -R George-RD/tools`)
and it uploads one tiny artifact — `artifact-transfer-test.tar.gz` plus its
`.sha256`, packed from `ci/artifact-test/` — holding a text file and an
executable shell script. The inner tar is what preserves the executable bit; the
zip wrapping every GitHub artifact does not touch it. The run log and the job
summary print both SHA-256 values, so the receiving side can confirm the bytes
it got are the bytes that were packed.

Note: GitHub does not serve Actions artifacts anonymously — the REST download
endpoint answers `401` without a token even for a public repo, so the receiving
connector must be authenticated to the repo (any token with `actions:read`, or
repo read access). Artifacts also expire (this one: 14 days), and artifact
storage is metered against the account's Actions allowance.

**Release assets are the better carrier for a full bundle.** GitHub *does* serve
release assets to anonymous clients (`200` verified on this repo), they do not
expire, and the documented limits are generous: under 2 GiB per file, up to 1000
assets per release, and no total-size or bandwidth limit. The identical test
payload is published as release `transfer-test-1` so a receiving client can
compare both routes byte for byte.

## Large payloads and this repository's packing rule

Payload files above GitHub's 100 MiB limit are committed as `.archives/*.tar.gz`
with a SHA-256 manifest; `setup.sh` restores them. When a bundle is built for a
no-network consumer, package **Linux x64 first**, include installed dependencies
(including dot-directories such as `.bin`) and local test assets, ship a version
manifest and SHA-256 checksums, and exclude credentials and runtime login state
(for this repo: `rive-official/home/`).

## Licenses

Third-party components keep their own licenses:
HyperFrames — Apache-2.0 (`hyperframes/source/LICENSE`);
Remotion — Remotion License (`remotion/node_modules/remotion/LICENSE`; free for
individuals and small/non-profit organisations, company license otherwise);
Rive CLI — Rive's terms (`rive-official/versions/<version>/docs/publishing.md`);
Node.js, Chrome for Testing and FFmpeg — their respective licenses, included
beside each copy.
