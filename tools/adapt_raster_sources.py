#!/usr/bin/env python3
"""Reproducible, assertion-checked lifecycle patches; preserve upstream CP1251."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def source(path): return (ROOT/path).read_text('cp1251')
def save(path,s): (ROOT/path).write_bytes(s.replace('\r\n','\n').replace('\n','\r\n').encode('cp1251'))
def replace(s,old,new):
 assert old in s, old[:100]
 return s.replace(old,new,1)
s=source('vendor/Bleeds/x64/Bleedsx64.asm')
s=replace(s,'  mov qword[rcx],IPlugin','  test rcx,rcx\n  jz .null\n  mov qword[rcx],IPlugin')
s=replace(s,'  mov eax,256\nret','  mov eax,256\n  ret\n.null: xor eax,eax\nret')
start=s.index('QueryInterface:');end=s.index('\nalign 8\nIPlugin ',start)
s=s[:start]+'''include 'Lifecycle27.inc'
'''+s[end:]
s=replace(s,'EventsCookie      rd 1','EventsCookie      rd 1\nSessionActive     rd 1\nCommandAdded      rd 1\nDialogActive      rd 1')
save('src/bleeds/x64/Bleedsx64.asm',s)

s=source('vendor/Seam-Carving/x64/SC_x64.asm')
s=s.replace('ProcessImageFileName=27','ProcessImageFileName=27\nWM_APP=8000h\nINFINITE=0FFFFFFFFh')
# RGB 32-bit loads/stores are confined to our padded staging buffers, never host buffers.
s=replace(s,'  .Carve:\n','  .Carve:\n    cmp [CancelRequested],0\n    jne .WorkerDone\n')
s=replace(s,'  mov     [CarvingThread],0\n  mov     ebx,1\n  call    EnableControls\n  ret','  .WorkerDone:\n  invoke PostMessageW,[hwnds.MainDlg],WM_APP+27,0,0\n  xor eax,eax\n  ret')
s=replace(s,'invoke EnableWindow,dword[rdi+rsi*8],ebx','invoke EnableWindow,qword[rdi+rsi*8],ebx')
s=replace(s,'.WM_DESTROY:invoke wglDeleteContext,[RC]\n                  invoke DeleteDC,[DC]', '.WM_DESTROY:invoke wglMakeCurrent,0,0\n                  invoke wglDeleteContext,[RC]\n                  invoke ReleaseDC,[hwnds.DrawArea],[DC]')
s=replace(s,'  cmp edx,WM_CLOSE\n  je .WM_CLOSE','  cmp edx,WM_APP+27\n  je .WorkerDone\n  cmp edx,WM_CLOSE\n  je .WM_CLOSE')
s=replace(s,'.BN_CLICKED:movzx r8,r8w\n                                jmp', '.BN_CLICKED:movzx r8,r8w\n                                cmp r8d,3\n                                jb .IgnoreCommand\n                                cmp r8d,6\n                                ja .IgnoreCommand\n                                cmp [CarvingThread],0\n                                jne .IgnoreCommand\n                                jmp')
s=replace(s,'.Aplpy:xor    ebx,ebx','.IgnoreCommand:ret\n                                    .Aplpy:mov [CancelRequested],0\n                                           xor    ebx,ebx')
s=replace(s,'invoke CreateThread,0,4096,SeamCarving,eax,0,0','invoke CreateThread,0,0,SeamCarving,eax,0,0')
s=replace(s,'mov    [CarvingThread],rax\n                                           ret','mov    [CarvingThread],rax\n                                           test rax,rax\n                                           jne @f\n                                             mov ebx,1\n                                             call EnableControls\n                                           @@:ret')
s=replace(s,'.WM_CLOSE:invoke EndDialog,rcx,0\n                    invoke TerminateThread,[CarvingThread],0\n                    ret', '''.WM_CLOSE:cmp [CarvingThread],0
                    je .CloseNow
                    mov [CancelRequested],1
                    mov eax,1
                    ret
          .WorkerDone:cmp [CarvingThread],0
                    je .IgnoreCommand
                    invoke WaitForSingleObject,[CarvingThread],INFINITE
                    invoke CloseHandle,[CarvingThread]
                    mov [CarvingThread],0
                    cmp [CancelRequested],0
                    jne .CloseNow
                    mov ebx,1
                    call EnableControls
                    mov eax,1
                    ret
          .CloseNow:invoke EndDialog,[hwnds.MainDlg],0
                    mov eax,1
                    ret''')
s=replace(s,'  mov     rbp,rdx\n  mov     word[r9],0','''  movsx ecx,cx
  test r9,r9
  jz .InvalidNoResult
  mov word[r9],0
  cmp rcx,5
  ja .Invalid
  test rcx,rcx
  jz .InvalidNoResult ; About needs no FilterRecord.
  test rdx,rdx
  jz .Invalid
  mov     rbp,rdx
  mov     word[r9],0''')
s=replace(s,'  align 8\n  .jmptable dq .filterSelectorAbout', '''.Invalid:mov word[r9],1
  .InvalidNoResult:ret
  align 8
  .jmptable dq .filterSelectorAbout''')
s=replace(s,'.filterSelectorStart:movd', '''.filterSelectorStart:cmp [CarvingData],0
                            jne .Busy
                            mov [CancelRequested],0
                            cmp qword[rbp+FilterRecord.platformData],0
                            je .BadRecord
                            cmp qword[rbp+FilterRecord.advanceState],0
                            je .BadRecord
                            movzx eax,[rbp+FilterRecord.planes]
                            cmp eax,3
                            jb .BadRecord
                            cmp eax,4
                            ja .BadRecord
                            movzx eax,[rbp+FilterRecord.wholeSize.h]
                            movzx ecx,[rbp+FilterRecord.wholeSize.v]
                            cmp eax,16384
                            ja .BadRecord
                            cmp ecx,16384
                            ja .BadRecord
                            imul eax,ecx
                            cmp eax,4194304
                            ja .BadRecord
                            movd''')
s=replace(s,'                            call      [rbp+FilterRecord.advanceState]\n', '''                            call      [rbp+FilterRecord.advanceState]
                            test ax,ax
                            jne .BadRecord
                            cmp qword[rbp+FilterRecord.inData],0
                            je .BadRecord
                            cmp qword[rbp+FilterRecord.outData],0
                            je .BadRecord
                            mov eax,[input.Width]
                            imul eax,[ChannelCount]
                            cmp [rbp+FilterRecord.inRowBytes],eax
                            jl .BadRecord
                            cmp [rbp+FilterRecord.outRowBytes],eax
                            jl .BadRecord
''')
s=replace(s,'                            mov       [MemSize],edx\n                            invoke    VirtualAlloc,0,edx,MEM_COMMIT,PAGE_READWRITE', '''                            mov [StageOffset],edx
                            mov eax,[input.PixelCount]
                            lea edx,[edx+eax*8+16]
                            mov       [MemSize],edx
                            invoke    VirtualAlloc,0,edx,MEM_COMMIT+MEM_RESERVE,PAGE_READWRITE''')
s=replace(s,'                            call      [InitCommonControls]', '''                            mov rdi,[CarvingData]
                            mov eax,[StageOffset]
                            add rdi,rax
                            mov [input.Data],rdi
                            mov eax,[input.PixelCount]
                            lea rax,[rdi+rax*4+8]
                            mov [output.Data],rax
                            mov rsi,[rbp+FilterRecord.inData]
                            mov ebx,[input.Height]
                            .CopyInputRow:
                              mov rdx,rsi
                              mov ecx,[input.Width]
                              imul ecx,[ChannelCount]
                              rep movsb
                              mov esi,[rbp+FilterRecord.inRowBytes]
                              add rsi,rdx
                              dec ebx
                            jne .CopyInputRow
                            call      [InitCommonControls]''')
# Corel Technical 27 is explicit. Never instantiate another Corel application.
a=s.index('                            invoke    NtQueryInformationProcess');b=s.index('                              cominvk  CorelApp,Get_AppWindow',a)
s=s[:a]+'''                            invoke CoInitialize,0
                            test eax,eax
                            js @f
                              mov [ComInitialized],1
                            @@:
                            invoke CLSIDFromProgID,CorelProgID,CorelCLSID
                            test eax,eax
                            js .BadCorel
                            invoke GetActiveObject,CorelCLSID,0,ActiveUnknown
                            test eax,eax
                            js .BadCorel
                            cmp [ActiveUnknown],0
                            je .BadCorel
                            cominvk ActiveUnknown,QueryInterface,IID_IVGApplication,CorelApp
                            mov ebx,eax
                            cominvk ActiveUnknown,Release
                            mov [ActiveUnknown],0
                            test ebx,ebx
                            js .BadCorel
                            cmp [CorelApp],0
                            je .BadCorel
'''+s[b:]
s=replace(s,'                              cominvk  AppWindow,Get_Handle,DC', '''                              cmp [AppWindow],0
                              je .BadCorel
                              mov [DC],0
                              cominvk  AppWindow,Get_Handle,DC
                              mov ebx,eax''')
s=replace(s,'                              cominvk  AppWindow,Release\n                              mov      rax,[DC]\n                              cmp      rax,[hwnds.Parent]\n                              mov      rax,errSecondInstance\n                              jne .filterError', '''                              cominvk  AppWindow,Release
                              mov [AppWindow],0
                              test ebx,ebx
                              js .BadCorel
                              invoke GetWindowThreadProcessId,[DC],CorelPID
                              test eax,eax
                              jz .BadCorel
                              invoke GetCurrentProcessId
                              cmp eax,[CorelPID]
                              jne .BadCorel''')
for call in ['cominvk  CorelApp,Get_ActiveSelectionRange,Selection','cominvk  Selection,Get_FirstShape,Shape','cominvk  Shape,GetSize,ShapeSize.Width,ShapeSize.Height','cominvk  Shape,Get_OriginalWidth,ShapePos.X','cominvk  Shape,Get_OriginalHeight,ShapePos.Y']:
 s=replace(s,call,call+'\n                              test eax,eax\n                              js .BadCorel')
s=replace(s,'                              movapd   xmm0,[ShapeSize]', '''                              pxor xmm0,xmm0
                              comisd xmm0,[ShapePos.X]
                              jae .BadCorel
                              comisd xmm0,[ShapePos.Y]
                              jae .BadCorel
                              movapd   xmm0,[ShapeSize]''')
s=replace(s,'                              cominvk  Selection,Release\n                              call', '                              cominvk  Selection,Release\n                              mov [Selection],0\n                              call')
s=replace(s,'                              cominvk  Shape,Release\n                              cominvk  CorelApp,Release','                              call ReleaseCorel27')
s=replace(s,'                            .exit:\n                            xor', '''                            .exit:
                            mov rsi,[output.Data]
                            mov rdi,[rbp+FilterRecord.outData]
                            mov ebx,[input.Height]
                            .CopyOutputRow:
                              mov rdx,rdi
                              mov ecx,[input.Width]
                              imul ecx,[ChannelCount]
                              rep movsb
                              mov edi,[rbp+FilterRecord.outRowBytes]
                              add rdi,rdx
                              dec ebx
                            jne .CopyOutputRow
                            xor''')
s=replace(s,'.filterSelectorPrepare:mov  eax,1','.filterSelectorPrepare:cmp qword[rbp+FilterRecord.platformData],0\n                            je .BadRecord\n                            mov  eax,1')
s=replace(s,'               .filterError:invoke', '''                 .BadRecord:mov rax,errBounds27
                            jmp .filterError
                  .BadCorel:mov rax,errSecondInstance
                            jmp .filterError
                      .Busy:mov rax,[result]
                            mov word[rax],1
                            ret
               .filterError:invoke''')
s=replace(s,'''.filterSelectorFinish:invoke TerminateThread,[CarvingThread],0
                            invoke DeleteObject,[StdCursor]
                            invoke DeleteObject,[HSizeCursor]
                            invoke VirtualFree,[CarvingData],[MemSize],MEM_DECOMMIT''','''.filterSelectorFinish:cmp [CarvingThread],0
                            jne .Busy
                            call ReleaseCorel27
                            cmp [CarvingData],0
                            je @f
                              invoke VirtualFree,[CarvingData],0,MEM_RELEASE
                              mov [CarvingData],0''')
s=replace(s,'proc ShowFilterDialog', '''proc ReleaseCorel27
  cmp [Selection],0
  je @f
    cominvk Selection,Release
    mov [Selection],0
  @@:
  cmp [Shape],0
  je @f
    cominvk Shape,Release
    mov [Shape],0
  @@:
  cmp [AppWindow],0
  je @f
    cominvk AppWindow,Release
    mov [AppWindow],0
  @@:
  cmp [CorelApp],0
  je @f
    cominvk CorelApp,Release
    mov [CorelApp],0
  @@:
  cmp [ComInitialized],0
  je @f
    invoke CoUninitialize
    mov [ComInitialized],0
  @@:ret
endp

proc ShowFilterDialog''')
s=replace(s,'  test     eax,eax\n  jne @f\n    mov  ecx,[input.PixelCount]', '  cmp eax,1\n  je @f\n    xor eax,eax\n    mov  ecx,[input.PixelCount]')
s=replace(s,'    add  ecx,3\n    shr  ecx,2\n    rep  movsd','    rep  movsb')
s=replace(s,"CorelProgID           du 'CorelDRAW.Application.'\nCorelVersion          dd 0\n                      dw 0", "CorelProgID           du 'CorelDRAW.Application.27',0")
s=replace(s,'CarvingThread         rq 1', '''CarvingThread         rq 1
CancelRequested       rd 1
ComInitialized        rd 1
CorelPID              rd 1
StageOffset           rd 1
ActiveUnknown         IVGApplication
errBounds27           du 'RGB/CMYK, 4..16384 px per side; up to 4 megapixels. Invalid host buffers are rejected.',0
align 8''')
save('src/seamcarving/x64/SC_x64.asm',s)
s=source('vendor/Seam-Carving/Imports.inc')
s=replace(s,"          ole,'OLE32.dll',\\", "          ole,'OLE32.dll',\\\n          oleaut,'OLEAUT32.dll',\\")
s=replace(s,"         TerminateThread,'TerminateThread'", "         WaitForSingleObject,'WaitForSingleObject',\\\n         CloseHandle,'CloseHandle',\\\n         GetCurrentProcessId,'GetCurrentProcessId'")
s=replace(s,"         GetDC,'GetDC',\\", "         GetDC,'GetDC',\\\n         ReleaseDC,'ReleaseDC',\\\n         GetWindowThreadProcessId,'GetWindowThreadProcessId',\\")
s=replace(s,"         CoCreateInstance,'CoCreateInstance'", "         CoUninitialize,'CoUninitialize'\n\n  import oleaut,GetActiveObject,'GetActiveObject'")
save('src/seamcarving/Imports.inc',s)

save("src/seamcarving/x64/Photoshop.inc",source("vendor/Seam-Carving/x64/Photoshop.inc").replace("MACRO", "macro"))
