; Guarded host lifecycle only. Geometry/dispatch code is unchanged upstream.
; Win64 RBX is nonvolatile even though CPUID overwrites EBX.
proc CheckCPU uses rbx
  mov eax,1
  cpuid
  and ecx,1001b shl 20 ; SSE4.2 and POPCNT
  xor eax,eax
  cmp ecx,1001b shl 20
  je .done
  mov eax,E_FAIL
.done:
  ret
endp

proc OnLoad uses rbx
  cmp [CorelApp],0
  jne .alreadyLoaded
  test rdx,rdx
  jz .nullApp
  mov rbx,rdx
  fastcall CheckCPU
  test eax,eax
  js .unsupported
  mov [CorelApp],rbx
  comcall rbx,IVGApplication,AddRef
  ; Each getter writes a LONG. Never store LONGs one byte apart.
  comcall rbx,IVGApplication,Get_VersionMajor,CorelMajor27
  test eax,eax
  js .failed
  comcall rbx,IVGApplication,Get_VersionMinor,CorelMinor27
  test eax,eax
  js .failed
  mov eax,[CorelMajor27]
  shl eax,8
  or eax,[CorelMinor27]
  mov [CorelVersion],eax ; preserve original 0xMMmm comparisons in geometry code
  comcall rbx,IVGApplication,QueryInterface,IID_ICUIApplication,CUIApp
  test eax,eax
  js .failed
  cmp [CUIApp],0
  je .nullCUI
  mov [RegistrationResult27],0
  cominvk CUIApp,RegisterDataSource,strSmartDepart,DataSourceFactory,NullStr,0,RegistrationResult27
  test eax,eax
  js .failed
  cmp word[RegistrationResult27],0
  je .notRegistered
  mov [DataSourceRegistered27],1
  xor eax,eax
  ret
.notRegistered:
  mov eax,E_FAIL
  jmp .failed
.nullCUI:
  mov eax,80004003h ; E_POINTER
.failed:
  mov ebx,eax
  fastcall OnUnload
  mov eax,ebx
  ret
.unsupported:
  invoke MessageBoxW,0,errCPUNotSupported,strSmartDepart,MB_TASKMODAL
  mov eax,E_FAIL
  ret
.nullApp:
  mov eax,80004003h
  ret
.alreadyLoaded:
  mov eax,8000FFFFh ; E_UNEXPECTED; do not release the active session
  ret
endp

proc StartSession
  cmp [DataSourceRegistered27],1
  jne .notLoaded
  fastcall CheckCPU
  ret
.notLoaded:
  mov eax,E_FAIL
  ret
endp

proc OnUnload uses rbx
  xor ebx,ebx
  cmp [DataSourceRegistered27],0
  je .releaseCUI
  mov [DataSourceRegistered27],0
  cmp [CUIApp],0
  je .releaseCUI
  cominvk CUIApp,UnregisterDataSource,strSmartDepart,RegistrationResult27
  mov ebx,eax
.releaseCUI:
  cmp [CUIApp],0
  je .releaseApp
  cominvk CUIApp,Release
  mov [CUIApp],0
.releaseApp:
  cmp [CorelApp],0
  je .done
  cominvk CorelApp,Release
  mov [CorelApp],0
.done:
  mov eax,ebx
  ret
endp

align 8
CorelMajor27          dd 0
CorelMinor27          dd 0
RegistrationResult27 dd 0
DataSourceRegistered27 dd 0
