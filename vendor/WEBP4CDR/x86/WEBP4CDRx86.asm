format MS COFF

include 'win32w.inc'
include 'CorelDraw.inc'
include 'DragDrop.inc'

extrn '__imp__GlobalFindAtomW@4' as GlobalFindAtomW:DWORD
extrn '__imp__GetPropW@8' as GetPropW:DWORD
extrn '__imp__SafeArrayCreate@12' as SafeArrayCreate:DWORD
extrn '__imp__SafeArrayDestroy@4' as SafeArrayDestroy:DWORD
extrn '__imp__DragQueryFileW@16' as DragQueryFileW:DWORD
extrn '__imp__DragFinish@4' as DragFinish:DWORD
extrn '__imp__ReleaseStgMedium@4' as ReleaseStgMedium:DWORD
extrn '__imp__SendMessageW@16' as SendMessageW:DWORD
extrn '__imp__RevokeDragDrop@4' as RevokeDragDrop:DWORD
extrn '__imp__RegisterDragDrop@8' as RegisterDragDrop:DWORD
extrn '__imp__SetWindowLongW@12' as SetWindowLongW:DWORD
extrn '__imp__VirtualAlloc@16' as VirtualAlloc:DWORD
extrn '__imp__CreateFileW@28' as CreateFileW:DWORD
extrn '__imp__CloseHandle@4' as CloseHandle:DWORD
extrn '__imp__ReadFile@20' as ReadFile:DWORD
extrn '__imp__GetFileSize@8' as GetFileSize:DWORD
extrn '__imp__CreateThread@24' as CreateThread:DWORD
extrn '__imp__VirtualFree@12' as VirtualFree:DWORD
extrn '_WebPDecodeBGRAInto' as WebPDecodeBGRAInto:DWORD
extrn '_WebPGetInfo' as WebPGetInfo:DWORD
public start as 'start'
public AttachPlugin as 'AttachPlugin'

AttachPlugin: ;ppIPlugin: IVGAppPlugin
  mov eax,[esp+4]
  mov dword[eax],IPlugin
  mov eax,256
ret 4

start:
  mov eax,TRUE
ret 12

QueryInterface:   ;(const self:IVGAppPlugin; const IID: TGUID; out Obj): HResult; stdcall;
  mov eax,[esp+12]
  mov dword[eax],IPlugin
  xor eax,eax
ret 12
AddRef:           ;(const self:IVGAppPlugin):Integer; stdcall;
Release:          ;(const self:IVGAppPlugin):Integer; stdcall;
  xor eax,eax
ret 4
GetTypeInfoCount: ;(const self:IVGAppPlugin; out Count: Integer): HResult; stdcall;
  mov eax,E_NOTIMPL
ret 8
GetTypeInfo:      ;(const self:IVGAppPlugin; Index, LocaleID: Integer; out TypeInfo): HResult; stdcall;
  mov eax,E_NOTIMPL
ret 12
GetIDsOfNames:    ;(const self:IVGAppPlugin; const IID: TGUID; Names: Pointer;NameCount, LocaleID: Integer; DispIDs: Pointer): HResult; stdcall;
  mov eax,E_NOTIMPL
ret 24

WndProc: ; wnd,msg,wParam,lParam
  cmp dword[esp+8],WM_ENABLE
  jne @f
    invoke  SetWindowLongW,dword[esp+12],GWL_WNDPROC,dword[esp+12]     ;restore old window proc
    invoke  GlobalFindAtomW,strOleDropTargetInterface
    invoke  GetPropW,dword[esp+8],eax
    mov     [OrigDropTarget],eax
    comcall eax,IDropTarget,AddRef
    invoke  RevokeDragDrop,dword[esp+4]
    invoke  RegisterDragDrop,dword[esp+8],DropTarget
    xor     eax,eax
  @@:
ret 16

Invoke: ;this,DispID,IID,LocaleID,Flags,Params,VarResult,ExcepInfo,ArgErr
  mov  eax,[esp+24] ;[Params]
  mov  eax,[eax+DISPPARAMS.rgvarg]
  mov  ecx,dword[eax+sizeof.VARIANT*3+VARIANT.data]
  cmp  dword[esp+8],OnDocumentNew
  je  .OnDocumentNew
  mov ecx,dword[eax+sizeof.VARIANT+VARIANT.data]
  cmp dword[esp+8],OnDocumentOpen
  jne  @f
    .OnDocumentNew:
    push    ebx
    sub     esp,4
    comcall ecx,IVGDocument,Get_ActiveWindow,esp
    mov     ebx,[esp]
    comcall ebx,IVGWindow,Get_Handle,esp
    comcall ebx,IVGWindow,Release
    mov     ebx,[esp]
    invoke  SetWindowLongW,ebx,GWL_WNDPROC,WndProc ;RegisterDragDrop must be called from message loop thread - so subclass window for do this
    invoke  SendMessageW,ebx,WM_ENABLE,eax,0
    pop     ebx
    pop     ebx
  @@:
  xor     eax,eax
ret 36

StartSession:     ;(const self:IVGAppPlugin):LongInt;stdcall;
  cominvk CorelApp,AdviseEvents,IPlugin,EventsCookie
  xor     eax,eax
ret 4

StopSession:      ;(const self:IVGAppPlugin):LongInt;stdcall;
  cominvk CorelApp,UnadviseEvents,[EventsCookie]
  xor     eax,eax
ret 4

OnLoad: ;(const self:IVGAppPlugin; const _Application: IVGApplication):LongInt;stdcall;
  mov     eax,[esp+8]
  mov     [CorelApp],eax
  comcall eax,IVGApplication,AddRef
ret 8

OnUnload:         ;(const self:IVGAppPlugin)LongInt;stdcall;
  cominvk CorelApp,Release
  xor     eax,eax
ret 4

QueryInterface2:   ;(const self:IVGAppPlugin; const IID: TGUID; out Obj): HResult; stdcall;
  mov eax,[esp+12]
  mov dword[eax],DropTarget
  xor eax,eax
ret 12

Release2:
  mov eax,[OrigDropTarget]
  mov dword[esp+4],eax
  mov eax,[eax]
  jmp [eax+IDropTarget.Release]

DragEnter: ; this,dataObj,grfKeyState,pt,dwEffect
  mov eax,[OrigDropTarget]
  mov dword[esp+4],eax
  mov eax,[eax]
  jmp [eax+IDropTarget.DragEnter]

DragOver:   ;(this,grfKeyState: Longint; pt: TPoint;var dwEffect: Longint): HResult; stdcall;
  mov eax,[OrigDropTarget]
  mov dword[esp+4],eax
  mov eax,[eax]
  jmp [eax+IDropTarget.DragOver]

DragLeave:  ;: HResult; stdcall;
  mov eax,[OrigDropTarget]
  mov dword[esp+4],eax
  mov eax,[eax]
  jmp [eax+IDropTarget.DragLeave]

SetImageData: ;(const Image: IVGImage; data: pointer);
  pushad
  mov     eax,[esp+36]
  comcall eax,IVGImage,Get_Tiles,Tiles
  cominvk Tiles,Get_Count,TileCount
  .MainLoop:
    cominvk Tiles,Get_Item,[TileCount],tmp
    mov     ebp,[tmp]
    comcall ebp,IVGImageTile,Get_Left,TileX
    comcall ebp,IVGImageTile,Get_Bottom,TileY
    comcall ebp,IVGImageTile,Get_Width,TileWidth
    comcall ebp,IVGImageTile,Get_Height,TileHeight
    comcall ebp,IVGImageTile,Get_BytesPerPixel,TileBPP
    comcall ebp,IVGImageTile,Get_BytesPerLine,TileBPL
    mov     ecx,[TileWidth]
    mov     edx,[TileHeight]
    mov     edi,[TileData]
    mov     esi,[esp+40]
    mov     eax,[TileBPP]
    mov     ebx,dword[PixelMask+eax*4-4]
    mov     ebp,ebx
    not     ebx
    imul    ecx,eax
    mov     eax,[TileBPL]
    imul    eax,edx
    mov     [rgsabound.cElements],eax

    sub     eax,[TileBPL]
    lea     edi,[eax+ecx]

    add     edx,[TileY]
    mov     eax,[ImageWidth]
    dec     edx
    imul    edx,eax
    sub     eax,[TileWidth]
    add     edx,[TileX]
    shl     eax,2
    add     edx,[TileWidth]
    push    eax
    lea     esi,[esi+edx*4]

    mov     eax,[TileBPL]
    sub     eax,ecx
    push    eax

    invoke  SafeArrayCreate,VT_UI1,1,rgsabound
    mov     [TileData],eax
    add     edi,[eax+SAFEARRAY.pvData]
    add     esp,8

    mov     edx,[TileHeight]
    .Row:mov ecx,[TileWidth]
         .Col:sub edi,[TileBPP]
              sub esi,4
              mov eax,[esi]
              and [edi],ebx
              and eax,ebp
              or  [edi],eax
              dec ecx
         jne .Col
         sub edi,[esp-8]
         sub esi,[esp-4]
         dec edx
    jne .Row

    mov     ebp,[tmp]
    comcall ebp,IVGImageTile,Set_PixelData,TileData
    invoke  SafeArrayDestroy,[TileData]
    comcall ebp,IVGImageTile,Release
    dec     [TileCount]
  jne .MainLoop
  cominvk Tiles,Release
  popad
ret 8

Drop: ;this,dataObj,grfKeyState,pt,dwEffect
  mov     eax,[esp+8]
  pushad
  comcall eax,IDataObject,GetData,formatetc,stgMedium
  test    eax,eax
  jne .NoHDROP
    cominvk CorelApp,Get_ActiveDocument,CorelDoc
    cominvk CorelDoc,Get_ActiveLayer,ActiveLayer
    cominvk CorelDoc,Get_ActiveWindow,ActiveWindow
    cominvk CorelDoc,BeginCommandGroup,strOleDropTargetInterface
    cominvk CorelDoc,Set_Unit,cdrMillimeter
    cominvk ActiveWindow,ScreenToDocument,dword[esp+60],dword[esp+60],x,y
    cominvk ActiveWindow,Release
    invoke  DragQueryFileW,[stgMedium.hGlobal],-1,0,0
    lea     ebp,[eax-1]
    @@:invoke  DragQueryFileW,[stgMedium.hGlobal],ebp,buf,sizeof.buf
       mov     ecx,dword[buf+eax*2-8]
       mov     edx,dword[buf+eax*2-4]
       and     ecx,$FFDFFFDF
       and     edx,$FFDFFFDF
       sub     ecx,$450057
       sub     edx,$500042
       or      ecx,edx ;if file path ends with 'webp'
       jne .unk
         invoke   CreateFileW,buf,GENERIC_READ,0,0,OPEN_EXISTING,0,0
         mov      ebx,eax
         invoke   GetFileSize,eax,0
         mov      [filesize],eax
         invoke   VirtualAlloc,0,eax,MEM_COMMIT,PAGE_READWRITE
         mov      [webpData],eax
         invoke   ReadFile,ebx,eax,[filesize],filesize,0
         invoke   CloseHandle,ebx
         stdcall  WebPGetInfo,[webpData],[filesize],ImageWidth,ImageHeight
         mov      ebx,[ImageWidth]
         mov      edi,[ImageHeight]
         shl      ebx,2
         imul     edi,ebx
         lea      eax,[edi+4]
         invoke   VirtualAlloc,0,eax,MEM_COMMIT,PAGE_READWRITE
         mov      esi,eax
         stdcall  WebPDecodeBGRAInto,[webpData],[filesize],eax,edi,ebx
         invoke   VirtualFree,[webpData],0,MEM_RELEASE
         cominvk  CorelDoc,CreateImage,cdrRGBColorImage,[ImageWidth],[ImageHeight],0,Image
         cominvk  CorelDoc,CreateImage,cdrGrayscaleImage,[ImageWidth],[ImageHeight],0,ImageAlpha
         stdcall  SetImageData,[Image],esi
         lea      eax,[esi+3]
         stdcall  SetImageData,[ImageAlpha],eax
         invoke   VirtualFree,esi,0,MEM_RELEASE
         movapd   xmm0,dqword[x]
         cvtpi2pd xmm1,qword[ImageWidth]
         push     dword Shape
         push     [ImageAlpha]
         push     [Image]
         sub      esp,32
         movupd   [esp],xmm0
         movupd   [esp+16],xmm1
         cominvk  ActiveLayer,CreateBitmap2
         cominvk  Image,Release
         cominvk  ImageAlpha,Release
         cominvk  Shape,Flip,cdrFlipVertical
         cominvk  Shape,Release
         jmp .next
       .unk:
         mov     dword[buf-4],eax
         cominvk ActiveLayer,Import,buf,0,0
         mov     [Shape],0
         cominvk CorelDoc,Selection,Shape
         movapd  xmm0,dqword[x]
         sub     esp,16
         movupd  [esp],xmm0
         cominvk Shape,SetPositionEx,cdrBottomLeft
         cominvk Shape,Release
       .next:
       dec     ebp
    jns @b
    invoke  DragFinish,[stgMedium.hGlobal]
    invoke  ReleaseStgMedium,stgMedium
    cominvk ActiveLayer,Release
    cominvk CorelDoc,EndCommandGroup
    cominvk CorelDoc,Release
    popad
    xor     eax,eax
    ret 20
  .NoHDROP:
    popad
    mov eax,[OrigDropTarget]
    mov dword[esp+4],eax
    mov eax,[eax]
    jmp [eax+IDropTarget.Drop]

section 'data' readable writeable
  DropTarget     dd  IDropTargetVMT
  IDropTargetVMT dd  QueryInterface2,\
                     AddRef,\
                     Release2,\
                     DragEnter,\
                     DragOver,\
                     DragLeave,\
                     Drop

  IPlugin        dd IPluginVMT
  IPluginVMT     dd QueryInterface,\
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

  strOleDropTargetInterface OLEstr 'OleDropTargetInterface'
  PixelMask                 dd $FF,$FFFF,$FFFFFF,$FFFFFFFF
  formatetc                 FORMATETC CF_HDROP,0,DVASPECT_CONTENT,-1,TYMED_HGLOBAL

section '' readable writeable
  x              rq 1
  y              rq 1
  stgMedium      uSTGMEDIUM
  CorelApp       IVGApplication
  OrigDropTarget IDropTarget
  CorelDoc       IVGDocument
  ActiveLayer    IVGLayer
  ActiveWindow   IVGWindow
  Shape          IVGShape
  Image          IVGImage
  ImageAlpha     IVGImage
  Tiles          IVGImageTiles
  filesize       rd 1
  webpData       rd 1
  EventsCookie   rd 1
  ImageWidth     rd 1
  ImageHeight    rd 1
  TileCount      rd 1
  TileX          rd 1
  TileY          rd 1
  TileWidth      rd 1
  TileHeight     rd 1
  TileBPP        rd 1
  TileBPL        rd 1
  TileData       rd 1
  TileStart      rd 1
  tmp            rd 1
  len            rd 1
  rgsabound      SAFEARRAYBOUND
  buf            rw 4096
  sizeof.buf=($-buf) shr 1
