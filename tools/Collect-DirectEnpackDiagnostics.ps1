# Windows PowerShell 5.1. Read-only inspection; writes only the requested report.
[CmdletBinding()]
param(
    [string]$CorelRoot = 'C:\Program Files\Corel\CorelDRAW Graphics Suite\27',
    [string]$ReportPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'DirectEnpack-diagnostics.txt')
)

$ErrorActionPreference = 'Stop'
$lines = New-Object 'System.Collections.Generic.List[string]'
function Log([string]$Text) {
    $lines.Add($Text)
    Write-Host $Text
}
function Get-PeMachine([string]$Path) {
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        $reader = New-Object IO.BinaryReader($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { return 'Not a PE file (missing MZ)' }
        $stream.Position = 0x3C
        $offset = $reader.ReadInt32()
        if ($offset -lt 0 -or $offset -gt ($stream.Length - 6)) { return 'Invalid PE offset' }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { return 'Invalid PE signature' }
        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0x8664 { return 'x64 / AMD64' }
            0x014C { return 'x86 / 32-bit (not suitable for a 64-bit host)' }
            default { return ('Other machine: 0x{0:X4}' -f $machine) }
        }
    } catch { return ('Unable to inspect PE: ' + $_.Exception.Message) }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}

Log 'DirectEnpack diagnostics - no settings or plugin files are modified'
Log ('Collected: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Log ('64-bit OS: ' + [Environment]::Is64BitOperatingSystem)
Log ('64-bit PowerShell: ' + [Environment]::Is64BitProcess)
Log ('Corel root: ' + $CorelRoot)
if (-not (Test-Path -LiteralPath $CorelRoot -PathType Container)) {
    Log 'WARNING: Corel root not found; use -CorelRoot with the actual installation directory.'
} else {
    $scanErrors = @()
    $files = @(Get-ChildItem -LiteralPath $CorelRoot -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable +scanErrors)
    Log ''
    Log '--- CorelDRW.exe ---'
    foreach ($exe in @($files | Where-Object { $_.Name -ieq 'CorelDRW.exe' })) {
        Log ($exe.FullName + ' | FileVersion=' + $exe.VersionInfo.FileVersion + ' | ' + (Get-PeMachine $exe.FullName))
    }
    Log ''
    Log '--- DirectEnpack files (including accidentally renamed extensions) ---'
    $plugins = @($files | Where-Object { $_.Name -like '*DirectEnpack*' })
    if ($plugins.Count -eq 0) { Log 'No DirectEnpack files found under Corel root.' }
    foreach ($plugin in $plugins) {
        Log ($plugin.FullName + ' | Bytes=' + $plugin.Length)
        Log ('  ' + (Get-PeMachine $plugin.FullName))
        try { Log ('  SHA256=' + (Get-FileHash -LiteralPath $plugin.FullName -Algorithm SHA256).Hash) }
        catch { Log ('  Hash unavailable: ' + $_.Exception.Message) }
        $zone = @(Get-Content -LiteralPath $plugin.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue)
        if ($zone.Count -gt 0) {
            # Do not include download URLs, which may contain private information.
            Log ('  Download mark: ' + (($zone | Where-Object { $_ -match '^ZoneId=' }) -join ', '))
            Log '  A download mark alone does not prove that Corel blocked the plugin.'
        } else { Log '  No readable Zone.Identifier stream.' }
    }
    Log ''
    Log '--- Type libraries / SDK headers (paths only, not uploaded) ---'
    $types = @($files | Where-Object {
        $_.Extension -ieq '.tlb' -or $_.Name -match '^(VGCore|VGAppPlugin).*\.(h|hpp|idl)$'
    })
    if ($types.Count -eq 0) { Log 'No matching files found.' }
    foreach ($type in $types) { Log $type.FullName }
    if ($scanErrors.Count -gt 0) {
        Log ('WARNING: some paths could not be scanned; error count=' + $scanErrors.Count)
    }
}

Log ''
Log '--- Running CorelDRAW processes and loaded DirectEnpack modules ---'
$processes = @(Get-Process -Name CorelDRW -ErrorAction SilentlyContinue)
if ($processes.Count -eq 0) { Log 'CorelDRAW is not running. Open it and run this script again to check loaded modules.' }
foreach ($process in $processes) {
    Log ('CorelDRW PID=' + $process.Id)
    try {
        $modules = @($process.Modules | Where-Object { $_.ModuleName -like '*DirectEnpack*' })
        if ($modules.Count -eq 0) {
            Log '  No DirectEnpack-named module visible at this moment. This does not identify the cause.'
        }
        foreach ($module in $modules) { Log ('  LOADED: ' + $module.FileName) }
    } catch {
        Log ('  Unable to enumerate modules: ' + $_.Exception.Message)
        Log '  Use 64-bit PowerShell with the same elevation level as CorelDRAW.'
    }
}
Log ''
Log 'Review this report before sharing it. It contains local file paths, not document contents.'
try {
    $lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host ('Report saved to: ' + $ReportPath)
} catch {
    Write-Error ('Unable to save report. Use -ReportPath with a writable location. ' + $_.Exception.Message)
    exit 1
}
