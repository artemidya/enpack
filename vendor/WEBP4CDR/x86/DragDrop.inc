DROPEFFECT_NONE    = 0
DROPEFFECT_COPY    = 1
DROPEFFECT_MOVE    = 2
DROPEFFECT_LINK    = 4
DROPEFFECT_SCROLL  = $80000000

DVASPECT_CONTENT   = 1
DVASPECT_THUMBNAIL = 2
DVASPECT_ICON      = 4
DVASPECT_DOCPRINT  = 8

TYMED_NULL         = 0
TYMED_HGLOBAL      = 1
TYMED_FILE         = 2
TYMED_ISTREAM      = 4
TYMED_ISTORAGE     = 8
TYMED_GDI          = 16
TYMED_MFPICT       = 32
TYMED_ENHMF        = 64

CF_TEXT            = 1
CF_BITMAP          = 2
CF_METAFILEPICT    = 3
CF_SYLK            = 4
CF_DIF             = 5
CF_TIFF            = 6
CF_OEMTEXT         = 7
CF_DIB             = 8
CF_PALETTE         = 9
CF_PENDATA         = 10
CF_RIFF            = 11
CF_WAVE            = 12
CF_UNICODETEXT     = 13
CF_ENHMETAFILE     = 14
CF_HDROP           = 15
CF_LOCALE          = 16
CF_DIBV5           = 17
CF_MAX             = 17

struct FORMATETC
  cfFormat rd 1 ;CLIPFORMAT
  ptd      rd 1 ;*DVTARGETDEVICE
  dwAspect rd 1
  lindex   rd 1
  tymed    rd 1
ends

struct uSTGMEDIUM
  tymed         rd 1
  union
    hBitmap       rd 1 ;HBITMAP
    hMetaFilePict rd 1 ;HMETAFILEPICT
    hEnhMetaFile  rd 1 ;HENHMETAFILE
    hGlobal       rd 1 ;HGLOBAL
    lpszFileName  rd 1 ;LPOLESTR
    pstm          rd 1 ;IStream
    pstg          rd 1 ;IStorage
  ends
  pUnkForRelease rd 1
ends

interface IDataObject,\
  QueryInterface,\
  AddRef,\
  Release,\
  GetData,\               ;(const formatetcIn: TFormatEtc; out medium: TStgMedium): HResult; stdcall;
  GetDataHere,\           ;(const formatetc: TFormatEtc; out medium: TStgMedium): HResult; stdcall;
  QueryGetData,\          ;(const formatetc: TFormatEtc): HResult; stdcall;
  GetCanonicalFormatEtc,\ ;(const formatetc: TFormatEtc; out formatetcOut: TFormatEtc): HResult; stdcall;
  SetData,\               ;(const formatetc: TFormatEtc; var medium: TStgMedium; fRelease: BOOL): HResult; stdcall;
  EnumFormatEtc,\         ;(dwDirection: Longint; out enumFormatEtc: IEnumFormatEtc): HResult; stdcall;
  DAdvise,\               ;(const formatetc: TFormatEtc; advf: Longint; const advSink: IAdviseSink; out dwConnection: Longint): HResult; stdcall;
  DUnadvise,\             ;(dwConnection: Longint): HResult; stdcall;
  EnumDAdvise             ;(out enumAdvise: IEnumStatData): HResult; stdcall;

interface IDropTarget,\
  QueryInterface,\
  AddRef,\
  Release,\
  DragEnter,\  ;(const dataObj: IDataObject; grfKeyState: Longint;pt: TPoint; var dwEffect: Longint): HResult; stdcall;
  DragOver,\   ;(grfKeyState: Longint; pt: TPoint;var dwEffect: Longint): HResult; stdcall;
  DragLeave,\  ;: HResult; stdcall;
  Drop         ;(const dataObj: IDataObject; grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult; stdcall;