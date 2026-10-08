# Run on Windows PowerShell 5.1; no CorelDRAW required or modified.
$ErrorActionPreference = 'Stop'
$watch = Join-Path $PSScriptRoot 'corelwatch'
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $watch 'CorelWatch.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
Add-Type -Path (Join-Path $watch 'NativeProbe.cs')
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Text = 'CorelWatch API smoke test'
$form.ShowInTaskbar = $false
try {
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $sample = [CorelWatch.NativeProbe]::Sample([uint32]$PID, $form.Handle.ToInt64())
    if (-not $sample.HasMainWindow -or -not $sample.MainEnabled -or -not $sample.MainReplied) {
        throw 'Normal window observation failed'
    }
    if (@($sample.Windows | Where-Object { $_.Handle -eq $form.Handle.ToInt64() }).Count -ne 1) {
        throw 'Test window was not enumerated'
    }
    $form.Enabled = $false
    $sample = [CorelWatch.NativeProbe]::Sample([uint32]$PID, $form.Handle.ToInt64())
    if ($sample.MainEnabled -or -not $sample.MainReplied) { throw 'Disabled != hung distinction failed' }
    $sample = [CorelWatch.NativeProbe]::Sample(0, $form.Handle.ToInt64())
    if ($sample.HasMainWindow) { throw 'Foreign-process handle accepted' }
} finally { $form.Close(); $form.Dispose() }
Write-Host 'PASS: native window enumeration, reply, disabled state, PID validation.'
$out = Join-Path $env:TEMP ('CorelWatch-Test-' + [Guid]::NewGuid().ToString('N'))
& "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $watch 'CorelWatch.ps1') -DurationMinutes 1 -IntervalSeconds 1 -Label 'CI-smoke-no-Corel' -OutputRoot $out
if ($LASTEXITCODE -ne 0) { throw 'Monitor process failed' }
$summaryFile = @(Get-ChildItem -LiteralPath $out -Recurse -Filter summary.json)
if ($summaryFile.Count -ne 1) { throw 'Expected exactly one summary' }
$summary = Get-Content -LiteralPath $summaryFile[0].FullName -Raw | ConvertFrom-Json
if ($summary.reason -ne 'duration_limit') { throw ('Unexpected stop: ' + $summary.reason) }
foreach ($file in @(Get-ChildItem -LiteralPath $out -Recurse -Filter '*.jsonl')) {
    foreach ($line in Get-Content -LiteralPath $file.FullName) { $null = $line | ConvertFrom-Json }
}
Write-Host 'PASS: one-minute idle capture, bounded stop, JSON reports.'
