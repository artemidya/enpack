# Native Windows tests with synthetic windows, never real CorelDRAW.
$ErrorActionPreference='Stop'
$watch=Join-Path $PSScriptRoot 'corelwatch2'
foreach ($file in @('CorelWatch.ps1','DeepCapture.ps1')) {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $watch $file),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
Add-Type -Path (Join-Path $watch 'NativeProbe.cs')
Add-Type -Path (Join-Path $watch 'CaptureProbe.cs')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Threading;
using System.Runtime.InteropServices;
public static class WaitTest {
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 public static uint Id;
 static ManualResetEvent ready=new ManualResetEvent(false), stop=new ManualResetEvent(false);
 static Thread worker;
 public static void Start(){worker=new Thread(delegate(){Id=GetCurrentThreadId();ready.Set();stop.WaitOne();});worker.IsBackground=true;worker.Start();ready.WaitOne();}
 public static void Stop(){stop.Set();worker.Join();}
}
'@
if ([CorelWatch2.CaptureProbe]::NodeSize() -ne 280) { throw 'Invalid x64 WCT layout' }
[WaitTest]::Start()
try {
    $chain=[CorelWatch2.CaptureProbe]::WaitChain([WaitTest]::Id)
    if (-not $chain.Success) { throw ('WCT failed for test thread: '+$chain.Error) }
    $node=@($chain.Nodes | Where-Object {$_.Type -eq 'Thread' -and $_.ThreadId -eq [WaitTest]::Id})
    if ($node.Count -ne 1 -or $node[0].ProcessId -ne $PID) { throw 'WCT thread fields/layout mismatch' }
} finally { [WaitTest]::Stop() }
$form=New-Object Windows.Forms.Form
$child=New-Object Windows.Forms.Button
$form.Controls.Add($child)
try {
    $form.Show(); [Windows.Forms.Application]::DoEvents()
    $sample=[CorelWatch2.CaptureProbe]::Children([uint32]$PID,$form.Handle.ToInt64())
    if (@($sample.Windows | Where-Object {$_.Handle -eq $child.Handle.ToInt64() -and $_.Replied}).Count -ne 1) { throw 'Child probe failed' }
    if ([CorelWatch2.CaptureProbe]::Children(0,$form.Handle.ToInt64()).Windows.Count) { throw 'Foreign HWND accepted' }
} finally { $form.Close();$form.Dispose() }
$out=Join-Path $env:TEMP ('CorelWatch2-Test-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $out
# Wrong process birth-time must refuse reads (PID reuse protection).
$wrong=Join-Path $out 'wrong-identity';$null=New-Item -ItemType Directory -Path $wrong
& "$PSHOME\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $watch 'DeepCapture.ps1') -TargetProcessId $PID -StartTicks 1 -OutputDirectory $wrong
if ($LASTEXITCODE -ne 1 -or -not (Test-Path (Join-Path $wrong 'capture-error.json')) -or (Test-Path (Join-Path $wrong 'modules.json'))) { throw 'PID-reuse refusal failed' }
$fake=Join-Path $out 'CorelDRW.exe'
# Test-only synthetic process. Timer blocks its GUI for 18 seconds, then exits.
$fakeCode=@'
using System;
using System.Threading;
using System.Windows.Forms;
class FakeCorel {
 [STAThread] static void Main(){
  var form=new Form();form.Controls.Add(new Button());
  var timer=new System.Windows.Forms.Timer();timer.Interval=500;
  timer.Tick+=delegate {timer.Stop();Thread.Sleep(18000);form.Close();};
  form.Shown+=delegate {timer.Start();};Application.Run(form);
 }
}
'@
$compiler=New-Object Microsoft.CSharp.CSharpCodeProvider
$parameters=New-Object CodeDom.Compiler.CompilerParameters
$parameters.GenerateExecutable=$true; $parameters.OutputAssembly=$fake
$parameters.CompilerOptions='/platform:x64 /target:winexe'
$null=$parameters.ReferencedAssemblies.Add('System.dll')
$null=$parameters.ReferencedAssemblies.Add('System.Windows.Forms.dll')
$null=$parameters.ReferencedAssemblies.Add('System.Drawing.dll')
$result=$compiler.CompileAssemblyFromSource($parameters,$fakeCode)
$compiler.Dispose()
if ($result.Errors.HasErrors) { throw ($result.Errors | Out-String) }
# Exercise the actual timeout handler on an owned test helper, with an elapsed clock.
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $watch 'CorelWatch.ps1'),[ref]$tokens,[ref]$errors)
$functionAst=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Poll-Capture'},$true)
. ([ScriptBlock]::Create($functionAst.Extent.Text))
function Event([string]$Kind,$Details) { Write-Host ('test-event: '+$Kind) }
$script:CaptureWorker=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 60"' -WindowStyle Hidden -PassThru
$helperId=$script:CaptureWorker.Id
$script:CaptureStarted=[pscustomobject]@{Elapsed=[TimeSpan]::FromSeconds(21)}
$script:CaptureDirectory=$out
Poll-Capture
if ($script:CaptureWorker -or (Get-Process -Id $helperId -ErrorAction SilentlyContinue)) { throw 'Timeout did not stop owned helper' }

$process=Start-Process -FilePath $fake -PassThru
try {
    & "$PSHOME\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $watch 'CorelWatch.ps1') -DurationMinutes 1 -IntervalSeconds 1 -OutputRoot (Join-Path $out 'Reports') -Label 'CI-synthetic-hung-window'
    if ($LASTEXITCODE -ne 0) { throw 'Monitor failed' }
} finally { if (-not $process.HasExited) {$process.Kill()};$process.Dispose() }
$summaryFile=@(Get-ChildItem (Join-Path $out 'Reports') -Recurse -Filter summary.json)
if ($summaryFile.Count -ne 1) { throw 'Summary missing' }
$summary=Get-Content -LiteralPath $summaryFile[0].FullName -Raw | ConvertFrom-Json
if ($summary.no_reply_samples -lt 3) { throw 'Synthetic hang not detected' }
foreach ($file in @(Get-ChildItem (Join-Path $out 'Reports') -Recurse -Filter '*.jsonl')) {
    foreach ($line in Get-Content -LiteralPath $file.FullName) { $null=$line | ConvertFrom-Json }
}
foreach ($file in @(Get-ChildItem (Join-Path $out 'Reports') -Recurse -Filter '*.json')) { $null=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json }
if (@(Get-ChildItem (Join-Path $out 'Reports') -Filter '*.zip').Count -ne 1) { throw 'Report ZIP missing' }
if (@(Get-ChildItem (Join-Path $out 'Reports') -Recurse -Filter modules.json).Count -lt 1) { throw 'Module snapshot missing' }
if (@(Get-ChildItem (Join-Path $out 'Reports') -Recurse -Filter wait-chains.json).Count -lt 1) { throw 'Wait-chain snapshot missing' }
$events=Get-Content (Join-Path $summaryFile[0].DirectoryName 'events.jsonl') | ForEach-Object {$_ | ConvertFrom-Json}
if (@($events | Where-Object {$_.kind -eq 'capture_started' -and $_.details.reason -eq 'repeated_no_reply'}).Count -lt 1) { throw 'Automatic hang snapshot not requested' }
Write-Host 'PASS: PS 5.1 parsing, x64 WCT layout/real thread query, child windows, PID reuse refusal, synthetic unresponsive GUI detection, snapshots and ZIP. No real CorelDRAW tested.'
