format MS64 COFF

include 'win64w.inc'
include 'CorelDraw.inc'
include 'DragDrop.inc'

prologue@proc equ static_rsp_prologue
epilogue@proc equ static_rsp_epilogue
close@proc equ static_rsp_close

extrn 'GlobalFindAtomW' as GlobalFindAtomW:QWORD
extrn 'GetPropW' as GetPropW:QWORD
extrn 'SafeArrayCreate' as SafeArrayCreate:QWORD
extrn 'SafeArrayDestroy' as SafeArrayDestroy:QWORD
extrn 'DragQueryFileW' as DragQueryFileW:QWORD
extrn 'DragFinish' as DragFinish:QWORD
extrn 'ReleaseStgMedium' as ReleaseStgMedium:QWORD
extrn 'SendMessageW' as SendMessageW:QWORD
extrn 'RevokeDragDrop' as RevokeDragDrop:QWORD
extrn 'RegisterDragDrop' as RegisterDragDrop:QWORD
extrn 'SetWindowLongPtrW' as SetWindowLongPtrW:QWORD
extrn 'VirtualAlloc' as VirtualAlloc:QWORD
extrn 'CreateFileW' as CreateFileW:QWORD
extrn 'CloseHandle' as CloseHandle:QWORD
extrn 'ReadFile' as ReadFile:QWORD
extrn 'GetFileSize' as GetFileSize:QWORD
extrn 'CreateThread' as CreateThread:QWORD
extrn 'VirtualFree' as VirtualFree:QWORD
extrn 'WebPDecodeBGRAInto' as WebPDecodeBGRAInto:QWORD
extrn 'WebPGetInfo' as WebPGetInfo:QWORD
public start as 'start'
public AttachPlugin as 'AttachPlugin'

AttachPlugin: ;ppIPlugin: IVGAppPlugin
  mov rax,IPlugin
  mov qword[rcx],rax
  mov eax,256
ret

start:
  mov eax,TRUE
ret

QueryInterface:   ;(const self:IVGAppPlugin; const IID: TGUID; out Obj): HResult; stdcall;
  mov rax,IPlugin
  mov qword[r8],rax
AddRef:           ;(const self:IVGAppPlugin):Integer; stdcall;
Release:          ;(const self:IVGAppPlugin):Integer; stdcall;
  xor eax,eax
ret
GetTypeInfoCount: ;(const self:IVGAppPlugin; out Count: Integer): HResult; stdcall;
GetTypeInfo:      ;(const self:IVGAppPlugin; Index, LocaleID: Integer; out TypeInfo): HResult; stdcall;
GetIDsOfNames:    ; this,IID,Names,NameCount,LocaleID,DispIDs
  mov eax,E_NOTIMPL
ret

proc WndProc wnd,msg,wParam,lParam
  cmp edx,WM_ENABLE
  jne @f
    mov     [wnd],rcx
    stdcall SetWindowLongPtrW,rcx,GWLP_WNDPROC,r8     ;restore old window proc
    stdcall GlobalFindAtomW,strOleDropTargetInterface
    stdcall GetPropW,[wnd],rax
    mov     [OrigDropTarget],rax
    comcall rax,IDropTarget,AddRef
    stdcall RevokeDragDrop,[wnd]
    stdcall RegisterDragDrop,[wnd],DropTarget
    xor     eax,eax
  @@:
  ret
endp

proc Invoke this,DispID,IID,LocaleID,Flags,Params,VarResult,ExcepInfo,ArgErr
  local wnd:QWORD,\
        ActiveWindow:IVGWindow
  mov rax,[Params]
  mov rax,[rax+DISPPARAMS.rgvarg]
  mov rcx,[rax+sizeof.VARIANT*3+VARIANT.data]
  cmp edx,OnDocumentNew
  je  .OnDocumentNew
  mov rcx,[rax+sizeof.VARIANT+VARIANT.data]
  cmp edx,OnDocumentOpen
  jne  @f
    .OnDocumentNew:
    comcall rcx,IVGDocument,Get_ActiveWindow,addr ActiveWindow
    cominvk ActiveWindow,Get_Handle,addr wnd
    cominvk ActiveWindow,Release
    stdcall SetWindowLongPtrW,[wnd],GWLP_WNDPROC,WndProc ;RegisterDragDrop must be called from message loop thread - so subclass window for do this
    stdcall SendMessageW,[wnd],WM_ENABLE,rax,0
  @@:
  xor     eax,eax
  ret
endp

proc StartSession     ;(const self:IVGAppPlugin):LongInt;stdcall;
  cominvk CorelApp,AdviseEvents,IPlugin,EventsCookie
  xor     eax,eax
ret
endp

proc StopSession      ;(const self:IVGAppPlugin):LongInt;stdcall;
  cominvk CorelApp,UnadviseEvents,[EventsCookie]
  xor     eax,eax
ret
endp

proc OnLoad ;(const self:IVGAppPlugin; const _Application: IVGApplication):LongInt;stdcall;
  mov     [CorelApp],rdx
  comcall rdx,IVGApplication,AddRef
ret
endp

proc OnUnload         ;(const self:IVGAppPlugin)LongInt;stdcall;
  cominvk CorelApp,Release
  xor     eax,eax
ret
endp

QueryInterface2:   ;(const self:IVGAppPlugin; const IID: TGUID; out Obj): HResult; stdcall;
  mov rax,DropTarget
  mov qword[r8],rax
  xor eax,eax
ret

Release2:
  mov rcx,[OrigDropTarget]
  mov rax,[rcx]
  jmp [rax+IDropTarget.Release]

DragEnter: ;this,dataObj,grfKeyState,pt,dwEffect
  mov rcx,[OrigDropTarget]
  mov rax,[rcx]
  jmp [rax+IDropTarget.DragEnter]


DragOver:  ;(grfKeyState: Longint; pt: TPoint;var dwEffect: Longint): HResult; stdcall;
  mov rcx,[OrigDropTarget]
  mov rax,[rcx]
  jmp [rax+IDropTarget.DragOver]

DragLeave: ;: HResult; stdcall;
  mov rcx,[OrigDropTarget]
  mov rax,[rcx]
  jmp [rax+IDropTarget.DragLeave]

proc SetImageData uses rdi rsi rbx rbp r12 r13 r14,Image,data
local Tiles:IVGImageTiles,\
      tmp:QWORD,\
      TileData:QWORD,\
      TileCount:DWORD,\
      TileX:DWORD,\
      TileY:DWORD,\
      TileWidth:DWORD,\
      TileHeight:DWORD,\
      TileBPP:DWORD,\
      TileBPL:DWORD

  mov     [data],rdx
  comcall rcx,IVGImage,Get_Tiles,addr Tiles
  cominvk Tiles,Get_Count,addr TileCount
  .MainLoop:
    cominvk Tiles,Get_Item,[TileCount],addr tmp
    mov     rbp,[tmp]
    comcall rbp,IVGImageTile,Get_Left,addr TileX
    comcall rbp,IVGImageTile,Get_Bottom,addr TileY
    comcall rbp,IVGImageTile,Get_Width,addr TileWidth
    comcall rbp,IVGImageTile,Get_Height,addr TileHeight
    comcall rbp,IVGImageTile,Get_BytesPerPixel,addr TileBPP
    comcall rbp,IVGImageTile,Get_BytesPerLine,addr TileBPL
    mov     ecx,[TileWidth]
    mov     edx,[TileHeight]
    mov     rsi,[data]
    mov     r12d,[TileBPP]
    mov     r14d,[TileBPL]
    mov     rax,PixelMask
    mov     ebx,dword[rax+r12*4-4]
    mov     ebp,ebx
    not     ebx
    imul    ecx,r12d
    mov     rax,r14
    imul    eax,edx
    mov     [rgsabound.cElements],eax
    sub     rax,r14
    sub     r14,rcx
    lea     edi,[eax+ecx]
    add     edx,[TileY]
    mov     r13d,[ImageWidth]
    dec     edx
    imul    edx,r13d
    sub     r13d,[TileWidth]
    add     edx,[TileX]
    shl     r13,2
    add     edx,[TileWidth]
    lea     rsi,[rsi+rdx*4]

    stdcall SafeArrayCreate,VT_UI1,1,rgsabound
    mov     [TileData],rax
    add     rdi,[rax+SAFEARRAY.pvData]

    mov     edx,[TileHeight]
    .Row:mov ecx,[TileWidth]
         .Col:sub rdi,r12
              sub rsi,4
              mov eax,[rsi]
              and [rdi],ebx
              and eax,ebp
              or  [rdi],eax
              dec ecx
         jne .Col
         sub rdi,r14
         sub rsi,r13
         dec edx
    jne .Row

    mov     rbp,[tmp]
    comcall rbp,IVGImageTile,Set_PixelData,addr TileData
    stdcall SafeArrayDestroy,[TileData]
    comcall rbp,IVGImageTile,Release
    dec     [TileCount]
  jne .MainLoop
  cominvk Tiles,Release
ret
endp

proc Drop uses rbx rsi rdi r12 r13,this,dataObj,grfKeyState,pt,dwEffect
local CorelDoc:IVGDocument,\
      ActiveLayer:IVGLayer,\
      ActiveWindow:IVGWindow,\
      Shape:IVGShape,\
      Image:IVGImage,\
      ImageAlpha:IVGImage,\
      x:QWORD,\
      y:QWORD,\
      filesize:QWORD

  mov [this],rcx
  mov [dataObj],rdx
  mov [grfKeyState],r8
  mov [pt],r9

  comcall rdx,IDataObject,GetData,formatetc,stgMedium
  test    eax,eax
  jne .NoHDROP
    cominvk CorelApp,Get_ActiveDocument,addr CorelDoc
    cominvk CorelDoc,Get_ActiveLayer,addr ActiveLayer
    cominvk CorelDoc,Get_ActiveWindow,addr ActiveWindow
    cominvk CorelDoc,BeginCommandGroup,strOleDropTargetInterface
    cominvk CorelDoc,Set_Unit,cdrMillimeter
    cominvk ActiveWindow,ScreenToDocument,dword[pt],dword[pt+4],addr x,addr y
    cominvk ActiveWindow,Release
    stdcall DragQueryFileW,[stgMedium.hGlobal],-1,0,0
    mov     r12,rax
    @@:stdcall DragQueryFileW,[stgMedium.hGlobal],addr r12-1,buf,sizeof.buf
       mov     rdx,buf
       mov     rdx,qword[rdx+rax*2-8]
       and     rdx,qword[UpperCase]
       cmp     rdx,qword[strWEBP] ;if file path ends with 'webp'
       jne .unk
         stdcall  CreateFileW,buf,GENERIC_READ,0,0,OPEN_EXISTING,0,0
         mov      rbx,rax
         stdcall  GetFileSize,rax,0
         mov      [filesize],rax
         stdcall  VirtualAlloc,0,rax,MEM_COMMIT,PAGE_READWRITE
         mov      r13,rax
         stdcall  ReadFile,rbx,rax,[filesize],addr filesize,0
         stdcall  CloseHandle,rbx
         stdcall  WebPGetInfo,r13,[filesize],ImageWidth,ImageHeight
         mov      ebx,[ImageWidth]
         mov      edi,[ImageHeight]
         shl      ebx,2
         imul     edi,ebx
         stdcall  VirtualAlloc,0,addr rdi+4,MEM_COMMIT,PAGE_READWRITE
         mov      rsi,rax
         stdcall  WebPDecodeBGRAInto,r13,[filesize],rax,rdi,ebx
         stdcall  VirtualFree,r13,0,MEM_RELEASE
         cominvk  CorelDoc,CreateImage,cdrRGBColorImage,[ImageWidth],[ImageHeight],0,addr Image
         cominvk  CorelDoc,CreateImage,cdrGrayscaleImage,[ImageWidth],[ImageHeight],0,addr ImageAlpha
         stdcall  SetImageData,[Image],rsi
         stdcall  SetImageData,[ImageAlpha],addr rsi+3
         stdcall  VirtualFree,rsi,0,MEM_RELEASE
         cvtsi2sd xmm3,[ImageWidth]
         cvtsi2sd xmm4,[ImageHeight]
         cominvk  ActiveLayer,CreateBitmap2,float[x],float[y],xmm3,xmm4,[Image],[ImageAlpha],addr Shape
         cominvk  Image,Release
         cominvk  ImageAlpha,Release
         cominvk  Shape,Flip,cdrFlipVertical
         cominvk  Shape,Release
         jmp .next
       .unk:
         mov     dword[buf-4],eax
         cominvk ActiveLayer,Import,buf,0,0
         mov     [Shape],0
         cominvk CorelDoc,Selection,addr Shape
         cominvk Shape,SetPositionEx,cdrBottomLeft,float[x],float[y]
         cominvk Shape,Release
       .next:
       dec     r12
    jne @b
    stdcall DragFinish,[stgMedium.hGlobal]
    stdcall ReleaseStgMedium,stgMedium
    cominvk ActiveLayer,Release
    cominvk CorelDoc,EndCommandGroup
    cominvk CorelDoc,Release
    jmp .quit
  .NoHDROP:
    cominvk OrigDropTarget,Drop,[dataObj],[grfKeyState],[pt],[dwEffect]
  .quit:
  xor     eax,eax
  ret
endp

section 'data' readable writeable
  DropTarget     dq  IDropTargetVMT
  IDropTargetVMT dq  QueryInterface2,\
                     AddRef,\
                     Release2,\
                     DragEnter,\
                     DragOver,\
                     DragLeave,\
                     Drop

  IPlugin        dq IPluginVMT
  IPluginVMT     dq QueryInterface,\
                    AddRef,\
                    Release,\
                    GetTypeInfoCount,\
                    GetTypeInfo,\
                    GetIDsOfNames,\
                    Invoke,\
                    OnLoad,\
                    StartSession,\
                    StopSession,\
                    OnUnload

  UpperCase                 dq $FFDFFFDFFFDFFFDF
  strWEBP                   du 'WEBP'
  strOleDropTargetInterface OLEstr 'OleDropTargetInterface'
  PixelMask                 dd $FF,$FFFF,$FFFFFF,$FFFFFFFF
  formatetc                 FORMATETC CF_HDROP,0,DVASPECT_CONTENT,-1,TYMED_HGLOBAL

section '' readable writeable
  stgMedium      uSTGMEDIUM
  CorelApp       IVGApplication
  OrigDropTarget IDropTarget
  EventsCookie   rd 1
  ImageWidth     rd 1
  ImageHeight    rd 1
  len            rd 1
  rgsabound      SAFEARRAYBOUND
  buf            rw 4096
  sizeof.buf=($-buf) shr 1
