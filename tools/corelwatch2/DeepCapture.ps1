# Isolated helper. Parent terminates THIS helper after 20 s, never CorelDRAW.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][int]$TargetProcessId,
      [Parameter(Mandatory=$true)][long]$StartTicks,
      [Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$script:SnapshotBytes=0L
function Save($Name,$Value) {
    $json=$Value | ConvertTo-Json -Depth 12
    $bytes=[Text.Encoding]::UTF8.GetByteCount($json)+3
    $path=Join-Path $OutputDirectory $Name
    $previous=0L; if (Test-Path -LiteralPath $path) { $previous=(Get-Item -LiteralPath $path).Length }
    if (($script:SnapshotBytes-$previous+$bytes) -gt 8MB) { throw 'Snapshot size limit (8 MiB)' }
    [IO.File]::WriteAllText($path,$json,(New-Object Text.UTF8Encoding($true)))
    $script:SnapshotBytes=$script:SnapshotBytes-$previous+$bytes
}
$target=$null
try {
    $target=Get-Process -Id $TargetProcessId -ErrorAction Stop
    if ($target.StartTime.Ticks -ne $StartTicks) { throw 'PID reused; snapshot refused.' }
    Add-Type -Path (Join-Path $PSScriptRoot 'NativeProbe.cs')
    Add-Type -Path (Join-Path $PSScriptRoot 'CaptureProbe.cs')
    $exe=$null; $version=$null
    try { $exe=$target.MainModule.FileName; $version=$target.MainModule.FileVersionInfo.FileVersion } catch { }
    Save 'process.json' ([ordered]@{time=(Get-Date).ToString('o'); process_id=$target.Id; start_ticks=$StartTicks; executable=$exe; file_version=$version; cpu_seconds=$target.TotalProcessorTime.TotalSeconds; private_bytes=$target.PrivateMemorySize64})
    # Save each stage independently so a timed-out helper still leaves useful evidence.
    try {
        $modules=@($target.Modules | Select-Object -First 2048 | ForEach-Object {
            $item=[ordered]@{name=$_.ModuleName; path=$_.FileName; base_address=$_.BaseAddress.ToInt64(); size=$_.ModuleMemorySize}
            if ($_.FileName -match '(?i)\.(cpg|8bf)$') {
                try { $item.sha256=(Get-FileHash -LiteralPath $_.FileName -Algorithm SHA256).Hash } catch { $item.hash_error=$_.Exception.Message }
            }
            $item
        })
        Save 'modules.json' @{limit=2048; modules=$modules; note='Loaded does not mean responsible for the hang. Hash is of the file on disk.'}
    } catch { Save 'modules-error.json' @{error=$_.Exception.Message} }
    if ($exe) {
        $addons=Join-Path (Split-Path -Parent $exe) 'Addons'
        try {
            # Only the installed Addons tree. Never search user documents/drives.
            # Recursive enumeration is bounded by file count and the helper timeout.
            $files=@(Get-ChildItem -LiteralPath $addons -File -Recurse -ErrorAction Stop | Select-Object -First 512 | ForEach-Object {
                [ordered]@{path=$_.FullName; extension=$_.Extension; size=$_.Length; modified=$_.LastWriteTime.ToString('o')}
            })
            Save 'addons-on-disk.json' @{directory=$addons; limit=512; files=$files; note='On disk is not proof of loading. Configured 8bf folders are not searched.'}
        } catch { Save 'addons-error.json' @{directory=$addons; error=$_.Exception.Message} }
    }
    $main=$target.MainWindowHandle.ToInt64()
    $windows=[CorelWatch.NativeProbe]::Sample([uint32]$target.Id,$main)
    Save 'windows.json' $windows
    $children=[CorelWatch2.CaptureProbe]::Children([uint32]$target.Id,$main)
    Save 'child-windows.json' $children
    $threads=@($target.Threads | Select-Object -First 256 | ForEach-Object {
        $t=[ordered]@{id=$_.Id; state=[string]$_.ThreadState}
        try { $t.cpu_seconds=$_.TotalProcessorTime.TotalSeconds; if ($_.ThreadState -eq [Diagnostics.ThreadState]::Wait) { $t.wait_reason=[string]$_.WaitReason } } catch { $t.error=$_.Exception.Message }
        $t
    })
    Save 'threads.json' @{limit=256; threads=$threads}
    # UI threads first; at most 24 thread queries in a disposable process.
    $ids=@([CorelWatch2.CaptureProbe]::WindowThread($main)) + @($windows.Windows | ForEach-Object {$_.ThreadId}) + @($children.Windows | ForEach-Object {$_.ThreadId}) + @($threads | ForEach-Object {$_.id})
    $ids=@($ids | Where-Object {$_ -gt 0} | Select-Object -Unique | Select-Object -First 24)
    $chains=@()
    foreach ($threadId in $ids) {
        if ($target.HasExited -or (Get-Process -Id $TargetProcessId -ErrorAction Stop).StartTime.Ticks -ne $StartTicks) { throw 'Target exited/replaced during capture.' }
        $chains+= [CorelWatch2.CaptureProbe]::WaitChain([uint32]$threadId)
        Save 'wait-chains.json' @{limit=24; chains=$chains; note='WCT is partial, not a native stack trace. Missing chains or no cycle do not exclude a hang; no plugin is blamed automatically.'}
    }
    Save 'complete.json' @{finished=(Get-Date).ToString('o'); process_id=$TargetProcessId}
} catch {
    Save 'capture-error.json' @{time=(Get-Date).ToString('o'); error=$_.Exception.Message}
    exit 1
} finally { if ($target) {$target.Dispose()} }
