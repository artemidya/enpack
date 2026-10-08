#!/usr/bin/env python3
"""Package only three NEW add-ons; never bundle/replace working DirectEnpack/SmartDepart binaries."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
PINS={'Bleeds':'718652d076332f0bdad7b006db727c6822ce0d9b','Seam-Carving':'3211483ad5b8af163d563770042e9b7b01972da7','WEBP4CDR':'c6c03d2ade9b50588eaa456d34a84ad8934b364e','libwebp':'4fa21912338357f89e4fd51cf2368325b59e9bd9'}
def package():
 files={}
 for name in ['Bleedsx64.cpg','WEBP4CDRx64.cpg']:files['Addons/'+name]=ROOT/'deliverables'/name
 files['Plugins/SC_x64.8bf']=ROOT/'deliverables/SC_x64.8bf'
 workspace='New_export-DirectEnpack-SmartDepart-Bleeds.cdws';files['Workspace/'+workspace]=ROOT/'deliverables'/workspace
 files['README-RU.md']=ROOT/'docs/RASTER-ADDONS-27-RU.md'
 for name in ['raster-abi-27.2.md','bleeds-workspace-manifest.json']:files['docs/'+name]=ROOT/'docs'/name
 for directory in ['bleeds','seamcarving','webp4cdr']:
  for p in (ROOT/'src'/directory).rglob('*'):
   if p.is_file():files['sources/adapted/'+directory+'/'+p.relative_to(ROOT/'src'/directory).as_posix()]=p
 for name in ['Bleeds','Seam-Carving','WEBP4CDR']:
  for p in (ROOT/'vendor'/name).rglob('*'):
   if not p.is_file() or any(x in ('lib','link') for x in p.relative_to(ROOT/'vendor'/name).parts):continue
   files['sources/upstream/'+name+'/'+p.relative_to(ROOT/'vendor'/name).as_posix()]=p
 for p in (ROOT/'docs/licenses').rglob('*'):
  if p.is_file():files['licenses/'+p.relative_to(ROOT/'docs/licenses').as_posix()]=p
 # Tools refer to repository-relative paths. Full reproducible checkout is linked in manifest.
 for name in ['build_raster.py','adapt_raster_sources.py','bleeds_workspace.py','check_raster_abi.py','test_raster_emulated.py','test_webp_windows.cpp','test_raster.py','package_raster.py']:
  files['tools/'+name]=ROOT/'tools'/name
 manifest={'target':'CorelDRAW Technical Suite 27 x64, Windows 10/11','upstream_pins':PINS,'repository':'https://github.com/artemidya/enpack/tree/arena/4cf01c57-enpack','toolchain':{'FASM':'1.73.35; tools/bootstrap-fasm.sh pinned source','WEBP4CDR':'Zig 0.13.0 / Clang 18.1.6; libwebp 1.6.0; native MSVC build cross-check in CI'},'runtime_coreldraw_tested':False,'notes':['Only Bleeds adds a workspace button.','Windows tests do not prove CorelDRAW geometry/UI compatibility.','Rebuild/test scripts use the full repository layout, not this rearranged installation archive.','Upstream Microsoft linker executables and bundled static libraries are intentionally excluded.'],'sha256':{name:sha(p) for name,p in sorted(files.items())}}
 text=json.dumps(manifest,ensure_ascii=False,indent=2)+'\n';(ROOT/'docs/raster-build-manifest.json').write_text(text)
 content={name:p.read_bytes() for name,p in files.items()};content['BUILD-MANIFEST.json']=text.encode()
 checksums=''.join(f'{hashlib.sha256(b).hexdigest()}  {n}\n' for n,b in sorted(content.items()));content['SHA256SUMS.txt']=checksums.encode()
 output=ROOT/'deliverables/Raster-Addons-27.zip'
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for name,data in sorted(content.items()):
   info=zipfile.ZipInfo(name,(2026,10,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,data)
 names=['Raster-Addons-27.zip','Bleedsx64.cpg','WEBP4CDRx64.cpg','SC_x64.8bf',workspace]
 (ROOT/'deliverables/RASTER-SHA256SUMS.txt').write_text(''.join(f'{sha(ROOT/"deliverables"/n)}  {n}\n' for n in names))
 print(output,output.stat().st_size,'bytes')
if __name__=='__main__':package()
