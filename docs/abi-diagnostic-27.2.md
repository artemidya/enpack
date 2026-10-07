# Interface check: VGCore 27.2 (x64)

TLB SHA-256: `7044b6074dfa445f39f6238062ae40e96e01c7764dc28d215872abacce3bdd7c`

Source: `src/x64`

This checks vtable slots and event DISPIDs only, not parameter types,
Windows loading, UI behavior or packing correctness.

| Interface | Method | Source slot | TLB slot | Result |
|---|---|---:|---:|---|
| ICUICommandBar | Get_Controls | 10 | 10 | PASS |
| ICUICommandBar | Get_Visible | 8 | 8 | PASS |
| ICUICommandBar | Set_Visible | 9 | 9 | PASS |
| ICUICommandBars | Add | 10 | 10 | PASS |
| ICUICommandBars | Get_Item | 7 | 7 | PASS |
| ICUIControl | Get_Caption | 7 | 7 | PASS |
| ICUIControl | SetIcon2 | 26 | 26 | PASS |
| ICUIControls | AddCustomButton | 11 | 11 | PASS |
| ICUIControls | Get_Count | 7 | 7 | PASS |
| ICUIControls | Get_Item | 8 | 8 | PASS |
| IVGApplication | AddPluginCommand | 121 | 121 | PASS |
| IVGApplication | AdviseEvents | 97 | 97 | PASS |
| IVGApplication | Get_ActiveDocument | 12 | 12 | PASS |
| IVGApplication | Get_ActiveSelectionRange | 48 | 48 | PASS |
| IVGApplication | Get_ActiveWindow | 14 | 14 | PASS |
| IVGApplication | Get_CommandBars | 72 | 72 | PASS |
| IVGApplication | Get_VersionMajor | 38 | 38 | PASS |
| IVGApplication | Get_VersionMinor | 39 | 39 | PASS |
| IVGApplication | Refresh | 77 | 77 | PASS |
| IVGApplication | RemovePluginCommand | 122 | 122 | PASS |
| IVGApplication | Set_Optimization | 53 | 53 | PASS |
| IVGApplication | UnadviseEvents | 98 | 98 | PASS |
| IVGDocument | BeginCommandGroup | 42 | 42 | PASS |
| IVGDocument | EndCommandGroup | 43 | 43 | PASS |
| IVGDocument | Get_ActiveLayer | 18 | 18 | PASS |
| IVGDocument | Set_ReferencePoint | 14 | 14 | PASS |
| IVGDocument | Set_Unit | 27 | 27 | PASS |
| IVGLayer | CreateRectangle | 29 | 29 | PASS |
| IVGOutline | Set_Width | 8 | 8 | PASS |
| IVGShape | Get_Outline | 28 | 28 | PASS |
| IVGShape | Get_SizeHeight | 21 | 21 | PASS |
| IVGShape | Get_SizeWidth | 19 | 19 | PASS |
| IVGShape | SetPosition | 66 | 66 | PASS |
| IVGShape | Set_RotationAngle | 36 | 36 | PASS |
| IVGShapeRange | GetPosition | 21 | 21 | PASS |
| IVGShapeRange | Get_Count | 11 | 11 | PASS |
| IVGShapeRange | Get_Item | 9 | 9 | PASS |
| IVGWindow | Get_Handle | 35 | 35 | PASS |

## Application event DISPIDs

- SelectionChange: source=17, TLB=17, PASS
- OnPluginCommand: source=20, TLB=20, PASS
- OnUpdatePluginCommand: source=21, TLB=21, PASS

Checked 38 Corel/UI methods and 3 events; mismatches: 0.
