#!/usr/bin/env python3
"""Vendor Chrome system libraries from Debian packages (both linux arches).

chrome-headless-shell needs the usual Chrome system libraries (libnss3, libatk,
libgbm, ...). Minimal containers, sandboxes and NixOS hosts often lack them and
cannot always `apt-get install`, so this builds self-contained library
directories from Debian bookworm .debs, resolving dependencies against the
published package index. No apt/dpkg required.

Usage: vendor-chrome-libs-debian.py [--arch arm64|amd64] [--out DIR]
Writes <out>/lib and <out>/PROVENANCE.tsv.
"""
import argparse
import gzip
import io
import os
import re
import sys
import tarfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DL = os.path.join(ROOT, '.downloads', 'debs')

SUITE = 'bookworm'
MIRRORS = [
    ('https://deb.debian.org/debian', f'dists/{SUITE}'),
]

ARCH_MAP = {'arm64': 'arm64', 'amd64': 'amd64', 'x64': 'amd64', 'aarch64': 'arm64'}
OUT_MAP = {'arm64': ('linux-arm64', 'aarch64'), 'amd64': ('linux-x64', 'x86-64')}

# Chrome's runtime dependencies (Playwright install-deps + ldd additions).
SEEDS = [
    'libnss3', 'libnspr4', 'libatk1.0-0', 'libatk-bridge2.0-0', 'libatspi2.0-0',
    'libcups2', 'libdrm2', 'libgbm1', 'libxkbcommon0', 'libxcomposite1',
    'libxdamage1', 'libxfixes3', 'libxrandr2', 'libxext6', 'libx11-6',
    'libxcb1', 'libxi6', 'libexpat1', 'libglib2.0-0', 'libdbus-1-3',
    'libpango-1.0-0', 'libcairo2', 'libasound2', 'libudev1', 'libpixman-1-0',
    'libpng16-16', 'libfreetype6', 'libfontconfig1', 'libharfbuzz0b',
    'libwayland-client0', 'libwayland-server0', 'libwayland-cursor0',
    'libwayland-egl1', 'libxshmfence1', 'libxau6', 'libxdmcp6', 'libbsd0',
    'libmd0', 'libselinux1', 'libpcre2-8-0', 'libffi8', 'libzstd1', 'liblzma5',
    'libbz2-1.0', 'zlib1g', 'libgcc-s1', 'libstdc++6', 'libc6', 'libxmu6',
    'libxt6', 'libsm6', 'libice6', 'libxrender1', 'libxft2', 'libthai0',
    'libdatrie1', 'libgraphite2-3', 'libfribidi0', 'libuuid1', 'libblkid1',
    'libmount1', 'libcap2', 'libgcrypt20', 'libgpg-error0', 'libsystemd0',
    'liblz4-1', 'libacl1', 'libattr1', 'libaudit1', 'libpam0g', 'libtinfo6',
    'libgmp10', 'libnettle8', 'libhogweed6', 'libidn2-0', 'libunistring2',
    'libtasn1-6', 'libp11-kit0', 'libavahi-client3', 'libavahi-common3',
    'libkrb5-3', 'libk5crypto3', 'libkrb5support0', 'libkeyutils1',
    'libcom-err2', 'libgssapi-krb5-2', 'libcrypt1', 'libpulse0', 'libglapi0',
]
# Packages never needed at runtime for the browser itself.
SKIP_PKGS = {'debconf', 'dpkg', 'apt', 'base-files', 'base-passwd',
             'init-system-helpers', 'libc-bin', 'libcrypt1'}


def fetch(url, dest=None):
    if dest and os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    req = urllib.request.Request(url, headers={'User-Agent': 'tools-vendor/1.0'})
    with urllib.request.urlopen(req, timeout=180) as r:
        data = r.read()
    if dest:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        tmp = dest + '.part'
        with open(tmp, 'wb') as f:
            f.write(data)
        os.replace(tmp, dest)
        return dest
    return data


def load_index(arch):
    index = {}
    for mirror, dist in MIRRORS:
        url = f'{mirror}/{dist}/main/binary-{arch}/Packages.gz'
        try:
            raw = fetch(url)
        except Exception as e:
            print(f'! index {url}: {e}', file=sys.stderr)
            continue
        text = gzip.decompress(raw).decode('utf-8', 'replace')
        for para in text.split('\n\n'):
            if not para.strip():
                continue
            fields, key = {}, None
            for line in para.split('\n'):
                if line.startswith(' ') and key:
                    fields[key] += ' ' + line.strip()
                elif ': ' in line:
                    key, val = line.split(': ', 1)
                    fields[key] = val
            pkg = fields.get('Package')
            if pkg:
                index[pkg] = {
                    'version': fields.get('Version', ''),
                    'depends': fields.get('Depends', ''),
                    'filename': fields.get('Filename', ''),
                }
    return index


def parse_deps(dep_field):
    for group in dep_field.split(','):
        alt = group.strip().split('|')[0].strip()
        name = re.sub(r'\s*\(.*?\)', '', alt).strip()
        name = re.sub(r'\s*<.*?>.*', '', name).strip()
        if name:
            yield name


def resolve(seeds, index):
    want, queue, missing = {}, list(seeds), []
    while queue:
        name = queue.pop()
        if name in want or name in SKIP_PKGS:
            continue
        entry = index.get(name)
        if not entry:
            missing.append(name)
            continue
        want[name] = entry
        for dep in parse_deps(entry['depends']):
            if dep in ('libc6', 'libgcc-s1', 'libstdc++6', 'libcrypt1'):
                continue
            queue.append(dep)
    return want, missing


def extract_deb(path, out_lib, extracted):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != b'!<arch>\n':
        raise ValueError(f'not an ar archive: {path}')
    off, members = 8, {}
    while off + 60 <= len(data):
        hdr = data[off:off + 60]
        name = hdr[0:16].decode('ascii', 'replace').strip().rstrip('/')
        size = int(hdr[48:58].decode('ascii').strip())
        members[name] = data[off + 60:off + 60 + size]
        off += 60 + size + (size % 2)
        if off >= len(data):
            break
    key = next((k for k in members if k.startswith('data.tar')), None)
    if not key:
        raise ValueError(f'no data member in {path}')
    tf = tarfile.open(fileobj=io.BytesIO(members[key]), mode='r:*')
    count = 0
    for m in tf.getmembers():
        base = os.path.basename(m.name)
        if '.so' not in base:
            continue
        dest = os.path.join(out_lib, base)
        if m.issym():
            target = os.path.basename(m.linkname)
            if not os.path.exists(dest):
                try:
                    os.symlink(target, dest)
                    count += 1
                except FileExistsError:
                    pass
        elif m.isfile():
            if extracted.get(base) == 'real':
                continue
            f = tf.extractfile(m)
            if f is None:
                continue
            tmp = dest + '.tmp'
            with open(tmp, 'wb') as fh:
                fh.write(f.read())
            os.chmod(tmp, 0o755)
            os.replace(tmp, dest)
            extracted[base] = 'real'
            count += 1
    return count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arch', default='arm64', help='arm64 (default) or amd64')
    ap.add_argument('--out', default=None,
                    help='output dir (default vendor/chrome-libs/<platform>)')
    args = ap.parse_args()

    arch = ARCH_MAP.get(args.arch)
    if not arch:
        sys.exit(f'unknown arch {args.arch}')
    platform = OUT_MAP[arch][0]
    out_lib = args.out or os.path.join(ROOT, 'vendor', 'chrome-libs', platform)
    libdir = os.path.join(out_lib, 'lib')
    os.makedirs(libdir, exist_ok=True)
    os.makedirs(DL, exist_ok=True)

    print(f'== {platform} ({arch}) ==')
    print('loading Debian package index...')
    index = load_index(arch)
    print(f'  {len(index)} packages indexed')

    want, missing = resolve(SEEDS, index)
    print(f'resolve: {len(want)} packages; not in index: {sorted(set(missing))}')

    extracted, provenance = {}, []
    for name, entry in sorted(want.items()):
        fn = entry['filename']
        if not fn:
            continue
        deb = os.path.join(DL, os.path.basename(fn))
        try:
            fetch(f'https://deb.debian.org/debian/{fn}', deb)
            n = extract_deb(deb, libdir, extracted)
            provenance.append(f'{name}\t{entry["version"]}\t{fn}\t{n} files')
        except Exception as e:
            print(f'! {name}: {e}', file=sys.stderr)

    with open(os.path.join(out_lib, 'PROVENANCE.tsv'), 'w') as f:
        f.write('package\tversion\tfilename\textracted\n')
        f.write('\n'.join(provenance) + '\n')

    real = [f for f in os.listdir(libdir)
            if os.path.isfile(os.path.join(libdir, f))
            and not os.path.islink(os.path.join(libdir, f))]
    total = sum(os.path.getsize(os.path.join(libdir, f)) for f in real)
    print(f'vendor: {len(os.listdir(libdir))} entries ({len(real)} real), '
          f'{total/1e6:.1f} MB in {libdir}')


if __name__ == '__main__':
    main()
