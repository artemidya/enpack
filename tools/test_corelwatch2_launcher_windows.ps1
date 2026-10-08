# Regression for the user's CMD/default-OutputRoot startup failure.
# Test the ZIP, not just the source; no real CorelDRAW is required or modified.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$out=Join-Path $env:TEMP ('CorelWatch-Launcher-'+[Guid]::NewGuid().ToString('N'))
# Unicode + spaces + apostrophe + brackets catch quoting/literal-path regressions.
$install=Join-Path $out (([string][char]0x0416)+" monitor's [folder]")
$null=New-Item -ItemType Directory -Path $install -Force
Expand-Archive -LiteralPath (Join-Path $root 'deliverables/CorelWatch-2.0.1.zip') -DestinationPath $install
foreach ($line in Get-Content -LiteralPath (Join-Path $install 'SHA256SUMS.txt')) {
    $parts=$line -split '  ',2
    if ((Get-FileHash -LiteralPath (Join-Path $install $parts[1]) -Algorithm SHA256).Hash -ne $parts[0]) { throw 'Packaged checksum mismatch' }
}
$script:testNumber=0
function Launch-Cmd([string]$Arguments) {
    $script:testNumber++
    $launcher=Join-Path $install 'Start-CorelWatch.cmd'
    $commandLine='/d /s /c ""'+$launcher+'" '+$Arguments+' <nul"'
    return Start-Process -FilePath $env:ComSpec -ArgumentList $commandLine -WorkingDirectory (Join-Path $env:SystemRoot 'System32') -PassThru -RedirectStandardOutput (Join-Path $out "stdout-$script:testNumber.txt") -RedirectStandardError (Join-Path $out "stderr-$script:testNumber.txt")
}
function Finish-Cmd($Process,[int]$ExpectedCode) {
    try {
        if (-not $Process.WaitForExit(30000)) { throw 'CMD did not finish in 30 seconds' }
        if ($Process.ExitCode -ne $ExpectedCode) {
            Get-Content -LiteralPath (Join-Path $out "stderr-$script:testNumber.txt") | Write-Host
            throw ('Unexpected launcher exit code: '+$Process.ExitCode)
        }
    } finally { if (-not $Process.HasExited) {$Process.Kill()}; $Process.Dispose() }
}
# Same default parameter binding as an ordinary double-click: no OutputRoot argument.
Finish-Cmd (Launch-Cmd '-SelfTest') 0
if ((Get-Content -LiteralPath (Join-Path $out 'stdout-1.txt') -Raw) -notmatch 'Reports root:') { throw 'SelfTest did not finish path initialization' }

# EXACT no-argument CMD startup. Stop only the test monitor after startup is verified.
# We validate the child-parent identity before doing any test-process cleanup.
$cmd=Launch-Cmd ''
$monitor=$null
try {
    $deadline=[Diagnostics.Stopwatch]::StartNew()
    $session=$null
    while ($deadline.Elapsed.TotalSeconds -lt 30) {
        $sessions=@(Get-ChildItem -LiteralPath (Join-Path $install 'Reports') -Recurse -Filter session.json -ErrorAction SilentlyContinue)
        if ($sessions.Count) {
            try { $session=Get-Content -LiteralPath $sessions[0].FullName -Raw | ConvertFrom-Json } catch { }
            if ($session) { break }
        }
        if ($cmd.HasExited) {
            Get-Content -LiteralPath (Join-Path $out 'stderr-2.txt') | Write-Host
            throw 'No-argument launcher exited before creating session.json'
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $session -or $session.tool_version -ne '2.0.1-hang-diagnostics') { throw 'Default Reports/session.json missing or wrong version' }
    $child=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int]$session.monitor_process_id)
    if (-not $child -or $child.ParentProcessId -ne $cmd.Id -or $child.Name -ne 'powershell.exe') { throw 'Test monitor is not our CMD child; refusing cleanup' }
    $monitor=Get-Process -Id $session.monitor_process_id
    if ($monitor.StartTime -lt $cmd.StartTime) { throw 'Unexpected monitor creation time' }
    $monitor.Kill();$null=$monitor.WaitForExit(5000)
    $null=$cmd.WaitForExit(5000)
} finally {
    if ($monitor) { if (-not $monitor.HasExited) {$monitor.Kill()};$monitor.Dispose() }
    if (-not $cmd.HasExited) {
        # If startup failed before session.json, stop only this CMD's PowerShell child.
        foreach ($child in @(Get-CimInstance Win32_Process -Filter ("ParentProcessId="+$cmd.Id))) {
            if ($child.Name -eq 'powershell.exe') {
                $owned=Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
                if ($owned) { try {if ($owned.StartTime -ge $cmd.StartTime) {$owned.Kill()}} finally {$owned.Dispose()} }
            }
        }
        $cmd.Kill()
    }
    $cmd.Dispose()
}

# Explicit output path must still override the default; verify through script diagnostics.
$custom=Join-Path $out 'custom-output'
Finish-Cmd (Launch-Cmd ('-SelfTest -OutputRoot "'+$custom+'"')) 0
if ((Get-Content -LiteralPath (Join-Path $out 'stdout-3.txt') -Raw) -notmatch 'custom-output') { throw 'OutputRoot override was ignored' }

# Real startup failure must propagate, and launcher must not claim a report was saved.
Move-Item -LiteralPath (Join-Path $install 'NativeProbe.cs') -Destination (Join-Path $install 'NativeProbe.cs.saved')
Finish-Cmd (Launch-Cmd '-SelfTest') 1
$text=Get-Content -LiteralPath (Join-Path $out 'stdout-4.txt') -Raw
if ($text -notmatch 'failed with exit code' -or $text -notmatch 'may NOT have been created' -or $text -match 'Reports are in the Reports folder') { throw 'Misleading launcher failure message' }
Write-Host 'PASS: extracted ZIP checksums, CMD default binding, exact no-argument launch from System32, Unicode/spaces/literal paths, explicit OutputRoot, failure exit code/message. No CorelDRAW touched.'
