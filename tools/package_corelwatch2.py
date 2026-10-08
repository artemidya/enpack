#!/usr/bin/env python3
"""Package the external hang monitor; no install/reset/replacement of CPGs."""
import hashlib,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'tools/corelwatch2'
files={p.name:p.read_bytes() for p in source.iterdir() if p.is_file()}
for name in files:
 if name.endswith('.cmd'):files[name]=files[name].replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
files['SHA256SUMS.txt']=''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n' for name,data in sorted(files.items())).encode()
output=ROOT/'deliverables/CorelWatch-2.zip'
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
 for name,data in sorted(files.items()):
  info=zipfile.ZipInfo(name,(2026,10,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,data)
with zipfile.ZipFile(output) as z:assert z.testzip() is None
versioned=ROOT/'deliverables/CorelWatch-2.0.1.zip'
versioned.write_bytes(output.read_bytes())
(ROOT/'deliverables/CORELWATCH2-SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in (output,versioned)))
print(output,output.stat().st_size)
