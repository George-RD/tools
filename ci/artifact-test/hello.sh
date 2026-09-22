#!/usr/bin/env bash
# Transfer-test payload for George-RD/tools.
# Run this on the receiving side after extracting artifact-transfer-test.tar.gz.
set -euo pipefail
cd "$(dirname "$0")"

echo "hello from George-RD/tools — artifact transfer OK"
echo "------------------------------------------------"

if [[ -x "$0" ]]; then
  echo "executable bit:  preserved"
else
  echo "executable bit:  LOST (you are probably running 'bash hello.sh')"
fi

if command -v sha256sum >/dev/null 2>&1; then
  echo "message.txt sha256: $(sha256sum message.txt | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  echo "message.txt sha256: $(shasum -a 256 message.txt | cut -d' ' -f1)"
else
  echo "message.txt sha256: (no sha256sum/shasum available)"
fi

echo "message.txt first line: $(head -n 1 message.txt)"
