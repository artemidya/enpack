# Windows PowerShell 5.1 x64. External, local-only CorelDRAW observer.
[CmdletBinding()]
param(
    [ValidateRange(1,120)][int]$DurationMinutes = 20,
    [ValidateRange(1,30)][int]$IntervalSeconds = 2,
    [string]$Label = 'manual-test',
    [string]$OutputRoot = '',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
# PS 5.1 may evaluate parameter defaults before PSScriptRoot is populated.
# Resolve defaults AFTER binding, from this script's file, never from CMD's cwd.
$scriptFile = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($scriptFile)) { $scriptFile = $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($scriptFile)) {
    throw 'Cannot locate CorelWatch.ps1. Extract the full ZIP and run Start-CorelWatch.cmd.'
}
$ScriptDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($scriptFile))
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $ScriptDirectory 'Reports' }

if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
Add-Type -LiteralPath (Join-Path $ScriptDirectory 'NativeProbe.cs')
if ($SelfTest) {
    $self = Get-Process -Id $PID
    $probe = [CorelWatch.NativeProbe]::Sample([uint32]$self.Id, $self.MainWindowHandle.ToInt64())
    $probe | ConvertTo-Json -Depth 8
    Write-Host ('Reports root: ' + $OutputRoot)
    Write-Host 'Native probe smoke test completed. This does not test CorelDRAW.'
    exit 0
}

$sessionStart = Get-Date
$sessionName = $sessionStart.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$report = Join-Path $OutputRoot $sessionName
$report = (New-Item -ItemType Directory -Path $report -Force).FullName
$utf8 = New-Object Text.UTF8Encoding($false)
$script:Writers = @{}
$script:BytesLogged = 0L
$script:LimitReached = $false
$maxBytes = 50MB
$known = @{}
$script:SampleCount = 0
$script:NoReplyCount = 0
$script:DisabledMainCount = 0
$stopReason = 'duration_limit'

function Write-Record([string]$File, $Value) {
    if ($script:LimitReached) { return }
    $json = $Value | ConvertTo-Json -Depth 10 -Compress
    $bytes = $utf8.GetByteCount($json) + 2
    if (($script:BytesLogged + $bytes) -gt $maxBytes) {
        $script:LimitReached = $true
        return
    }
    if (-not $script:Writers.ContainsKey($File)) {
        $writer = New-Object IO.StreamWriter((Join-Path $report $File), $false, $utf8)
        $writer.AutoFlush = $true
        $script:Writers[$File] = $writer
    }
    $script:Writers[$File].WriteLine($json)
    $script:BytesLogged += $bytes
}
function Event([string]$Kind, $Details) {
    Write-Record 'events.jsonl' ([ordered]@{time=(Get-Date).ToString('o'); kind=$Kind; details=$Details})
}
$script:CaptureWorker=$null
$script:CaptureCount=0
$script:CaptureStarted=$null
$script:CaptureDirectory=$null
function Poll-Capture {
    if (-not $script:CaptureWorker) { return }
    $worker=$script:CaptureWorker
    if (-not $worker.HasExited -and $script:CaptureStarted.Elapsed.TotalSeconds -ge 20) {
        # ONLY our separately started helper; never the observed Corel process.
        try { $worker.Kill() } catch { Event 'helper_stop_error' $_.Exception.Message }
        Event 'capture_timeout' @{directory=$script:CaptureDirectory; limit_seconds=20}
        if (-not $worker.WaitForExit(1000)) {
            Event 'helper_not_stopped' 'Unable to stop our helper; monitor will not wait indefinitely. Check helper PID in events.jsonl.'
            $worker.Dispose(); $script:CaptureWorker=$null
            return
        }
    }
    if ($worker.HasExited) {
        Event 'capture_finished' @{directory=$script:CaptureDirectory; exit_code=$worker.ExitCode}
        $worker.Dispose(); $script:CaptureWorker=$null
    }
}
function Snapshot-Modules($Target, [string]$Reason) {
    Poll-Capture
    if ($script:CaptureWorker -or $script:CaptureCount -ge 8) { return $false }
    try {
        $script:CaptureCount++
        $dir=Join-Path $report ('capture-{0:D2}-pid{1}' -f $script:CaptureCount,$Target.Id)
        $null=New-Item -ItemType Directory -Path $dir
        $scriptPath=(Join-Path $ScriptDirectory 'DeepCapture.ps1').Replace("'","''")
        $escapedDir=$dir.Replace("'","''")
        $command="& '$scriptPath' -TargetProcessId $($Target.Id) -StartTicks $($Target.StartTime.Ticks) -OutputDirectory '$escapedDir'"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $script:CaptureWorker=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $dir 'helper-out.txt') -RedirectStandardError (Join-Path $dir 'helper-error.txt')
        $script:CaptureStarted=[Diagnostics.Stopwatch]::StartNew(); $script:CaptureDirectory=$dir
        Event 'capture_started' @{process_id=$Target.Id; reason=$Reason; directory=$dir; helper_pid=$script:CaptureWorker.Id}
        Write-Host ('Diagnostic snapshot: ' + $Reason)
        return $true
    } catch { Event 'capture_start_error' $_.Exception.Message; return $false }
}
function Export-WindowsEvents {
    try {
        # Read only the current session. Never change event/audit configuration.
        $records = @(Get-WinEvent -FilterHashtable @{
            LogName='Application'; StartTime=$sessionStart; Id=1000,1001,1002,1026
        } -MaxEvents 1000 -ErrorAction Stop)
        foreach ($record in $records) {
            $message = [string]$record.Message
            if ($message -match '(?i)CorelDRW|DirectEnpack') {
                Write-Record 'windows-events.jsonl' ([ordered]@{
                    time=$record.TimeCreated.ToString('o'); event_id=$record.Id
                    provider=$record.ProviderName; record_id=$record.RecordId; message=$message
                })
            }
        }
        Event 'windows_events_checked' @{queried=$records.Count; limit=1000}
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
            Event 'windows_events_checked' @{queried=0}
        } else { Event 'windows_events_unavailable' $_.Exception.Message }
    }
}

@{
    started=$sessionStart.ToString('o'); label=$Label; tool_version='2.0.1-hang-diagnostics'; monitor_process_id=$PID
    interval_seconds=$IntervalSeconds; max_minutes=$DurationMinutes; max_jsonl_bytes=$maxBytes
    os=[Environment]::OSVersion.VersionString; processor_count=[Environment]::ProcessorCount
    powershell=$PSVersionTable.PSVersion.ToString(); native_probe_timeout_ms=150; helper_timeout_seconds=20; max_snapshots=8; max_snapshot_bytes=8MB
    privacy='No keystroke hooks, window titles, screenshots, document reads, network upload or memory dumps. Module paths and Windows event messages may contain personal information.'
    limits='Sampling only; not all Corel actions/errors. NoReply can mean busy; disabled main can mean a normal modal dialog.'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'session.json') -Encoding UTF8

Write-Host 'CorelWatch 2.0.1: external CorelDRAW hang diagnostics.'
Write-Host ('Reports: ' + $report)
Write-Host 'Keep this window open; minimize it while working in CorelDRAW.'
Write-Host 'H = capture HANG now, M = marker, S = snapshot, Q = finish and create ZIP.'
Write-Host 'Keys are read ONLY while this console is focused. Nothing is uploaded.'
Write-Host 'This tool does not fix or reset CorelDRAW. Close it to stop monitoring.'
$timer = [Diagnostics.Stopwatch]::StartNew()
try {
    Event 'monitor_started' @{label=$Label}
    $stop = $false
    while (-not $stop -and $timer.Elapsed.TotalMinutes -lt $DurationMinutes -and -not $script:LimitReached) {
        Poll-Capture
        $seen = @{}
        $targets = @(Get-Process -Name CorelDRW -ErrorAction SilentlyContinue)
        foreach ($target in $targets) {
            try {
                $target.Refresh()
                $key = [string]$target.Id + ':' + $target.StartTime.Ticks
                $seen[$key] = $true
                if (-not $known.ContainsKey($key)) {
                    $known[$key] = @{no_reply_streak=0; disabled_streak=0; captured_stall=$false; process_id=$target.Id}
                    Event 'process_observed' @{process_id=$target.Id; started=$target.StartTime.ToString('o')}
                    $null=Snapshot-Modules $target 'process_observed'
                }
                $probe = [CorelWatch.NativeProbe]::Sample([uint32]$target.Id, $target.MainWindowHandle.ToInt64())
                $script:SampleCount++
                if ($probe.HasMainWindow -and -not $probe.MainReplied) {
                    $script:NoReplyCount++
                    $known[$key].no_reply_streak++
                } else {
                    $known[$key].no_reply_streak = 0
                    if ($probe.MainEnabled) { $known[$key].captured_stall = $false }
                }
                if ($probe.HasMainWindow -and -not $probe.MainEnabled) { $script:DisabledMainCount++; $known[$key].disabled_streak++ } else { $known[$key].disabled_streak=0 }
                Write-Record 'samples.jsonl' ([ordered]@{
                    time=(Get-Date).ToString('o'); process_id=$target.Id; cpu_seconds=$target.TotalProcessorTime.TotalSeconds
                    working_set_bytes=$target.WorkingSet64; private_bytes=$target.PrivateMemorySize64
                    thread_count=$target.Threads.Count; handle_count=$target.HandleCount
                    no_reply_streak=$known[$key].no_reply_streak; windows=$probe
                })
                if (($known[$key].no_reply_streak -ge 3 -or $known[$key].disabled_streak -ge 3) -and -not $known[$key].captured_stall) {
                    $reason='repeated_no_reply'; if ($known[$key].no_reply_streak -lt 3) { $reason='main_disabled_possible_modal' }
                    $known[$key].captured_stall=Snapshot-Modules $target $reason
                }
            } catch { Event 'sampling_error' @{process_id=$target.Id; error=$_.Exception.Message} }
            finally { $target.Dispose() }
        }
        foreach ($key in @($known.Keys)) {
            if (-not $seen.ContainsKey($key)) {
                Event 'process_no_longer_observed' @{process_id=$known[$key].process_id}
                $known.Remove($key)
            }
        }
        $pause = [Diagnostics.Stopwatch]::StartNew()
        while ($pause.Elapsed.TotalSeconds -lt $IntervalSeconds -and -not $stop) {
            Poll-Capture
            try {
                if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true).Key
                    if ($key -eq [ConsoleKey]::Q) { $stop = $true; $stopReason = 'user_stopped' }
                    elseif ($key -eq [ConsoleKey]::M) {
                        Event 'user_marker' 'User pressed M in monitor console'
                        Write-Host ('Marker: ' + (Get-Date).ToString('HH:mm:ss'))
                    } elseif ($key -eq [ConsoleKey]::S -or $key -eq [ConsoleKey]::H) {
                        foreach ($target in @(Get-Process -Name CorelDRW -ErrorAction SilentlyContinue)) {
                            try { $null=Snapshot-Modules $target 'manual_hang_or_snapshot' }
                            finally { $target.Dispose() }
                        }
                        Event 'manual_snapshot_requested' $null
                    }
                }
            } catch { } # Redirected/non-console runs still stop at the time/size limit.
            Start-Sleep -Milliseconds 100
        }
    }
    if ($script:LimitReached) { $stopReason = 'size_limit' }
} catch {
    $stopReason = 'monitor_error'
    Event 'monitor_error' $_.Exception.Message
} finally {
    Write-Host 'Finishing local report (pending helper: up to 20 seconds)...'
    while ($script:CaptureWorker) { Poll-Capture; if ($script:CaptureWorker) { Start-Sleep -Milliseconds 100 } }

    try {
        Export-WindowsEvents
        $pluginLog = Join-Path $env:TEMP 'DirectEnpack-27.log'
        if (Test-Path -LiteralPath $pluginLog -PathType Leaf) {
            $info = Get-Item -LiteralPath $pluginLog
            if ($info.Length -le (5 * 1024 * 1024)) {
                # Copy a bounded tail. This can include entries from earlier Corel launches.
                Get-Content -LiteralPath $pluginLog -Tail 2000 | Set-Content -LiteralPath (Join-Path $report 'DirectEnpack-27-tail.log') -Encoding UTF8
            } else { Event 'plugin_log_skipped' 'Larger than 5 MiB; not copied' }
        }
        Event 'monitor_stopped' @{reason=$stopReason}
    } catch { Write-Warning $_.Exception.Message }
    foreach ($writer in $script:Writers.Values) { $writer.Dispose() }
    @{
        stopped=(Get-Date).ToString('o'); reason=$stopReason; sample_count=$script:SampleCount
        no_reply_samples=$script:NoReplyCount; disabled_main_samples=$script:DisabledMainCount
        note='Counts are observations, not automatic error diagnoses. Absence of events does not prove absence of errors.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $report 'summary.json') -Encoding UTF8
    @'
CorelWatch 2 - observations, not an automatic root-cause verdict.
1. Repeated no reply: UI busy or blocked; examine capture-*/wait-chains.json.
2. Main disabled + a popup/off-screen window: possible modal dialog, not necessarily deadlock.
3. Main replies but UI unusable: examine child-windows.json and mark H manually.
4. modules.json: exact loaded CPG paths/hashes; addons-on-disk.json is only inventory.
5. capture_timeout: helper was stopped, NOT CorelDRAW. Earlier snapshot stages are retained.
No native stacks or memory dumps were collected. A dump may be needed for precise diagnosis.
Review paths and Windows event messages for private information before sharing this folder/ZIP.
'@ | Set-Content -LiteralPath (Join-Path $report 'READ-FIRST.txt') -Encoding UTF8
    try {
        $zip=$report+'.zip'
        Compress-Archive -LiteralPath $report -DestinationPath $zip -CompressionLevel Optimal -ErrorAction Stop
        Write-Host ('ZIP to review before sharing: ' + $zip)
    } catch { Write-Warning ('ZIP failed; report folder remains: ' + $_.Exception.Message) }
    Write-Host ('Saved: ' + $report)
    Write-Host 'Review paths/event messages before sharing. Do not upload memory dumps publicly.'
}
