param(
 [Parameter(Mandatory=$true)][string]$Godot,
 [Parameter(Mandatory=$true)][string]$ReportDirectory
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$engine=(Resolve-Path -LiteralPath $Godot).Path
New-Item -ItemType Directory -Force $ReportDirectory|Out-Null
$report=(Resolve-Path -LiteralPath $ReportDirectory).Path
if(Test-Path -LiteralPath (Join-Path $report 'simulations.json')){throw 'Choose a fresh report directory; previous failures must remain available.'}
$previous=@{}
foreach($name in 'APPDATA','LOCALAPPDATA','TEMP','TMP'){$previous[$name]=[Environment]::GetEnvironmentVariable($name)}
$results=@()
try {
 $env:TEMP=Join-Path $report 'temp';$env:TMP=$env:TEMP
 New-Item -ItemType Directory -Force $env:TEMP|Out-Null
 $env:APPDATA=Join-Path $report 'check-user';$env:LOCALAPPDATA=$env:APPDATA
 & $engine --headless --path $project --check-only --script res://dev/campaign_balance_audit.gd *> (Join-Path $report 'parse.log')
 if($LASTEXITCODE -ne 0){throw 'Campaign harness parse failed; inspect parse.log'}
 $cases=@(@{name='standard-7';difficulty='standard';seed=7;loss=$false},@{name='standard-17';difficulty='standard';seed=17;loss=$false},@{name='standard-423';difficulty='standard';seed=423;loss=$false},@{name='recovery-17';difficulty='standard';seed=17;loss=$true},@{name='easy-17';difficulty='easy';seed=17;loss=$false},@{name='hard-17';difficulty='hard';seed=17;loss=$false})
 foreach($case in $cases){
  $env:APPDATA=Join-Path $report ($case.name+'-user');$env:LOCALAPPDATA=$env:APPDATA
  $log=Join-Path $report ($case.name+'.log');$root=Join-Path $report $case.name
  $arguments=@('--headless','--fixed-fps','60','--path',$project,'--script','res://dev/campaign_balance_audit.gd','--',('--difficulty='+$case.difficulty),('--seed='+$case.seed),'--prepared',('--report-root='+$root))
  if($case.loss){$arguments+='--early-loss'}
  $watch=[Diagnostics.Stopwatch]::StartNew()
  & $engine @arguments *> $log
  $code=$LASTEXITCODE;$watch.Stop()
  $good=$code -eq 0 -and (Select-String -LiteralPath $log -Pattern 'ROSTER CAMPAIGN PLAY RESULT: 0 failures' -Quiet) -and -not (Select-String -LiteralPath $log -Pattern '^(SCRIPT )?ERROR:' -Quiet)
  $record=[ordered]@{scenario=$case.name;exit_code=$code;passed=$good;seconds=$watch.Elapsed.TotalSeconds}
  $path=Join-Path $root 'roster-campaign-play.json'
  if(Test-Path -LiteralPath $path){$data=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json;$record.ending=$data.ending;$record.missions=$data.missions.Count;$record.victories=$data.snapshot.victories;$record.threat=$data.snapshot.threat}
  $results+=[pscustomobject]$record
  Write-Output ($record|ConvertTo-Json -Compress)
  $results|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $report 'simulations.json') -Encoding utf8
 }
} finally {
 foreach($name in $previous.Keys){[Environment]::SetEnvironmentVariable($name,$previous[$name])}
}
if(@($results|Where-Object {-not $_.passed}).Count -gt 0){exit 1}
