#!/usr/bin/env python3
"""Build the x64 CPG with FASM on Linux or Windows. Does not install it."""
import argparse
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fasm', type=Path, default=ROOT / '.tools/fasm-current')
parser.add_argument('--include', type=Path, default=ROOT / '.tools/include')
parser.add_argument('--output', type=Path, default=ROOT / 'build/DirectEnpackx64.cpg')
parser.add_argument('--upstream', action='store_true', help='Build unchanged upstream source instead')
args = parser.parse_args()
fasm = args.fasm.resolve()
include = args.include.resolve()
if not fasm.is_file() or not (include / 'win64w.inc').is_file():
    parser.error('FASM/include not found. Run tools/bootstrap-fasm.sh or specify --fasm and --include.')
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, INCLUDE=str(include) + os.sep)
source = ROOT / ('upstream' if args.upstream else 'src') / 'x64/DirectEnpackx64.asm'
subprocess.run([str(fasm), '-m', '131072', str(source), str(output)],
               cwd=ROOT, env=env, check=True)
print('Built:', output)
