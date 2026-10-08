# Windows PowerShell 5.1 x64. External, local-only CorelDRAW observer.
[CmdletBinding()]
param(
    [ValidateRange(1,120)][int]$DurationMinutes = 20,
    [ValidateRange(1,30)][int]$IntervalSeconds = 2,
    [string]$Label = 'manual-test',
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'Reports'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
Add-Type -Path (Join-Path $PSScriptRoot 'NativeProbe.cs')
if ($SelfTest) {
    $self = Get-Process -Id $PID
    $probe = [CorelWatch.NativeProbe]::Sample([uint32]$self.Id, $self.MainWindowHandle.ToInt64())
    $probe | ConvertTo-Json -Depth 8
    Write-Host 'Native probe smoke test completed. This does not test CorelDRAW.'
    exit 0
}

$sessionStart = Get-Date
$sessionName = $sessionStart.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$report = Join-Path $OutputRoot $sessionName
$null = New-Item -ItemType Directory -Path $report -Force
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
function Snapshot-Modules($Target, [string]$Reason) {
    try {
        $modules = @($Target.Modules | ForEach-Object {
            [ordered]@{name=$_.ModuleName; path=$_.FileName; base_address=$_.BaseAddress.ToInt64()}
        })
        Write-Record 'modules.jsonl' ([ordered]@{
            time=(Get-Date).ToString('o'); process_id=$Target.Id; reason=$Reason; modules=$modules
        })
    } catch {
        Event 'modules_unavailable' @{process_id=$Target.Id; error=$_.Exception.Message; reason=$Reason}
    }
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
    started=$sessionStart.ToString('o'); label=$Label; tool_version='1.0-experimental'
    interval_seconds=$IntervalSeconds; max_minutes=$DurationMinutes; max_jsonl_bytes=$maxBytes
    os=[Environment]::OSVersion.VersionString; processor_count=[Environment]::ProcessorCount
    powershell=$PSVersionTable.PSVersion.ToString(); native_probe_timeout_ms=150
    privacy='No keystroke hooks, window titles, screenshots, document reads, network upload or memory dumps. Module paths and Windows event messages may contain personal information.'
    limits='Sampling only; not all Corel actions/errors. NoReply can mean busy; disabled main can mean a normal modal dialog.'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $report 'session.json') -Encoding UTF8

Write-Host 'CorelWatch: external CorelDRAW monitor (experimental).'
Write-Host ('Reports: ' + $report)
Write-Host 'Keep this window open; minimize it while working in CorelDRAW.'
Write-Host 'M = timestamp marker, S = module snapshot, Q = stop and finish report.'
Write-Host 'Keys are read ONLY while this console is focused. Nothing is uploaded.'
Write-Host 'This tool does not fix or reset CorelDRAW. Close it to stop monitoring.'
$timer = [Diagnostics.Stopwatch]::StartNew()
try {
    Event 'monitor_started' @{label=$Label}
    $stop = $false
    while (-not $stop -and $timer.Elapsed.TotalMinutes -lt $DurationMinutes -and -not $script:LimitReached) {
        $seen = @{}
        $targets = @(Get-Process -Name CorelDRW -ErrorAction SilentlyContinue)
        foreach ($target in $targets) {
            try {
                $target.Refresh()
                $key = [string]$target.Id + ':' + $target.StartTime.Ticks
                $seen[$key] = $true
                if (-not $known.ContainsKey($key)) {
                    $known[$key] = @{no_reply_streak=0; captured_stall=$false; process_id=$target.Id}
                    Event 'process_observed' @{process_id=$target.Id; started=$target.StartTime.ToString('o')}
                    Snapshot-Modules $target 'process_observed'
                }
                $probe = [CorelWatch.NativeProbe]::Sample([uint32]$target.Id, $target.MainWindowHandle.ToInt64())
                $script:SampleCount++
                if ($probe.HasMainWindow -and -not $probe.MainReplied) {
                    $script:NoReplyCount++
                    $known[$key].no_reply_streak++
                } else {
                    $known[$key].no_reply_streak = 0
                    $known[$key].captured_stall = $false
                }
                if ($probe.HasMainWindow -and -not $probe.MainEnabled) { $script:DisabledMainCount++ }
                Write-Record 'samples.jsonl' ([ordered]@{
                    time=(Get-Date).ToString('o'); process_id=$target.Id; cpu_seconds=$target.TotalProcessorTime.TotalSeconds
                    working_set_bytes=$target.WorkingSet64; private_bytes=$target.PrivateMemorySize64
                    thread_count=$target.Threads.Count; handle_count=$target.HandleCount
                    no_reply_streak=$known[$key].no_reply_streak; windows=$probe
                })
                if ($known[$key].no_reply_streak -ge 3 -and -not $known[$key].captured_stall) {
                    $known[$key].captured_stall = $true
                    Event 'repeated_no_reply' @{process_id=$target.Id; note='Observation, not a diagnosis or proof of deadlock'}
                    Snapshot-Modules $target 'repeated_no_reply'
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
            try {
                if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true).Key
                    if ($key -eq [ConsoleKey]::Q) { $stop = $true; $stopReason = 'user_stopped' }
                    elseif ($key -eq [ConsoleKey]::M) {
                        Event 'user_marker' 'User pressed M in monitor console'
                        Write-Host ('Marker: ' + (Get-Date).ToString('HH:mm:ss'))
                    } elseif ($key -eq [ConsoleKey]::S) {
                        foreach ($target in @(Get-Process -Name CorelDRW -ErrorAction SilentlyContinue)) {
                            try { Snapshot-Modules $target 'manual_snapshot' }
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
    Write-Host 'Finishing local report...'
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
    Write-Host ('Saved: ' + $report)
    Write-Host 'Review paths/event messages before sharing. Do not upload memory dumps publicly.'
}
