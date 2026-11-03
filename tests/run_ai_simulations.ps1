param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [ValidateRange(1,100000)][int]$Encounters=6,
    [ValidateRange(0,100000)][int]$StartCase=0,
    [int]$Seed=-1,
    [switch]$Repro1740,
    [ValidateRange(1,86400)][int]$TimeoutSeconds=900,
    [string]$ReportDirectory=''
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$enginePath=(Resolve-Path -LiteralPath $Godot).Path
if (-not $ReportDirectory) { $ReportDirectory=Join-Path $projectRoot 'verification\ai-simulations' }
New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null
$ReportDirectory=(Resolve-Path -LiteralPath $ReportDirectory).Path

function Invoke-BoundedGodot([string[]]$Arguments,[string]$Name) {
    $stdout=Join-Path $ReportDirectory "$Name.stdout.log"
    $stderr=Join-Path $ReportDirectory "$Name.stderr.log"
    $process=$null
    try {
        $process=Start-Process -FilePath $enginePath -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        # Keep the native handle open so Windows retains the actual exit code.
        $nativeHandle=$process.Handle
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $finished=$false
        while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            $remaining=[Math]::Max(1,[int](($TimeoutSeconds-$watch.Elapsed.TotalSeconds)*1000))
            if ($process.WaitForExit([Math]::Min(1000,$remaining))) { $finished=$true; break }
        }
        if (-not $finished) {
            Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
            $process.WaitForExit(1000) | Out-Null
            throw "$Name timed out after $TimeoutSeconds seconds: $stdout ; $stderr"
        }
        $process.WaitForExit()
        $exitCode=$process.ExitCode
        $output=Get-Content -LiteralPath $stdout -Raw
        $errors=Get-Content -LiteralPath $stderr -Raw
        if ($null -eq $exitCode -or $exitCode -ne 0 -or -not [string]::IsNullOrEmpty($errors)) {
            throw "$Name failed (exit $exitCode): $stdout ; $stderr"
        }
        return [string]$output
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

$originalEnvironment=@{}
foreach ($name in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
    $originalEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
}
try {
    $env:APPDATA=Join-Path $ReportDirectory 'runtime'
    $env:LOCALAPPDATA=$env:APPDATA
    $env:TEMP=Join-Path $ReportDirectory 'temp'
    $env:TMP=$env:TEMP
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:TEMP | Out-Null
    $importArguments=@('--headless','--editor','--import','--path',('"{0}"' -f $projectRoot))
    $importOutput=Invoke-BoundedGodot -Arguments $importArguments -Name 'import'
    if ($importOutput -match '(?m)^(SCRIPT )?ERROR:') { throw "Import failed: $ReportDirectory\import.stdout.log" }
    $testArguments=@('--headless','--fixed-fps','60','--path',('"{0}"' -f $projectRoot),'--script','res://tests/ai_simulation_tests.gd','--',"--encounters=$Encounters","--start-case=$StartCase",('"--report-root={0}"' -f $ReportDirectory))
    if ($Repro1740) { $testArguments += '--repro-1740' }
    if ($Seed -ge 0) { $testArguments += "--seed=$Seed" }
    $output=Invoke-BoundedGodot -Arguments $testArguments -Name 'ai_simulation_tests'
    if ($output -notmatch '(?m)^AI SIMULATION RESULT: 0 failures; \d+ encounters\s*$') {
        throw "AI simulation omitted an explicit zero-failure result: $ReportDirectory\ai_simulation_tests.stdout.log"
    }
    Write-Output "AI simulations passed: $ReportDirectory"
}
finally {
    foreach ($name in $originalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name,$originalEnvironment[$name],'Process')
    }
}
