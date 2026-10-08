#!/usr/bin/env python3
"""Rebuild FASM binaries and optionally cross-build WEBP4CDR using Zig 0.13.0.

Run bootstrap-fasm.sh first. Python environment needs cmake, ninja, ziglang==0.13.0.
Windows alternative: cmake -S src/webp4cdr -B build/native -A x64
                    cmake --build build/native --config Release --target WEBP4CDRx64
Outputs only under build/, never writes Corel folders or deliverables.
"""
import argparse,hashlib,os,subprocess,sys,tarfile,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--webp',action='store_true');args=p.parse_args()
os.chdir(ROOT);(ROOT/'build').mkdir(exist_ok=True)
for plugin,name,out in [('bleeds','Bleedsx64.asm','Bleedsx64.cpg'),('seamcarving','SC_x64.asm','SC_x64.8bf')]:
 subprocess.run([str(ROOT/'.tools/fasm-current'),'-m','131072',str(ROOT/'src'/plugin/'x64'/name),str(ROOT/'build'/out)],env=dict(os.environ,INCLUDE=str(ROOT/'.tools/include')+os.sep),check=True)
if args.webp:
 import ziglang
 zig=Path(ziglang.__file__).parent/'zig'
 if subprocess.check_output([str(zig),'version'],text=True).strip()!='0.13.0':raise ValueError('Expected pinned Zig 0.13.0')
 source=ROOT/'.tools/libwebp'
 if not (source/'CMakeLists.txt').exists():
  archive=ROOT/'.tools/libwebp-1.6.0.tar.gz'
  urllib.request.urlretrieve('https://codeload.github.com/webmproject/libwebp/tar.gz/4fa21912338357f89e4fd51cf2368325b59e9bd9',archive)
  if hashlib.sha256(archive.read_bytes()).hexdigest()!='923f3382a47a2af185c3240c954cf004428b237bd7317413a95146d01eb4b94b':raise ValueError('libwebp archive checksum mismatch')
  source.mkdir(exist_ok=True)
  with tarfile.open(archive) as tar:
   for member in tar.getmembers():
    parts=Path(member.name).parts[1:]
    if not parts:continue
    if member.issym() or member.islnk() or '..' in parts:raise ValueError('Unexpected archive link/path')
    member.name='/'.join(parts);tar.extract(member,source,filter='data')
 for cmd in ('cc','c++','ar','ranlib'):
  wrapper=ROOT/'.tools'/('zig-'+cmd);target=' -target x86_64-windows-gnu' if cmd in ('cc','c++') else ''
  wrapper.write_text(f'#!/bin/sh\nexec "{zig}" {cmd}{target} "$@"\n');wrapper.chmod(0o755)
 toolchain=ROOT/'.tools/windows.cmake'
 toolchain.write_text('set(CMAKE_SYSTEM_NAME Windows)\nset(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)\n'+''.join(f'set(CMAKE_{kind} "{ROOT}/.tools/zig-{cmd}" CACHE FILEPATH "" FORCE)\n' for kind,cmd in [('C_COMPILER','cc'),('CXX_COMPILER','c++'),('AR','ar'),('RANLIB','ranlib')]))
 subprocess.run(['cmake','-S','src/webp4cdr','-B','build/webp','-G','Ninja','-DCMAKE_TOOLCHAIN_FILE='+str(toolchain),'-DWEBP_SOURCE='+str(source),'-DCMAKE_BUILD_TYPE=Release'],check=True)
 subprocess.run(['cmake','--build','build/webp','--target','WEBP4CDRx64','-j','2'],check=True)
print('Built into build/; no installed or delivered files overwritten.')
