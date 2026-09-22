#!/usr/bin/env bash
# Audit the lib-nocore overlays: every dependency required by a vendored
# library must be either exposed by the overlay itself or part of the host's
# core C runtime. A missing entry shows up as "<lib> => not found" at runtime,
# which is silent until a browser actually needs that code path.
#
# This exists because libz.so.1 was excluded from the overlay by mistake:
# nine vendored libraries (libcairo, libcups, libfreetype, libgio, libpng16)
# depend on it, and hosts without zlib in the default library path then failed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

uv run --no-project python3 - "$ROOT" <<'PY'
import struct, os, glob, re, sys

def needed(path):
    """Return the DT_NEEDED list of an ELF64 shared object, or None."""
    try:
        d = open(path, 'rb').read()
    except Exception:
        return None
    if d[:4] != b'\x7fELF' or d[4] != 2:
        return None
    e = '<' if d[5] == 1 else '>'
    try:
        e_shoff, = struct.unpack_from(e+'Q', d, 0x28)
        e_shentsize, = struct.unpack_from(e+'H', d, 0x3a)
        e_shnum, = struct.unpack_from(e+'H', d, 0x3c)
        secs = []
        for i in range(e_shnum):
            o = e_shoff + i*e_shentsize
            _, typ, _, _, off, size = struct.unpack_from(e+'IIQQQQ', d, o)
            link, _, _, _ = struct.unpack_from(e+'IIQQ', d, o+40)
            secs.append(dict(typ=typ, off=off, size=size, link=link))
        out = []
        for s in secs:
            if s['typ'] == 6:
                so = secs[s['link']]['off']
                for i in range(s['size'] // 16):
                    o = s['off'] + i*16
                    tag, val = struct.unpack_from(e+'qQ', d, o)
                    if tag == 1:
                        p = so + val
                        out.append(d[p:d.index(b'\0', p)].decode(errors='replace'))
        return out
    except Exception:
        return None

# Allowed to come from the host: the glibc family and C++/TLS runtimes.
CORE = re.compile(r'ld-linux.*|libc\.so\.6|libc-.*\.so|libcrypt\.so.*|libm\.so\.6|libm-.*\.so|'
                  r'libmvec\.so.*|libpthread\.so.*|libdl\.so.*|librt\.so.*|libgcc_s\.so\.*|'
                  r'libstdc\+\+\.so.*|libutil\.so.*|libresolv\.so.*|libnsl\.so.*|libanl\.so.*|'
                  r'libthread_db\.so.*|libBrokenLocale\.so.*|libc_malloc_debug\.so.*|'
                  r'libcrypto\.so.*|libssl\.so.*')

root = sys.argv[1]
rc = 0
for arch in ('linux-x64', 'linux-arm64'):
    nc = f'{root}/vendor/chrome-libs/{arch}/lib-nocore'
    if not os.path.isdir(nc):
        print(f"  SKIP {arch} (no lib-nocore)")
        continue
    exposed = {os.path.basename(p) for p in glob.glob(nc + '/*')}
    gaps, broken = {}, []
    for f in sorted(glob.glob(nc + '/*')):
        if not os.path.exists(os.path.realpath(f)):
            broken.append(os.path.basename(f))
            continue
        for dep in (needed(f) or []):
            if dep in exposed or CORE.fullmatch(dep):
                continue
            gaps.setdefault(dep, set()).add(os.path.basename(f))
    if gaps or broken:
        rc = 1
        print(f"  FAIL {arch}")
        for dep, reqs in sorted(gaps.items()):
            print(f"       unsatisfied: {dep} <- {sorted(reqs)[:3]}")
        for b in broken[:5]:
            print(f"       broken symlink: {b}")
    else:
        print(f"  PASS {arch} lib-nocore complete ({len(exposed)} entries)")
sys.exit(rc)
PY
