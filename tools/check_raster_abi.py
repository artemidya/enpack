#!/usr/bin/env python3
"""Check every early-bound Corel method used by Bleeds/Seam against user's 27.2 TLB."""
import re, hashlib, sys
from pathlib import Path
from check_typelib import TypeLibrary,interfaces
ROOT=Path(__file__).resolve().parents[1]
def check(tlb_file):
 data=Path(tlb_file).read_bytes();tlb=TypeLibrary(data);failed=[];lines=['# Raster add-ons: x64 ABI metadata check','',f'VGCoreAuto {tlb.version}, SHA256 `{hashlib.sha256(data).hexdigest()}`','', 'Slots only: not a CorelDRAW runtime or geometry test.','']
 for plugin,incfile in [('bleeds','x64/CorelDraw.inc'),('seamcarving','CorelDraw.inc')]:
  directory=ROOT/'src'/plugin;inc=interfaces((directory/incfile).read_text('cp1251'))
  asm='\n'.join(p.read_text('cp1251') for p in directory.rglob('*') if p.suffix in ('.asm','.inc') and p.name not in ('CorelDraw.inc','Photoshop.inc','OpenGL.inc'))
  asm='\n'.join(l.split(';')[0] for l in asm.splitlines())
  objects=dict(re.findall(r'^(\w+)\s+(I\w+)\s*$',asm,re.M))
  calls={(objects[o],m) for o,m in re.findall(r'cominvk\s+(\w+),(\w+)',asm)}|set(re.findall(r'comcall\s+[^,\n]+,(I\w+),(\w+)',asm))
  lines+=['## '+plugin,'','| Interface.method | Source slot | TLB slot |','|---|---:|---:|']
  for interface,method in sorted(calls):
   if method in ('QueryInterface','AddRef','Release'):continue
   actual=inc[interface].index(method)
   matches=[m['slot'] for m in tlb.types[interface] if m['name'].casefold()==method.casefold()]
   if matches!=[actual]:failed.append((plugin,interface,method,actual,matches))
   lines.append(f'| {interface}.{method} | {actual} | {matches} |')
 lines+=['','WEBP4CDR uses IDispatch names (no inherited Corel vtable offsets).', '', f'Mismatches: {len(failed)}',repr(failed) if failed else 'PASS','']
 (ROOT/'docs/raster-abi-27.2.md').write_text('\n'.join(lines));return bool(failed)
if __name__=='__main__':sys.exit(check(sys.argv[1]))
