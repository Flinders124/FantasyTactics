param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [int]$TimeoutSeconds = 60,
    [string]$ReportDirectory = '',
    [ValidateSet('all','fast','integration','simulation','stress')][string]$Category = 'all',
    [int]$StressEncounters = 60
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
if (-not $ReportDirectory) {
    $ReportDirectory = Join-Path $projectRoot '..\verification\stability'
}
New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null
$ReportDirectory = (Resolve-Path -LiteralPath $ReportDirectory).Path
$suites = @(
    'run_tests', 'movement_tests', 'player_input_tests', 'attack_tests',
    'targeting_tests', 'enemy_tests', 'playable_encounter_tests', 'interface_tests',
    'ranged_tests', 'ranged_enemy_tests', 'ability_tests', 'ability_enemy_tests',
    'area_tests', 'area_enemy_tests', 'area_input_tests', 'flow_tests',
    'generation_tests', 'generated_encounter_tests', 'character_tests',
    'stability_tests', 'party_encounter_tests', 'transition_stability_tests', 'navigation_lifecycle_tests', 'courtyard_tests', 'sound_tests', 'tactics_tests', 'tactics_encounter_tests', 'objective_tests', 'objective_generation_tests', 'objective_encounter_tests', 'objective_flow_tests', 'objective_tactics_tests', 'difficulty_tests', 'difficulty_generation_tests', 'difficulty_flow_tests', 'difficulty_encounter_tests', 'tutorial_tests', 'usability_tests', 'settings_tests', 'settings_lifecycle_tests', 'campaign_tests', 'campaign_flow_tests', 'campaign_play_tests', 'camp_tests', 'persistence_tests', 'save_flow_tests', 'release_export_tests'
)
$suites += 'environment_tests'
$suites += 'authored_character_tests'
$suites += 'combat_fx_tests'
$suites += @('oath_ui_tests', 'resource_lifecycle_tests', 'visual_lifecycle_tests', 'save_integrity_tests', 'turn_lifecycle_tests', 'faction_tests', 'faction_compatibility_tests', 'telegraph_tests', 'faction_spawn_tests', 'faction_encounter_tests', 'combat_stress_tests', 'session_lifecycle_tests')
$fast = @('run_tests','tactics_tests','objective_tests','difficulty_tests','campaign_tests','persistence_tests','save_integrity_tests','turn_lifecycle_tests','resource_lifecycle_tests','visual_lifecycle_tests','faction_tests')
$simulation = @('playable_encounter_tests','objective_encounter_tests','difficulty_encounter_tests','campaign_play_tests','faction_encounter_tests','combat_stress_tests')
if ($Category -eq 'fast') { $suites = $fast }
if ($Category -eq 'simulation') { $suites = $simulation }
if ($Category -eq 'integration') { $suites = @($suites | Where-Object { $_ -notin $fast -and $_ -notin $simulation }) }
if ($Category -eq 'stress') { $suites = @('combat_stress_tests', 'session_lifecycle_tests') }
# Refresh import/class metadata so a fresh checkout can run newly added tests.
$importLog = Join-Path $ReportDirectory 'import.log'
& $enginePath --headless --editor --import --path $projectRoot *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -Path $importLog -Pattern '^(SCRIPT )?ERROR:' -Quiet)) { throw "Import/type-check failed: $importLog" }
$results = @()
foreach ($suite in $suites) {
    $stdout = Join-Path $ReportDirectory "$suite.stdout.log"
    $stderr = Join-Path $ReportDirectory "$suite.stderr.log"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $testArguments = @('--headless', '--fixed-fps', '60', '--path', ('"{0}"' -f $projectRoot), '--script', "res://tests/$suite.gd", '--', ('"--report-root={0}"' -f $ReportDirectory))
    if ($Category -eq 'stress') { $testArguments += "--encounters=$StressEncounters" }
    $testProcess = Start-Process -FilePath $enginePath -ArgumentList $testArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $nativeHandle = $testProcess.Handle
    # The objective matrix bakes 90 maps plus fallback cases. Allow a bounded
    # two minutes for this batch, with short waits so cancellation stays usable.
    $limit = [Math]::Max(1, $TimeoutSeconds)
    if ($suite -in @('objective_generation_tests', 'difficulty_generation_tests')) { $limit = [Math]::Max(120, $limit) }
    if ($suite -in @('campaign_play_tests', 'save_flow_tests', 'session_lifecycle_tests')) { $limit = [Math]::Max(180, $limit) }
    if ($suite -in @('difficulty_generation_tests','faction_encounter_tests')) { $limit = [Math]::Max(180, $limit) }
    if ($Category -eq 'stress') { $limit = [Math]::Max(900,$limit) }
    $finished = $false
    while ($watch.Elapsed.TotalSeconds -lt $limit) {
        $slice = [Math]::Min(10000, [Math]::Max(1, ($limit - $watch.Elapsed.TotalSeconds) * 1000))
        if ($testProcess.WaitForExit([int]$slice)) { $finished = $true; break }
    }
    if (-not $finished) { Stop-Process -Id $testProcess.Id -ErrorAction SilentlyContinue }
    $testProcess.Refresh()
    $watch.Stop()
    $output = Get-Content -LiteralPath $stdout -Raw
    $errors = Get-Content -LiteralPath $stderr -Raw
    # Some Windows process handles do not retain ExitCode. Require the suite's
    # own final success record AND empty stderr, not just process termination.
    $passed = $finished -and $testProcess.ExitCode -eq 0 -and ($output -match 'RESULT: 0 failures') -and [string]::IsNullOrWhiteSpace($errors)
    $results += [pscustomobject]@{ suite = $suite; category = $Category; exit_code = $testProcess.ExitCode; passed = $passed; timed_out = -not $finished; seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2) }
    Write-Output ("{0}: {1} ({2}s)" -f $suite, $(if ($passed) { 'PASS' } else { 'FAIL' }), $results[-1].seconds)
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ReportDirectory 'results.json') -Encoding UTF8
if ($results.passed -contains $false) { exit 1 }
exit 0

