; CorelDRAW Technical 27 lifecycle. Geometry/dialog code stays upstream.
; Interface calls retain the original ABI; UI definition is in the CDWS only.
QueryInterface:
  test r8,r8
  jz .bad
  mov qword[r8],0
  test rdx,rdx
  jz .bad
  mov rax,[rdx]
  mov r9,[rdx+8]
  cmp rax,qword[IIDIUnknown27]
  jne @f
  cmp r9,qword[IIDIUnknown27+8]
  je .ok
  @@:cmp rax,qword[IIDIDispatch27]
  jne @f
  cmp r9,qword[IIDIDispatch27+8]
  je .ok
  @@:cmp r9,qword[IIDCorelTail27]
  jne .no
  cmp rax,qword[IIDPlugin27]
  je .ok
  cmp rax,qword[IIDEvents27]
  jne .no
  .ok:mov qword[r8],IPlugin
  xor eax,eax
  ret
  .no:mov eax,80004002h
  ret
  .bad:mov eax,80004003h
  ret
AddRef:
Release:
  mov eax,1
  ret
GetTypeInfoCount:
  test rdx,rdx
  jz .bad
  mov dword[rdx],0
  xor eax,eax
  ret
  .bad:mov eax,80004003h
  ret
GetTypeInfo:
GetIDsOfNames:
  mov eax,E_NOTIMPL
  ret

proc RefreshSelection27
  mov [Enabled],0
  cmp [CorelApp],0
  je .done
  mov [Selection],0
  cominvk CorelApp,Get_ActiveSelectionRange,Selection
  test eax,eax
  js .done
  cmp [Selection],0
  je .done
  cominvk Selection,Get_Count,Enabled
  test eax,eax
  jns @f
    mov [Enabled],0
  @@:cominvk Selection,Release
  mov [Selection],0
  .done:xor eax,eax
  ret
endp

proc Invoke uses rbx,this,DispID,IID,LocaleID,Flags,Params,VarResult,ExcepInfo,ArgErr
  cmp [SessionActive],0
  je .done
  cmp edx,OnSelectionChange
  je .selection
  cmp edx,OnPluginCommand
  je .command
  cmp edx,OnUpdatePluginCommand
  jne .done
  mov rbx,[Params]
  test rbx,rbx
  jz .done
  cmp [rbx+DISPPARAMS.cArgs],3
  jb .done
  mov rbx,[rbx+DISPPARAMS.rgvarg]
  test rbx,rbx
  jz .done
  cmp word[rbx+sizeof.VARIANT*2+VARIANT.type],VT_BSTR
  jne .done
  cmp word[rbx+sizeof.VARIANT+VARIANT.type],VT_BOOL+VT_BYREF
  jne .done
  cmp qword[rbx+sizeof.VARIANT*2+VARIANT.data],0
  je .done
  invoke lstrcmpW,[rbx+sizeof.VARIANT*2+VARIANT.data],strBleeds
  test eax,eax
  jne .done
  mov rax,[rbx+sizeof.VARIANT+VARIANT.data]
  test rax,rax
  jz .done
  xor edx,edx
  cmp [Enabled],0
  setne dl
  neg edx
  mov [rax],dx
  jmp .done
  .command:
  mov rbx,[Params]
  test rbx,rbx
  jz .done
  cmp [rbx+DISPPARAMS.cArgs],1
  jb .done
  mov rbx,[rbx+DISPPARAMS.rgvarg]
  test rbx,rbx
  jz .done
  cmp word[rbx+VARIANT.type],VT_BSTR
  jne .done
  cmp qword[rbx+VARIANT.data],0
  je .done
  invoke lstrcmpW,[rbx+VARIANT.data],strBleeds
  test eax,eax
  jne .done
  cmp [DialogActive],0
  jne .done
  call RefreshSelection27
  cmp [Enabled],0
  je .done
  mov [CorelWnd],0
  cominvk CorelApp,Get_ActiveWindow,CorelWnd
  test eax,eax
  js .done
  cmp [CorelWnd],0
  je .done
  mov [CorelWndHandle],0
  cominvk CorelWnd,Get_Handle,CorelWndHandle
  mov ebx,eax
  cominvk CorelWnd,Release
  mov [CorelWnd],0
  test ebx,ebx
  js .done
  cmp [CorelWndHandle],0
  je .done
  mov [DialogActive],1
  invoke DialogBoxIndirectParamW,0,MainDlg,[CorelWndHandle],DialogFunc,0
  mov [DialogActive],0
  cominvk CorelApp,Refresh
  jmp .done
  .selection:cmp [DialogActive],0
  jne .done
  call RefreshSelection27
  .done:xor eax,eax
  ret
endp

proc OnLoad
  test rdx,rdx
  jz .bad
  cmp [CorelApp],0
  jne .bad
  mov [CorelApp],rdx
  comcall rdx,IVGApplication,AddRef
  xor eax,eax
  ret
  .bad:mov eax,80004003h
  ret
endp
proc StartSession uses rbx
  cmp [CorelApp],0
  je .bad
  cmp [SessionActive],0
  jne .ok
  mov eax,1
  cpuid
  test ecx,1 shl 19
  jz .bad
  cmp [CommandAdded],0
  jne @f
    cominvk CorelApp,AddPluginCommand,strBleeds,strButtonCaption,strButtonCaption,buf
    test eax,eax
    js .exit
    mov [CommandAdded],1
  @@:
  cominvk CorelApp,AdviseEvents,IPlugin,EventsCookie
  test eax,eax
  js .exit
  mov [SessionActive],1
  call RefreshSelection27
  .ok:xor eax,eax
  .exit:ret
  .bad:mov eax,E_FAIL
  ret
endp
proc StopSession
  cmp [SessionActive],0
  je .done
  mov [SessionActive],0
  mov [Enabled],0
  cmp [CorelApp],0
  je .done
  cominvk CorelApp,UnadviseEvents,[EventsCookie]
  .done:xor eax,eax
  ret
endp
proc OnUnload
  call StopSession
  cmp [CorelApp],0
  je .done
  cominvk CorelApp,Release
  mov [CorelApp],0
  mov [CommandAdded],0
  .done:xor eax,eax
  ret
endp
align 8
IIDIUnknown27 dq 0,46000000000000C0h
IIDIDispatch27 dq 0000000000020400h,46000000000000C0h
IIDPlugin27 dq 44FD9AA4B0580005h
IIDEvents27 dq 44FD9AA4B05800C5h
IIDCorelTail27 dq 0C47A75EB914F4795h
