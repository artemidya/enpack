#!/usr/bin/env python3
"""Execute delivered x64 guard/lifecycle paths with hostile fake COM/WinAPI."""
import json,struct,sys,uuid
from pathlib import Path
from test_startup_emulated import Host,qword
from check_typelib import interfaces
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_EDX,UC_X86_REG_RBX
ROOT=Path(__file__).resolve().parents[1]
class RasterHost(Host):
 def call(self,address,*args):
  if len(args)>4:self.uc.mem_write(0x200FF008+40,b''.join(qword(a) for a in args[4:]))
  return super().call(address,*args[:4])
class BleedsHost(RasterHost):
 def __init__(self,file,scenario):
  super().__init__(file,scenario);self.inc=interfaces((ROOT/'src/bleeds/x64/CorelDraw.inc').read_text('cp1251'))
  self.objects['app']=self.object('app','IVGApplication');self.objects['selection']=self.object('selection','IVGShapeRange')
 def cpuid(self,uc,_):
  uc.reg_write(UC_X86_REG_RBX,0xFEED);uc.reg_write(UC_X86_REG_ECX,0 if self.scenario=='cpu' else 1<<19);return True
 def com(self,obj,method,a):
  self.calls.append((obj,method))
  if method in ('AddRef','Release'):
   self.refcounts[obj]+=1 if method=='AddRef' else -1;assert self.refcounts[obj]>=0;return self.refcounts[obj]
  if method=='AddPluginCommand':
   assert self.string(a[1],True)=='Bleeds';return 0x80004005 if self.scenario=='register' else 0
  if method=='AdviseEvents':
   if self.scenario=='advise':return 0x80004005
   self.out(a[2],17,4)
  elif method=='UnadviseEvents':assert a[1]==17
  elif method=='Get_ActiveSelectionRange':
   if self.scenario=='selection-failure':return 0x80004005
   if self.scenario=='selection-null':self.out(a[1],0);return 0
   return self.return_object(a[1],'selection')
  elif method=='Get_Count':self.out(a[1],0 if self.scenario=='empty' else 65536,4)
  else:raise AssertionError('Unexpected geometry/UI call: '+method)
  return 0
 def run(self):
  attach=self.base+next(s.address for s in self.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name==b'AttachPlugin')
  assert self.call(attach,0)==0;out=self.alloc(8);assert self.call(attach,out)==256;self.plugin=struct.unpack('<Q',self.uc.mem_read(out,8))[0]
  assert self.callback(7,0)==0x80004003
  assert self.callback(8)==0x80004005
  assert self.callback(7,self.objects['app'])==0
  hr=self.callback(8);failed=self.scenario in ('cpu','register','advise');assert bool(hr)==failed
  if not failed:
   assert self.callback(8)==0
   assert sum(m=='AddPluginCommand' for _,m in self.calls)==1
   assert sum(m=='AdviseEvents' for _,m in self.calls)==1
   # Unrelated events and null/short/mistyped DISPPARAMS must be harmless.
   for event in (1,17,20,21):assert self.callback(6,event,0,0,1,0,0,0,0)==0
   params=self.alloc(24);args=self.alloc(72);name=self.alloc(32);self.write_string(name,'Bleeds',True);flag=self.alloc(2)
   self.uc.mem_write(params,struct.pack('<QQII',args,0,3,0));self.uc.mem_write(args+48,struct.pack('<QQQ',8,name,0));self.uc.mem_write(args+24,struct.pack('<QQQ',0x400B,flag,0))
   assert self.callback(6,21,0,0,1,params,0,0,0)==0
   actual=struct.unpack('<H',self.uc.mem_read(flag,2))[0];assert actual==(0 if self.scenario in ('empty','selection-null','selection-failure') else 65535),actual
   self.out(flag,123,2);self.out(args+24,3,2);assert self.callback(6,21,0,0,1,params,0,0,0)==0;assert self.uc.mem_read(flag,2)==b'{\0'
  assert self.callback(9)==0;assert self.callback(9)==0;assert self.callback(10)==0;assert self.callback(10)==0
  assert all(v==0 for v in self.refcounts.values()),self.refcounts
  print('PASS Bleeds:',self.scenario)
class SeamHost(RasterHost):
 def cpuid(self,uc,_):
  uc.reg_write(UC_X86_REG_RBX,0xFEED);uc.reg_write(UC_X86_REG_ECX,0xFFFFFFFF);uc.reg_write(UC_X86_REG_EDX,0xFFFFFFFF);return True
 def run(self):
  entry=self.base+next(s.address for s in self.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name==b'S');out=self.alloc(2)
  for selector,record,expected in [(0,0,0),(65535,0,1),(99,0,1),(3,0,1)]:
   self.call(entry,selector,record,0,out);assert struct.unpack('<H',self.uc.mem_read(out,2))[0]==expected
  self.call(entry,0,0,0,0)
  layout=json.loads((ROOT/'tests/raster/filter-layout.json').read_text());record=self.alloc(layout['size']);platform=self.alloc(8);self.out(platform,123)
  self.out(record+layout['platformData'],platform);self.out(record+layout['advanceState'],self.stub(lambda _:1))
  self.out(record+layout['wholeSize'],(4<<16)|4,4);self.out(record+layout['planes'],3,2);self.out(record+layout['imageMode'],3,2)
  self.call(entry,2,record,0,out);assert self.uc.mem_read(out,2)==b'\0\0'
  # Bad dimensions, channel count, and failed advanceState: reject before allocation/COM.
  for width,height,planes in [(3,4,3),(4,3,3),(16385,4,3),(4096,4096,3),(4,4,2),(4,4,5),(4,4,3)]:
   self.out(record+layout['wholeSize'],(width<<16)|height,4);self.out(record+layout['planes'],planes,2)
   self.call(entry,3,record,0,out);assert self.uc.mem_read(out,2)==b'\1\0'
  self.call(entry,5,record,0,out);assert self.uc.mem_read(out,2)==b'\0\0'
  print('PASS Seam: selectors/nulls, CPU-preserved registers, dimensions/pixels/planes, advanceState failure, idempotent cleanup')
if __name__=='__main__':
 directory=Path(sys.argv[1] if len(sys.argv)>1 else ROOT/'deliverables')
 for case in ['ok','cpu','register','advise','empty','selection-failure','selection-null']:BleedsHost(directory/'Bleedsx64.cpg',case).run()
 SeamHost(directory/'SC_x64.8bf','ok').run()
 print('8 scenarios passed; actual machine code, NOT CorelDRAW geometry/UI.')
