#!/usr/bin/env python3
"""Package SmartDepart only; do not replace the user's working DirectEnpack CPG."""
import hashlib
import json
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'docs/smartdepart-workspace-manifest.json').read_text())
files = {
    'plugin/SmartDepart.cpg': (ROOT / 'deliverables/SmartDepart.cpg').read_bytes(),
    manifest['output']: (ROOT / 'deliverables' / manifest['output']).read_bytes(),
    'README-RU.md': (ROOT / 'docs/SMARTDEPART-RU.md').read_bytes(),
    'WORKSPACE.json': (ROOT / 'docs/smartdepart-workspace-manifest.json').read_bytes(),
    'ABI-27.2.md': (ROOT / 'docs/smartdepart-abi-27.2.md').read_bytes(),
}
assert hashlib.sha256(files[manifest['output']]).hexdigest() == manifest['output_sha256']
for folder, label in [('vendor/SmartDepart','source-original'),('src/smartdepart','source-adapted')]:
    for path in sorted((ROOT / folder).rglob('*')):
        if path.is_file(): files[label + '/' + path.relative_to(ROOT / folder).as_posix()] = path.read_bytes()
files['COMPONENTS.json'] = (json.dumps({
    'source_origin':'https://github.com/fersatgit/SmartDepart/tree/9ff9af3af2dca74ace96179a2e9ef5175777f560',
    'compiler':'FASM 1.73.35', 'target':'CorelDRAW Technical Suite 27 x64',
    'geometry_changed':False, 'lifecycle_changed':True, 'coreldraw_runtime_tested':False,
    'directenpack_binary_included_or_replaced':False,
    'ui_route':'CDWS data-source bindings, no AppUI.xslt installation or toolbar reset',
    'cpg_sha256':hashlib.sha256(files['plugin/SmartDepart.cpg']).hexdigest(),
}, indent=2) + '\n').encode()
files['SHA256SUMS.txt'] = ''.join(hashlib.sha256(b).hexdigest() + '  ' + n + '\n' for n,b in files.items()).encode()
output = ROOT / 'deliverables/SmartDepart-27.zip'
with zipfile.ZipFile(output, 'w') as z:
    for name, content in files.items():
        info = zipfile.ZipInfo(name, (2026,10,8,0,0,0)); info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, content)
with zipfile.ZipFile(output) as z: assert z.testzip() is None
names = ['SmartDepart-27.zip','SmartDepart.cpg',manifest['output']]
(ROOT / 'deliverables/SMARTDEPART-SHA256SUMS.txt').write_text(''.join(
    hashlib.sha256((ROOT/'deliverables'/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in names), encoding='ascii')
print(output)
