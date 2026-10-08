#!/usr/bin/env python3
"""Bundle the New_export UI integration with the supplied original CPG/source.

No plugin execution, registration, automatic installation or CPG rebuilding.
"""
import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_CPG_SHA256 = '8cc62d017f6cd59e51ff1f8e4c136087930a088ac34b41803e9eaa1fb05f9b5e'
INPUT_COMMIT = '13a41e519259669bc9f2566e6eb6adc6c880466c'
SOURCE_COMMIT = 'fd88547ffb69fcd8f0bc84441bd589414f918f25'


def package(cpg_path):
    cpg = Path(cpg_path).read_bytes()
    if hashlib.sha256(cpg).hexdigest() != EXPECTED_CPG_SHA256:
        raise ValueError('CPG differs from the supplied original; refusing to label it as that file')
    pe = struct.unpack_from('<I', cpg, 0x3C)[0]
    if (cpg[:2] != b'MZ' or cpg[pe:pe + 4] != b'PE\0\0'
            or struct.unpack_from('<H', cpg, pe + 4)[0] != 0x8664
            or not struct.unpack_from('<H', cpg, pe + 22)[0] & 0x2000
            or struct.unpack_from('<H', cpg, pe + 24)[0] != 0x20B):
        raise ValueError('Expected a PE32+ AMD64 DLL')
    manifest = json.loads((ROOT / 'docs/new-export-manifest.json').read_text())
    workspace = (ROOT / 'deliverables' / manifest['output']).read_bytes()
    if hashlib.sha256(workspace).hexdigest() != manifest['output_sha256']:
        raise ValueError('Workspace no longer matches its integration manifest')
    components = {
        'scope': 'Workspace UI integration, not a CorelDRAW runtime compatibility certification',
        'workspace_input': f'https://github.com/artemidya/enpack/blob/{INPUT_COMMIT}/New_export.cdws',
        'cpg_input': f'https://github.com/artemidya/enpack/blob/{INPUT_COMMIT}/DirectEnpackx64.cpg',
        'cpg_sha256': EXPECTED_CPG_SHA256,
        'cpg_rebuilt_for_this_bundle': False,
        'source_origin': f'https://github.com/fersatgit/DirectEnpack/tree/{SOURCE_COMMIT}',
        'cpg_reproducibility_from_source_asserted': False,
        'runtime_tested_in_coreldraw': False,
        'source_files': {},
    }
    files = {
        manifest['output']: workspace,
        'plugin/DirectEnpackx64.cpg': cpg,
        'README-RU.md': (ROOT / 'docs/NEW-EXPORT-INTEGRATION-RU.md').read_bytes(),
        'INTEGRATION.json': (ROOT / 'docs/new-export-manifest.json').read_bytes(),
    }
    for path in sorted((ROOT / 'upstream').rglob('*')):
        if path.is_file():
            name = path.relative_to(ROOT / 'upstream').as_posix()
            data = path.read_bytes()
            files['source/' + name] = data
            components['source_files'][name] = hashlib.sha256(data).hexdigest()
    files['COMPONENTS.json'] = (json.dumps(components, ensure_ascii=False, indent=2) + '\n').encode()
    files['SHA256SUMS.txt'] = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                                    for name, data in files.items()).encode()
    output = ROOT / 'deliverables/New_export-DirectEnpack.zip'
    with zipfile.ZipFile(output, 'w') as archive:
        for name, data in files.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 8, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    (ROOT / 'deliverables/NEW-EXPORT-SHA256SUMS.txt').write_text(''.join(
        hashlib.sha256((ROOT / 'deliverables' / name).read_bytes()).hexdigest() + '  ' + name + '\n'
        for name in (manifest['output'], output.name)), encoding='ascii')
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-cpg', type=Path, default=ROOT / 'reference/DirectEnpackx64.cpg')
    args = parser.parse_args()
    print(package(args.original_cpg))
