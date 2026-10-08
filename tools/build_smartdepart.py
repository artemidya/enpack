#!/usr/bin/env python3
"""Build SmartDepart x64 with pinned FASM tools (never installs into CorelDRAW)."""
import argparse
import os
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--fasm', type=Path, default=ROOT / '.tools/fasm-current')
p.add_argument('--include', type=Path, default=ROOT / '.tools/include')
p.add_argument('--output', type=Path, default=ROOT / 'build/SmartDepart.cpg')
p.add_argument('--original', action='store_true')
a = p.parse_args()
source = ROOT / ('vendor/SmartDepart' if a.original else 'src/smartdepart') / 'x64/SmartDepart.asm'
output = a.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([str(a.fasm.resolve()), '-m', '131072', str(source), str(output)],
               cwd=ROOT, env=dict(os.environ, INCLUDE=str(a.include.resolve()) + os.sep), check=True)
print(output)
