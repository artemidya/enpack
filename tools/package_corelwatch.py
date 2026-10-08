#!/usr/bin/env python3
"""Package external monitor sources/launcher. No CPG or settings installer."""
import hashlib
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'tools/corelwatch'
output = root / 'deliverables/CorelWatch.zip'
files = ('Start-CorelWatch.cmd', 'CorelWatch.ps1', 'NativeProbe.cs', 'README-RU.md')
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        data = (source / name).read_bytes()
        if name.endswith('.cmd'):
            data = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        info = zipfile.ZipInfo(name, date_time=(2026, 10, 8, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, data)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert archive.namelist() == list(files)
names = ('Lite-DirectEnpack.cdws', 'Touch-DirectEnpack.cdws', 'CorelWatch.zip')
(root / 'deliverables/RECOVERY-SHA256SUMS.txt').write_text(''.join(
    hashlib.sha256((root / 'deliverables' / name).read_bytes()).hexdigest() + '  ' + name + '\n'
    for name in names), encoding='ascii')
print(output)
