param(
 [Parameter(Mandatory=$true)][string]$Godot,
 [Parameter(Mandatory=$true)][string]$Pack,
 [Parameter(Mandatory=$true)][string]$ReportDirectory
)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $Godot).Path
$packPath=(Resolve-Path -LiteralPath $Pack).Path
New-Item -ItemType Directory -Force -Path $ReportDirectory|Out-Null
$report=(Resolve-Path -LiteralPath $ReportDirectory).Path
if(Test-Path -LiteralPath (Join-Path $report 'userdata')){throw 'Use a fresh report directory so smoke phases cannot reuse an old test campaign.'}
$previous=@{}
foreach($name in 'APPDATA','LOCALAPPDATA','TEMP','TMP','OATH_TEST_ISOLATED'){$previous[$name]=[Environment]::GetEnvironmentVariable($name)}
$results=@()
try {
 $env:APPDATA=Join-Path $report 'userdata';$env:LOCALAPPDATA=$env:APPDATA
 $env:TEMP=Join-Path $report 'temp';$env:TMP=$env:TEMP;$env:OATH_TEST_ISOLATED='1'
 New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:TEMP|Out-Null
 foreach($phase in 1..4){
  $stdout=Join-Path $report "phase-$phase.stdout.log";$stderr=Join-Path $report "phase-$phase.stderr.log"
  $arguments=@('--headless','--fixed-fps','60','--main-pack',('"'+$packPath+'"'),'--script',('"'+(Join-Path $PSScriptRoot 'export_smoke_tests.gd')+'"'),'--',"$phase",('"'+$report+'"'))
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $handle=$process.Handle;$finished=$false
  while($watch.Elapsed.TotalSeconds -lt 180){if($process.WaitForExit(10000)){$finished=$true;break}}
  if(-not $finished){Stop-Process -Id $process.Id -ErrorAction SilentlyContinue}
  $process.Refresh();$watch.Stop()
  $passed=$finished -and $process.ExitCode -eq 0 -and ((Get-Content $stdout -Raw) -match "NATIVE_PHASE_$phase failures=0") -and [string]::IsNullOrWhiteSpace((Get-Content $stderr -Raw))
  $results+=[pscustomobject]@{phase=$phase;passed=$passed;exit_code=$process.ExitCode;timed_out=(-not $finished);seconds=$watch.Elapsed.TotalSeconds}
  Write-Output "Exported pack phase $phase passed=$passed"
  if(-not $passed){break}
 }
} finally {
 foreach($name in $previous.Keys){[Environment]::SetEnvironmentVariable($name,$previous[$name])}
 $results|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $report 'results.json') -Encoding UTF8
}
if($results.Count -ne 4 -or $results.passed -contains $false){exit 1}
exit 0