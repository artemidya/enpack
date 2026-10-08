include 'MACRO\struct.inc'
struct PSRGBColor
  r rw 1
  g rw 1
  b rw 1
ends

struct PSPoint
  v rw 1
  h rw 1
ends

struct PSPoint32
 v rd 1
 h rd 1
ends

struct PSRect
  top    rw 1
  left   rw 1
  bottom rw 1
  right  rw 1
ends

struct PSRect32
  top    rd 1
  left   rd 1
  bottom rd 1
  right  rd 1
ends

struct PlugInMonitor
  gamma   rd 1 ;The monitors gamma value or zero if the whole record is invalid.
  redX    rd 1 ;The chromaticity coordinates of the monitors phosphors.
  redY    rd 1 ;The chromaticity coordinates of the monitors phosphors.
  greenX  rd 1 ;The chromaticity coordinates of the monitors phosphors.
  greenY  rd 1 ;The chromaticity coordinates of the monitors phosphors.
  blueX   rd 1 ;The chromaticity coordinates of the monitors phosphors.
  blueY   rd 1 ;The chromaticity coordinates of the monitors phosphors.
  whiteX  rd 1 ;The chromaticity coordinates of the monitors white point.
  whiteY  rd 1 ;The chromaticity coordinates of the monitors white point.
  ambient rd 1 ;The relative amount of ambient light in the room.
ends

struct FilterRecord
  serialNumber             rd 1
  TestAbortProc            rd 1 ;function:boolean;cdecl;               pointer to the TestAbortProc callback.
  ProgressProc             rd 1 ;procedure(done,total: integer);cdecl; pointer the the ProgressProc callback.
  parameters               rd 1 ;                                      Parameters the plug-in can request from a user.
  ImageSize                PSPoint;
  planes                   rw 1 ;                                      The number of planes in the image.
  align1                   rw 1
  filterRect               PSRect
  background               PSRGBColor
  foreground               PSRGBColor
  maxSpace                 rd 1
  bufferSpace              rd 1
  inRect                   PSRect
  inLoPlane                rw 1 ;                                      The first input plane to process next.
  inHiPlane                rw 1 ;                                      The last input plane to process next.
  outRect                  PSRect
  outLoPlane               rw 1 ;                                      The first output plane to process next.
  outHiPlane               rw 1 ;                                      The last output plane to process next.
  inData                   rd 1 ;pointer;                              A pointer to the requested input image data.
  inRowBytes               rd 1 ;                                      The offset between rows of the input image data.
  outData                  rd 1 ;pointer;                              A pointer to the requested output image data.
  outRowBytes              rd 1 ;                                      The offset between rows of the output image data.
  isFloating               rb 1 ;boolean;                              Indicates if the selection is floating.
  haveMask                 rb 1 ;boolean;                              Indicates if the selection has a mask.
  autoMask                 rb 1 ;boolean;                              Enables or disables auto-masking.
  align2                   rb 1
  maskRect                 PSRect
  maskData                 rd 1 ;pointer;                              A pointer to the requested mask data.
  maskRowBytes             rd 1 ;                                      The offset between rows of the mask data.
  backColor                rd 1 ;                                      The current background color, in the color space native to the image.
  foreColor                rd 1 ;                                      The current foreground color, in the color space native to the image.
  hostSig                  rd 1 ;                                      The signature of the host, provided by the host.
  hostProc                 rd 1 ;procedure(selector: word; data: pointer);cdecl; A pointer to a host-defined callback procedure.
  imageMode                rw 1 ;                                      The mode of the image being filtered, for example, Gray Scale, RGB Color, and so forth.
  align3                   rw 1 ;
  imageHRes                rd 1 ;                                      The horizontal resolution of the image in terms of pixels per inch.
  imageVRes                rd 1 ;                                      The vertical resolution of the image in terms of pixels per inch.
  floatCoord               PSPoint
  wholeSize                PSPoint
  monitor                  PlugInMonitor;                              Monitor setup information for the host.
  platformData             rd 1 ;pointer;                              A pointer to platform specific data.
  bufferProcs              rd 1 ;PBufferProcs;                         A pointer to the Buffer suite if it is supported by the host, otherwise NULL.
  resourceProcs            rd 1 ;PResourceProcs;                       A pointer to the Pseudo-Resource suite if it is supported by the host, otherwise NULL.
  processEvent             rd 1 ;procedure;                            A pointer to the ProcessEventProc callback if it is supported by the host, otherwise NULL.
  displayPixels            rd 1 ;function(source: PPSPixelMap;srcRect: PRect; dstRow,dstCol: integer; platformContext: pointer):pword;cdecl;     //A pointer to the DisplayPixelsProc callback if it is supported by the host, otherwise NULL.
  handleProcs              rd 1 ;PHandleProcs;                         A pointer to the Handle callback suite if it is supported by the host, otherwise NULL.
  supportsDummyChannels    rb 1 ;boolean;                              Indicates whether the host supports the plug-in requesting nonexistent planes.
  supportsAlternateLayouts rb 1 ;boolean;                              Indicates whether the host support data layouts other than rows of columns of planes.
  wantLayout               rw 1 ;                                      The desired layout for the data.
  filterCase               rw 1 ;                                      The type of data being filtered.
  dummyPlaneValue          rw 1 ;                                      The value to store into any dummy planes.
  premiereHook             rd 1 ;pointer;
  advanceState             rd 1 ;function:pword;cdecl;                 AdvanceState callback.
  supportsAbsolute         rb 1 ;boolean;                              Indicates whether the host supports absolute channel indexing.
  wantsAbsolute            rb 1 ;boolean;                              Enables absolute channel indexing for the input.
  align4                   rw 1
  getPropertyObsolete      rd 1 ;function(signature,key,index: dword;simpleProperty,complexProperty: pointer):pword;cdecl;       //The GetProperty callback.
  cannotUndo               rb 1 ;boolean;                              Indicates whether a filter plug-in makes changes that the user cannot undo.
  supportsPadding          rb 1 ;boolean;                              Indicates whether the host supports requests outside the image area.
  inputPadding             rw 1 ;                                      Instructions for padding the input.
  outputPadding            rw 1 ;                                      Instructions for padding the output.
  maskPadding              rw 1 ;                                      Padding instructions for the mask.
  samplingSupport          rb 1 ;                                      Indicates whether the host support non- 1:1 sampling of the input and mask.
  reservedByte             rb 1 ;                                      For alignment.
  inputRate                rd 1 ;                                      The sampling rate for the input.
  maskRate                 rd 1 ;                                      Like inputRate, but as applied to the mask data.
  align5                   rw 1 ;
  colorServices            rd 1 ;function(info: PColorServicesInfo):pword;cdecl;     //Function pointer to access color services routine.
  inLayerPlanes            rw 1 ;                                      The number of target layer planes for the input data.
  inTransparencyMask       rw 1 ;                                      The number of transparency masks for the input target layer data.
  inLayerMasks             rw 1 ;                                      The number of layer mask channels for the input target layer.
  inInvertedLayerMasks     rw 1 ;                                      The number of inverted layer mask channels for the input target layer.
  inNonLayerPlanes         rw 1 ;                                      The number of non-layer channels for the input data.
  outLayerPlanes           rw 1 ;                                      The number of target layer planes for the output data.
  outTransparencyMask      rw 1 ;                                      The number of transparency masks for the output data.
  outLayerMasks            rw 1 ;                                      The number of layer mask channels for the output data.
  outInvertedLayerMasks    rw 1 ;                                      The number of inverted layer mask channels for the output data.
  outNonLayerPlanes        rw 1 ;                                      The number of non-layer channels for the output data.
  absLayerPlanes           rw 1 ;                                      The number of target layer planes for the input data, used for the structure of the input data when wantsAbsolute is TRUE.
  absTransparencyMask      rw 1 ;                                      The number of transparency masks for the input data, used for the structure of the input data when wantsAbsolute is TRUE.
  absLayerMasks            rw 1 ;                                      The number of layer mask channels for the input data, used for the structure of the input data when wantsAbsolute is TRUE.
  absInvertedLayerMasks    rw 1 ;                                      The number of inverted layer mask channels for the input data, used for the structure of the input data when wantsAbsolute is TRUE.
  absNonLayerPlanes        rw 1 ;                                      The number of target layer planes for the input data, used for the structure of the input data when wantsAbsolute is TRUE.
  inPreDummyPlanes         rw 1 ;                                      The number of extra planes before the input data.
  inPostDummyPlanes        rw 1 ;                                      The number of extra planes after the input data.
  outPreDummyPlanes        rw 1 ;                                      The number of extra planes before the output data.
  outPostDummyPlanes       rw 1 ;                                      The number of extra planes after the output data.
  inColumnBytes            rd 1 ;                                      The step from column to column in the input.
  inPlaneBytes             rd 1 ;                                      The step from plane to plane in the input.
  outColumnBytes           rd 1 ;                                      The output equivalent of inColumnBytes.
  outPlaneBytes            rd 1 ;                                      The output equivalent of inPlaneBytes.
  align6                   rw 1
  imageServicesProcs       rd 1 ;PImageServicesProcs;                  Image Services callback suite.
  propertyProcs            rd 1 ;PPropertyProcs;                       Property callback suite.
  inTileHeight             rw 1 ;                                      Tiling height for the input, set by host.
  inTileWidth              rw 1 ;                                      Tiling width for the input, set by host.
  inTileOrigin             PSPoint;                                    Tiling origin for the input, set by host.
  absTileHeight            rw 1 ;                                      Tiling height the absolute data, set by host.
  absTileWidth             rw 1 ;                                      Tiling width the absolute data, set by host.
  absTileOrigin            PSPoint;                                    Tiling origin the absolute data, set by host.
  outTileHeight            rw 1 ;                                      Tiling height for the output, set by host.
  outTileWidth             rw 1 ;                                      Tiling width for the output, set by host.
  outTileOrigin            PSPoint;                                    Tiling origin for the output, set by host.
  maskTileHeight           rw 1 ;                                      Tiling height for the mask, set by host.
  maskTileWidth            rw 1 ;                                      Tiling width for the mask, set by host.
  maskTileOrigin           PSPoint;                                    Tiling origin for the mask, set by host.
  descriptorParameters     rd 1 ;PPIDescriptorParameters;              Descriptor callback suite.
  errorString              rd 1 ;PAnsiChar;                            An error reporting string to return to Photoshop.
  channelPortProcs         rd 1 ;PChannelPortProcs;                    Channel Ports callback suite.
  documentInfo             rd 1 ;PReadImageDocumentDesc;               The Channel Ports document information for the document being filtered.
  sSPBasic                 rd 1 ;pointer;                              SPBasicSuite PICA basic suite.
  plugInRef                rd 1 ;pointer;                              Plug-in reference used by PICA.
  depth                    rd 1 ;                                      Bit depth per channel (1,8,16,32).
  iCCprofileData           rd 1 ;                                      Handle containing the ICC profile for the image.
  iCCprofileSize           rd 1 ;                                      Size of profile.
  canUseICCProfiles        rd 1 ;                                      Indicates if the host uses ICC Profiles.
  hasImageScrap            rd 1 ;                                      Indicates if Photoshop has image scrap; non-zero if it does.
  bigDocumentData          rd 1 ;PBigDocumentStruct;                   Support for documents larger than 30,000 pixels.
  input3DScene             rd 1 ;PPIDescriptorParameters;              support for 3d scene data to be sent into the plug-in
  output3DScene            rd 1 ;PPIDescriptorParameters;              support for 3d scene to come out of the plug-in
  createNewLayer           rb 1 ;boolean;                              set by plug-in this only works for 3D layers
  iCCWorkingProfileData    rd 1 ;                                      Handle containing the ICC profile for the working profile set via color settings dialog.
  iCCWorkingProfileSize    rd 1 ;                                      Size of working profile.
  bufferSpace64            rq 1 ;                                      Allows the plug-in to specify how much buffer space it needs.
  maxSpace64               rq 1 ;                                      The maximum number of bytes of informa
ends

;'8BIM' сигратура Photoshop
kPhotoshopSignature              =0x3842494d
kCurrentPiPLVersion              =0

;Основные свойства
PIKindProperty                   =0x6b696e64    ;'kind' тип плагина
PIVersionProperty                =0x76657273    ;'vers' версия интерфейса редактора
PIPriorityProperty               =0x70727479    ;'prty' порядок загрузки плагинов
PIImageModesProperty             =0x6d6f6465    ;'mode' поддерживаемые режимы изображения
PIEnableInfoProperty             =0x656e626c    ;'enbl' когда плагин в меню будет доступен
PIRequiredHostProperty           =0x686f7374    ;'host' редактор, для которого написан плагин
PICategoryProperty               =0x63617467    ;'catg' подменю в меню Filter
PINameProperty                   =0x6e616d65    ;'name' название плагина
PIProgressTextProperty           =0x70726f67    ;'prog' текст индикатора процесса
PIWin32X86CodeProperty           =0x77783836    ;'wx86' название основной процедуры плагина

;Типы плагинов (PIKindProperty)
kGeneral                         =0x38425049    ;'8BPI'
kActions                         =0x384C495A    ;'8LIZ'
kColorPicker                     =0x3842434D    ;'8BCM'
kExport                          =0x3842454D    ;'8BEM'
kExtension                       =0x3842584D    ;'8BXM'
kFilter                          =0x3842464D    ;'8BFM'
kImageFormat                     =0x38424946    ;'8BIF'
kParser                          =0x3842594D    ;'8BYM'
kSelection                       =0x3842534D    ;'8BSM'

;Режимы изображения (PIImageModesProperty)
supportsBitmap                   =0x0080
supportsGrayScale                =0x0040
supportsIndexedColor             =0x0020
supportsRGBColor                 =0x0010
supportsCMYKColor                =0x0008
supportsHSLColor                 =0x0004
supportsHSBColor                 =0x0002
supportsMultichannel             =0x0001
supportsDuotone                  =0x8000
supportsLABColor                 =0x4000
supportsGray16                   =0x2000
supportsRGB48                    =0x1000
supportsLab48                    =0x0800
supportsCMYK64                   =0x0400
supportsDeepMultichannel         =0x0200
supportsDuotone16                =0x0100

;Свойство фильтра 'fici'
PIFilterCaseInfoProperty         =0x66696369

;Режимы пред- и пост-обработки данных фильтра
filterDataHandlingCantFilter     =0
filterDataHandlingNone           =1
filterDataHandlingBlackMat       =2
filterDataHandlingGrayMat        =3
filterDataHandlingWhiteMat       =4

;режимы, применимые только для входных данных
filterDataHandlingDefringe       =5
filterDataHandlingBlackZap       =6
filterDataHandlingGrayZap        =7
filterDataHandlingWhiteZap       =8

;режимы, применимые только для выходных данных
filterDataHandlingFillMask       =9

;еще режимы для входных данных
filterDataHandlingBackgroundZap  =10
filterDataHandlingForegroundZap  =11

;flags1
PIFilterDontCopyToDestinationBit =0
PIFilterWorksWithBlankDataBit    =1
PIFilterFiltersLayerMaskBit      =2
PIFilterWritesOutsideSelectionBit=3

macro PIPL [type,string]{
  common
    paramcount=1
  forward
    paramcount=paramcount+1
  common
    dw 1
    dd kCurrentPiPLVersion
    dd paramcount
  forward
    local len1,len2,str,propHeader
    propHeader dd kPhotoshopSignature,type,0,len2
    if (type=PICategoryProperty)|(type=PINameProperty)
      str db len1-1,string
      len1=$-str
    else if string eqtype ""
      str db string,0
    else
      str dd string
    end if
    if ($-propHeader) and 3>0
      db 4-(($-propHeader) and 3) dup 0
    end if
    len2=$-str
}