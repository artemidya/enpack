#!/usr/bin/env python3
"""Package an already built diagnostic CPG; does not install or publish it."""
import hashlib
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
binary = (root / 'build/DirectEnpackx64.cpg').read_bytes()
checksums = hashlib.sha256(binary).hexdigest() + '  DirectEnpackx64.cpg\n'
files = {
    'DirectEnpackx64.cpg': binary,
    'README-RU.md': (root / 'docs/INSTALL-RU.md').read_bytes(),
    'LICENSE': (root / 'upstream/LICENSE').read_bytes(),
    'SHA256SUMS.txt': checksums.encode('ascii'),
}
output = root / 'deliverables/DirectEnpack-27-diagnostic-1.zip'
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name, content in files.items():
        archive.writestr(name, content)
(root / 'deliverables/SHA256SUMS.txt').write_text(
    hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n', encoding='ascii')
print(output)
print(checksums.strip())
