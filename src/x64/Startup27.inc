; Diagnostic startup for CorelDRAW 27.2 x64.
; Packing code remains in DirectEnpackx64.asm, unchanged from upstream.
; LogResult returns the supplied HRESULT unchanged in EAX.
proc LogResult uses rbx rsi rdi,stage,result
  mov rbx,rcx
  mov esi,edx
  invoke GetTempPathW,480,LogPath
  test eax,eax
  jz .done
  cmp eax,480
  jae .done
  invoke lstrcatW,LogPath,LogFileName
  invoke CreateFileW,LogPath,4,3,0,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
  cmp rax,-1
  je .done
  mov rdi,rax
  cinvoke wsprintfA,LogBuffer,LogFormat,rbx,esi
  invoke WriteFile,rdi,LogBuffer,eax,LogBytes,0
  invoke CloseHandle,rdi
.done:
  mov eax,esi
  ret
endp

proc ReleaseUi
  cmp [CaptionPtr],0
  je @f
  invoke SysFreeString,[CaptionPtr]
  mov [CaptionPtr],0
@@:
  cmp [Control],0
  je @f
  cominvk Control,Release
  mov [Control],0
@@:
  cmp [Controls],0
  je @f
  cominvk Controls,Release
  mov [Controls],0
@@:
  cmp [CommandBar],0
  je @f
  cominvk CommandBar,Release
  mov [CommandBar],0
@@:
  cmp [CommandBars],0
  je @f
  cominvk CommandBars,Release
  mov [CommandBars],0
@@:
  ret
endp

proc OnLoad uses rbx
  mov rbx,rdx
  fastcall LogResult,logOnLoad,0
  test rbx,rbx
  jz .invalid
  mov [CorelApp],rbx
  comcall rbx,IVGApplication,AddRef
  ; Each COM getter writes a full 32-bit LONG, not a packed version byte.
  comcall rbx,IVGApplication,Get_VersionMajor,CorelMajor
  fastcall LogResult,logMajor,eax
  test eax,eax
  js .failed
  comcall rbx,IVGApplication,Get_VersionMinor,CorelMinor
  fastcall LogResult,logMinor,eax
  test eax,eax
  js .failed
  xor eax,eax
  ret
.failed:
  mov ebx,eax
  cominvk CorelApp,Release
  mov [CorelApp],0
  mov eax,ebx
  ret
.invalid:
  mov eax,80004003h ; E_POINTER
  ret
endp

proc StartSession uses rbx rsi
  fastcall LogResult,logStart,0
  cmp [CorelApp],0
  je .null
  mov eax,1
  cpuid
  test ecx,1 shl 19
  jz .cpu
  mov [CommandAdded],0
  cominvk CorelApp,AddPluginCommand,strDirectEnpack,strButtonCaption,strButtonCaption,CommandAdded
  fastcall LogResult,logRegister,eax
  test eax,eax
  js .cleanup
  cmp word[CommandAdded],0
  je .notAdded
  mov [Registered],1
  cominvk CorelApp,AdviseEvents,IPlugin,EventsCookie
  fastcall LogResult,logAdvise,eax
  test eax,eax
  js .cleanup
  mov [Advised],1
  cominvk CorelApp,Get_CommandBars,CommandBars
  fastcall LogResult,logBars,eax
  test eax,eax
  js .cleanup
  cmp [CommandBars],0
  je .null
  cominvk CommandBars,Get_Item,varStrStandard,CommandBar
  fastcall LogResult,logStandard,eax
  test eax,eax
  js .fallback
  cmp [CommandBar],0
  je .fallback
  cominvk CommandBar,Get_Visible,BarVisible
  fastcall LogResult,logVisible,eax
  test eax,eax
  js .fallback
  cmp word[BarVisible],0
  jne .controls
.fallback:
  ; Do not unhide a Standard bar that the user deliberately hid.
  ; Reuse or create a separate temporary toolbar instead.
  cmp [CommandBar],0
  je @f
  cominvk CommandBar,Release
  mov [CommandBar],0
@@:
  cominvk CommandBars,Get_Item,varStrDirectEnpack,CommandBar
  fastcall LogResult,logOwnBar,eax
  test eax,eax
  js .addBar
  cmp [CommandBar],0
  jne .showBar
.addBar:
  cmp [CommandBar],0
  je @f
  cominvk CommandBar,Release
  mov [CommandBar],0
@@:
  ; cuiBarTop=1, Temporary=VARIANT_TRUE (-1).
  cominvk CommandBars,Add,strDirectEnpack,1,-1,CommandBar
  fastcall LogResult,logAddBar,eax
  test eax,eax
  js .cleanup
  cmp [CommandBar],0
  je .null
.showBar:
  cominvk CommandBar,Set_Visible,-1
  fastcall LogResult,logShowBar,eax
  test eax,eax
  js .cleanup
.controls:
  cominvk CommandBar,Get_Controls,Controls
  fastcall LogResult,logControls,eax
  test eax,eax
  js .cleanup
  cmp [Controls],0
  je .null
  cominvk Controls,Get_Count,ControlCount
  fastcall LogResult,logCount,eax
  test eax,eax
  js .cleanup
  mov ebx,[ControlCount]
  test ebx,ebx
  jle .addButton
.find:
  cominvk Controls,Get_Item,ebx,Control
  fastcall LogResult,logItem,eax
  test eax,eax
  js .cleanup
  cmp [Control],0
  je .null
  cominvk Control,Get_Caption,CaptionPtr
  fastcall LogResult,logCaption,eax
  test eax,eax
  js .cleanup
  cmp [CaptionPtr],0
  je .next
  invoke lstrcmpW,[CaptionPtr],strButtonCaption
  mov esi,eax
  invoke SysFreeString,[CaptionPtr]
  mov [CaptionPtr],0
  test esi,esi
  jz .icon
.next:
  cominvk Control,Release
  mov [Control],0
  dec ebx
  jnz .find
.addButton:
  cominvk Controls,AddCustomButton,cdrCmdCategoryPlugins,strDirectEnpack,1,0,Control
  fastcall LogResult,logAddButton,eax
  test eax,eax
  js .cleanup
  cmp [Control],0
  je .null
.icon:
  ; Keep the original icon, but icon failure must not hide a usable button.
  invoke GetTempPathW,480,IconPath
  test eax,eax
  jz .iconFailed
  cmp eax,480
  jae .iconFailed
  invoke lstrcatW,IconPath,IconFileName
  ; SetIcon2 takes a BSTR (byte length stored immediately before IconPath).
  invoke lstrlenW,IconPath
  add eax,eax
  mov [IconPathLength],eax
  invoke CreateFileW,IconPath,GENERIC_WRITE,FILE_SHARE_READ,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
  cmp rax,-1
  je .iconFailed
  mov rbx,rax
  invoke WriteFile,rbx,ICOData,sizeof.ICOData,IconBytes,0
  mov esi,eax
  invoke CloseHandle,rbx
  test esi,esi
  jz .iconFailed
  cmp [IconBytes],sizeof.ICOData
  jne .iconFailed
  cominvk Control,SetIcon2,IconPath
  fastcall LogResult,logIcon,eax
  jmp .ready
.iconFailed:
  fastcall LogResult,logIconFile,E_FAIL
.ready:
  fastcall LogResult,logReady,0
  xor eax,eax
.cleanup:
  mov esi,eax
  fastcall ReleaseUi
  test esi,esi
  jns @f
  fastcall StopSession
@@:
  mov eax,esi
  ret
.null:
  fastcall LogResult,logNull,80004003h
  jmp .cleanup
.notAdded:
  fastcall LogResult,logNotAdded,E_FAIL
  jmp .cleanup
.cpu:
  fastcall LogResult,logCPU,E_FAIL
  invoke MessageBoxW,0,errCPUNotSupported,strDirectEnpack,MB_TASKMODAL
  mov eax,E_FAIL
  jmp .cleanup
endp

proc StopSession
  fastcall LogResult,logStop,0
  cmp [CorelApp],0
  je .done
  cmp [Advised],0
  je @f
  cominvk CorelApp,UnadviseEvents,[EventsCookie]
  fastcall LogResult,logUnadvise,eax
  mov [Advised],0
@@:
  cmp [Registered],0
  je .done
  cominvk CorelApp,RemovePluginCommand,strDirectEnpack,CommandRemoved
  fastcall LogResult,logRemove,eax
  mov [Registered],0
.done:
  xor eax,eax
  ret
endp

proc OnUnload
  fastcall StopSession
  fastcall ReleaseUi
  cmp [CorelApp],0
  je @f
  cominvk CorelApp,Release
  mov [CorelApp],0
@@:
  fastcall LogResult,logUnload,0
  xor eax,eax
  ret
endp

align 8
CorelMajor      dd 0
CorelMinor      dd 0
Registered      dd 0
Advised         dd 0
CommandAdded    dd 0
CommandRemoved  dd 0
ControlCount    dd 0
BarVisible      dd 0
CaptionPtr      dq 0
LogBytes        dd 0
IconBytes       dd 0
LogPath         rw 512
LogBuffer       rb 256
                dd 0
IconPathLength  dd 0
IconPath        rw 512
varStrDirectEnpack VARIANT VT_BSTR,strDirectEnpack
LogFileName     du 'DirectEnpack-27.log',0
IconFileName    du 'DirectEnpack-27.ico',0
LogFormat       db '%s HRESULT=0x%08X',13,10,0
logAttach       db '=== DirectEnpack 27 diagnostic 1: AttachPlugin ===',0
logOnLoad       db 'OnLoad',0
logMajor        db 'Application.VersionMajor',0
logMinor        db 'Application.VersionMinor',0
logStart        db 'StartSession',0
logRegister     db 'Application.AddPluginCommand',0
logNotAdded     db 'AddPluginCommand returned false (duplicate command?)',0
logAdvise       db 'Application.AdviseEvents',0
logBars         db 'Application.CommandBars',0
logStandard     db 'CommandBars.Item(Standard)',0
logVisible      db 'Standard.Visible',0
logOwnBar       db 'CommandBars.Item(DirectEnpack)',0
logAddBar       db 'CommandBars.Add(DirectEnpack)',0
logShowBar      db 'DirectEnpack.Visible=true',0
logControls     db 'CommandBar.Controls',0
logCount        db 'Controls.Count',0
logItem         db 'Controls.Item',0
logCaption      db 'Control.Caption',0
logAddButton    db 'Controls.AddCustomButton',0
logIcon         db 'Control.SetIcon2',0
logIconFile     db 'Icon file unavailable (nonfatal)',0
logReady        db 'READY: startup completed',0
logNull         db 'Required COM pointer was null',0
logCPU          db 'CPU lacks SSE4.1',0
logStop         db 'StopSession',0
logUnadvise     db 'Application.UnadviseEvents',0
logRemove       db 'Application.RemovePluginCommand',0
logUnload       db 'OnUnload',0
