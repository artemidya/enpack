# Raster add-ons: x64 ABI metadata check

VGCoreAuto (27, 2), SHA256 `7044b6074dfa445f39f6238062ae40e96e01c7764dc28d215872abacce3bdd7c`

Slots only: not a CorelDRAW runtime or geometry test.

## bleeds

| Interface.method | Source slot | TLB slot |
|---|---:|---:|
| IVGApplication.AddPluginCommand | 121 | [121] |
| IVGApplication.AdviseEvents | 97 | [97] |
| IVGApplication.CreateCMYKColor | 59 | [59] |
| IVGApplication.Get_ActiveDocument | 12 | [12] |
| IVGApplication.Get_ActiveSelectionRange | 48 | [48] |
| IVGApplication.Get_ActiveWindow | 14 | [14] |
| IVGApplication.Get_GlobalUserData | 126 | [126] |
| IVGApplication.Refresh | 77 | [77] |
| IVGApplication.UnadviseEvents | 98 | [98] |
| IVGBitmap.Get_Image | 40 | [40] |
| IVGBitmap.Get_ImageAlpha | 41 | [41] |
| IVGBitmap.Get_Mode | 16 | [16] |
| IVGBitmap.Get_ResolutionX | 9 | [9] |
| IVGBitmap.Trace | 39 | [39] |
| IVGDocument.BeginCommandGroup | 42 | [42] |
| IVGDocument.CreateImage | 173 | [173] |
| IVGDocument.EndCommandGroup | 43 | [43] |
| IVGDocument.Get_ActiveLayer | 18 | [18] |
| IVGDocument.Get_ActivePage | 17 | [17] |
| IVGDocument.Get_SelectionRange | 51 | [51] |
| IVGDocument.Set_Unit | 27 | [27] |
| IVGEffect.Separate | 23 | [23] |
| IVGFill.ApplyNoFill | 18 | [18] |
| IVGImage.Get_Height | 9 | [9] |
| IVGImage.Get_Tiles | 13 | [13] |
| IVGImage.Get_Width | 8 | [8] |
| IVGImage.Get_type | 7 | [7] |
| IVGImageTile.Get_Bottom | 10 | [10] |
| IVGImageTile.Get_BytesPerLine | 14 | [14] |
| IVGImageTile.Get_BytesPerPixel | 15 | [15] |
| IVGImageTile.Get_Height | 12 | [12] |
| IVGImageTile.Get_Left | 7 | [7] |
| IVGImageTile.Get_PixelData | 16 | [16] |
| IVGImageTile.Get_Width | 11 | [11] |
| IVGImageTile.Set_PixelData | 17 | [17] |
| IVGImageTiles.Get_Count | 7 | [7] |
| IVGImageTiles.Get_Item | 8 | [8] |
| IVGLayer.Activate | 12 | [12] |
| IVGLayer.CreateBitmap2 | 83 | [83] |
| IVGLayers.Find | 12 | [12] |
| IVGOutline.Set_Width | 8 | [8] |
| IVGPage.CreateLayer | 28 | [28] |
| IVGPage.Get_Layers | 11 | [11] |
| IVGProperties.Get_Item | 7 | [7] |
| IVGProperties.Set_Item | 8 | [8] |
| IVGShape.BreakApartEx | 133 | [133] |
| IVGShape.ConvertToBitmapEx | 118 | [118] |
| IVGShape.CreateContour | 93 | [93] |
| IVGShape.Delete | 31 | [31] |
| IVGShape.Duplicate | 32 | [32] |
| IVGShape.GetPosition | 68 | [68] |
| IVGShape.GetSize | 69 | [69] |
| IVGShape.Get_Bitmap | 26 | [26] |
| IVGShape.Get_Fill | 29 | [29] |
| IVGShape.Get_Outline | 28 | [28] |
| IVGShape.Get_RotationAngle | 35 | [35] |
| IVGShape.Get_type | 27 | [27] |
| IVGShape.MoveToLayer | 157 | [157] |
| IVGShape.OrderBackOf | 51 | [51] |
| IVGShape.Weld | 75 | [75] |
| IVGShapeRange.Add | 12 | [12] |
| IVGShapeRange.Combine | 59 | [59] |
| IVGShapeRange.Get_Count | 11 | [11] |
| IVGShapeRange.Get_FirstShape | 129 | [129] |
| IVGShapeRange.Get_Item | 9 | [9] |
| IVGShapeRange.Get_LastShape | 130 | [130] |
| IVGShapeRange.Group | 26 | [26] |
| IVGShapeRange.RemoveAll | 27 | [27] |
| IVGTraceSettings.Finish | 31 | [31] |
| IVGWindow.Get_Handle | 35 | [35] |
## seamcarving

| Interface.method | Source slot | TLB slot |
|---|---:|---:|
| IVGAppWindow.Get_Handle | 25 | [25] |
| IVGApplication.Get_ActiveLayer | 44 | [44] |
| IVGApplication.Get_ActiveSelectionRange | 48 | [48] |
| IVGApplication.Get_AppWindow | 24 | [24] |
| IVGLayer.CreateRectangle2 | 46 | [46] |
| IVGOutline.SetNoOutline | 48 | [48] |
| IVGShape.AddToPowerClip | 98 | [98] |
| IVGShape.GetPosition | 68 | [68] |
| IVGShape.GetSize | 69 | [69] |
| IVGShape.Get_OriginalHeight | 88 | [88] |
| IVGShape.Get_OriginalWidth | 87 | [87] |
| IVGShape.Get_Outline | 28 | [28] |
| IVGShape.SetSize | 67 | [67] |
| IVGShapeRange.Get_FirstShape | 129 | [129] |

WEBP4CDR uses IDispatch names (no inherited Corel vtable offsets).

Mismatches: 0
PASS
