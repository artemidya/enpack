#!/usr/bin/env python3
"""Package, workspace, provenance and source regression tests (no Corel)."""
import hashlib,io,json,struct,unittest,zipfile
from pathlib import Path
from PIL import Image
import pefile
from bleeds_workspace import ROOT,BASE,OUTPUT,XML_PATH,ICON_PATH,fragments,integrate
class RasterTests(unittest.TestCase):
 def test_workspace_preserves_every_existing_member_and_metadata(self):
  m=json.loads((ROOT/'docs/bleeds-workspace-manifest.json').read_text())
  self.assertEqual(hashlib.sha256(BASE.read_bytes()).hexdigest(),m['source_sha256'])
  self.assertEqual(hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),m['output_sha256'])
  with zipfile.ZipFile(BASE) as base,zipfile.ZipFile(OUTPUT) as out:
   self.assertEqual(set(out.namelist())-set(base.namelist()),{ICON_PATH})
   for name in base.namelist():
    data=out.read(name)
    if name==XML_PATH:
     for f in fragments():self.assertEqual(data.count(f),1);data=data.replace(f,b'',1)
    self.assertEqual(data,base.read(name),name)
    for attr in ['date_time','external_attr','create_system','comment','extra','compress_type']:
     self.assertEqual(getattr(base.getinfo(name),attr),getattr(out.getinfo(name),attr),(name,attr))
 def test_duplicate_button_refused(self):
  with zipfile.ZipFile(OUTPUT) as z:
   with self.assertRaises(ValueError):integrate(z.read(XML_PATH))
 def test_icon_is_upstream_bitmap_not_redesigned(self):
  bmp=Image.open(ROOT/'vendor/Bleeds/Readme/icon.bmp').convert('RGB')
  with zipfile.ZipFile(OUTPUT) as z:icon=Image.open(io.BytesIO(z.read(ICON_PATH))).convert('RGBA')
  self.assertEqual(icon.size,(16,16));self.assertEqual(icon.getchannel('A').tobytes().count(b'\xff'),61)
  for y in range(16):
   for x in range(16):
    rgb=bmp.getpixel((x,y));self.assertEqual(icon.getpixel((x,y)),rgb+(0 if rgb==(255,255,255) else 255,))
 def test_bleeds_geometry_and_dialog_are_unchanged(self):
  old=(ROOT/'vendor/Bleeds/x64/Bleedsx64.asm').read_text('cp1251');new=(ROOT/'src/bleeds/x64/Bleedsx64.asm').read_text('cp1251')
  self.assertEqual(old[old.index('proc GetImageData'):old.index('QueryInterface:')],new[new.index('proc GetImageData'):new.index("include 'Lifecycle27.inc'")])
  self.assertEqual((ROOT/'vendor/Bleeds/x64/CorelDraw.inc').read_bytes(),(ROOT/'src/bleeds/x64/CorelDraw.inc').read_bytes())
 def test_seam_worker_math_is_unchanged(self):
  old=(ROOT/'vendor/Seam-Carving/x64/SC_x64.asm').read_text('cp1251');new=(ROOT/'src/seamcarving/x64/SC_x64.asm').read_text('cp1251')
  old=old[old.index('proc SeamCarving'):old.index('  mov     [CarvingThread],0')]
  new=new[new.index('proc SeamCarving'):new.index('  .WorkerDone:')].replace('    cmp [CancelRequested],0\n    jne .WorkerDone\n','')
  self.assertEqual(old,new)
 def test_x64_exports_and_no_unsafe_seam_apis(self):
  for filename,export in [('Bleedsx64.cpg',b'AttachPlugin'),('WEBP4CDRx64.cpg',b'AttachPlugin'),('SC_x64.8bf',b'S')]:
   pe=pefile.PE(str(ROOT/'deliverables'/filename));self.assertEqual(pe.FILE_HEADER.Machine,0x8664);self.assertTrue(pe.FILE_HEADER.Characteristics&0x2000)
   self.assertIn(export,[s.name for s in pe.DIRECTORY_ENTRY_EXPORT.symbols])
   if export==b'S':
    imports={i.name for dll in pe.DIRECTORY_ENTRY_IMPORT for i in dll.imports}
    self.assertFalse({b'TerminateThread',b'CoCreateInstance',b'DeleteDC'}&imports)
    self.assertTrue({b'GetActiveObject',b'CloseHandle',b'ReleaseDC',b'CoUninitialize'}<=imports)
 def test_package_checksums_and_no_legacy_binary_replacements(self):
  manifest=json.loads((ROOT/'docs/raster-build-manifest.json').read_text())
  self.assertFalse(manifest['runtime_coreldraw_tested'])
  with zipfile.ZipFile(ROOT/'deliverables/Raster-Addons-27.zip') as z:
   self.assertIsNone(z.testzip());self.assertEqual(len(z.namelist()),len(set(z.namelist())))
   binaries=[n for n in z.namelist() if n.endswith(('.cpg','.8bf'))]
   self.assertEqual(set(binaries),{'Addons/Bleedsx64.cpg','Addons/WEBP4CDRx64.cpg','Plugins/SC_x64.8bf'})
   for line in z.read('SHA256SUMS.txt').decode().splitlines():
    digest,name=line.split('  ',1);self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(),digest,name)
   for name,digest in manifest['sha256'].items():self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(),digest,name)
   for filename in ['Bleedsx64.cpg','WEBP4CDRx64.cpg','SC_x64.8bf']:
    member=('Plugins/' if filename.endswith('8bf') else 'Addons/')+filename
    self.assertEqual(z.read(member),(ROOT/'deliverables'/filename).read_bytes())
   self.assertFalse(any('/lib/' in n or '/link/' in n for n in z.namelist()))
 def test_outer_checksums(self):
  for line in (ROOT/'deliverables/RASTER-SHA256SUMS.txt').read_text().splitlines():
   digest,name=line.split('  ',1);self.assertEqual(hashlib.sha256((ROOT/'deliverables'/name).read_bytes()).hexdigest(),digest)
if __name__=='__main__':unittest.main()
