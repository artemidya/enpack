#!/usr/bin/env bash
# Linux x86_64 with IA32 execution support; builds FASM 1.73.35 from pinned source.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/bootstrap .tools/include
work=$(mktemp -d "$PWD/.tools/fasm-source.XXXXXX")
trap 'rm -rf "$work"' EXIT
curl -fsSL https://codeload.github.com/the-little-language-designer/fasm-linux/tar.gz/58595b35b4a07beb48f944af1e2820854ec41ab7 \
  | tar xz --strip-components=1 -C .tools/bootstrap
printf '%s  %s\n' d66887d2e51f0ad646fd50cb4cc439b88375926f07f549b6b5aaf43f3c953eae .tools/bootstrap/fasm | sha256sum -c -
chmod +x .tools/bootstrap/fasm
curl -fsSL https://codeload.github.com/tgrysztar/fasm/tar.gz/225ce90e81e69877ab42505f7713e3d3fd531d42 \
  | tar xz --strip-components=1 -C "$work"
curl -fsSL https://codeload.github.com/insolor/fasmw_includes/tar.gz/ba9e1c06677f0155390933fa3248d1d2830c5af3 \
  | tar xz --strip-components=1 -C .tools/include
# Official source filenames are uppercase, includes inside use lowercase.
python3 - "$work" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for path in sorted(root.rglob('*'), key=lambda p: len(p.parts), reverse=True):
    if path.name != path.name.lower():
        path.rename(path.with_name(path.name.lower()))
PY
.tools/bootstrap/fasm "$work/source/linux/fasm.asm" .tools/fasm-current
chmod +x .tools/fasm-current
