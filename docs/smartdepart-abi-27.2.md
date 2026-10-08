# SmartDepart / VGCore 27.2 x64 — vtable slots

TLB SHA256: `7044b6074dfa445f39f6238062ae40e96e01c7764dc28d215872abacce3bdd7c`

Only slot positions checked; not full signatures, geometry or runtime compatibility. ICUIApplication IID bytes match: `0a00ee9ca042805943a37aa71461482c`.

| Interface | Method | Source | TLB | Result |
|---|---|---:|---:|---|
| ICUIApplication | RegisterDataSource | 8 | 8 | PASS |
| ICUIApplication | UnregisterDataSource | 9 | 9 | PASS |
| IVGApplication | CreateCurve | 86 | 86 | PASS |
| IVGApplication | Get_ActiveDocument | 12 | 12 | PASS |
| IVGApplication | Get_ActiveLayer | 44 | 44 | PASS |
| IVGApplication | Get_VersionMajor | 38 | 38 | PASS |
| IVGApplication | Get_VersionMinor | 39 | 39 | PASS |
| IVGApplication | Refresh | 77 | 77 | PASS |
| IVGApplication | Set_Optimization | 53 | 53 | PASS |
| IVGCurve | AutoReduceNodes | 45 | 45 | PASS |
| IVGCurve | GetCurveInfo | 22 | 22 | PASS |
| IVGCurve | Get_SubPaths | 8 | 8 | PASS |
| IVGCurve | PutCurveInfo | 23 | 23 | PASS |
| IVGDocument | BeginCommandGroup | 42 | 42 | PASS |
| IVGDocument | EndCommandGroup | 43 | 43 | PASS |
| IVGDocument | Get_SelectionRange | 51 | 51 | PASS |
| IVGDocument | Get_StyleSheet | 159 | 159 | PASS |
| IVGDocument | Set_Unit | 27 | 27 | PASS |
| IVGLayer | CreateCurve | 39 | 39 | PASS |
| IVGShape | Delete | 31 | 31 | PASS |
| IVGShape | Get_Curve | 25 | 25 | PASS |
| IVGShape | Get_Style | 221 | 221 | PASS |
| IVGShapeRange | Combine | 59 | 59 | PASS |
| IVGStyle | Assign | 33 | 33 | PASS |
| IVGStyle | GetCopy | 34 | 34 | PASS |
| IVGStyleSheet | Get_ObjectDefaults | 9 | 9 | PASS |
| IVGStyles | Find | 10 | 10 | PASS |
| IVGSubPaths | Get_Count | 11 | 11 | PASS |

28 methods, 0 mismatches.
