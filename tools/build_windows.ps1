param([string]$Godot = "$PSScriptRoot/../../../work/godot-runtime/Godot_v4.7.2-stable_mono_win64_console.exe")
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path "$PSScriptRoot/..").Path
$workspace = (Resolve-Path "$project/../..").Path
$release = "$workspace/outputs/releases/FantasyTactics-0.12.0-rc1"
$logs = "$workspace/outputs/verification/release"
$template = "$workspace/work/export-templates/windows_release_x86_64.exe"
if (!(Test-Path -LiteralPath $template)) { throw "Missing standard Godot 4.7.2 Windows x86_64 release template: $template. See RELEASE.md." }
foreach ($notice in @('GODOT-LICENSE.txt', 'GODOT-THIRD-PARTY.txt')) {
    if (!(Test-Path -LiteralPath "$project/docs/licenses/$notice")) { throw "Missing engine notice: $notice" }
}
New-Item -ItemType Directory -Force $release,$logs | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:APPDATA = "$workspace/work/godot-appdata"
    $env:LOCALAPPDATA = "$workspace/work/godot-localappdata"
    New-Item -ItemType Directory -Force "$workspace/work/godot-temp" | Out-Null
    $env:TEMP = "$workspace/work/godot-temp"
    $env:TMP = $env:TEMP
& $Godot --headless --path $project --editor --import --log-file "$logs/import.log" *> "$logs/import-console.log"
if ($LASTEXITCODE -ne 0 -or (Select-String -Path "$logs/import-console.log" -Pattern '^(SCRIPT )?ERROR:' -Quiet)) { throw 'Godot import failed; see release logs.' }
& $Godot --headless --path $project --log-file "$logs/scope.log" --script res://tests/release_export_tests.gd *> "$logs/scope-console.log"
if ($LASTEXITCODE -ne 0) { throw 'Export scope checks failed; see release logs.' }
& $Godot --headless --path $project --log-file "$logs/export.log" --export-release 'Windows Desktop' "$release/FantasyTactics.exe" *> "$logs/export-console.log"
if ($LASTEXITCODE -ne 0 -or (Select-String -Path "$logs/export-console.log" -Pattern '^(SCRIPT )?ERROR:' -Quiet) -or !(Test-Path "$release/FantasyTactics.exe") -or !(Test-Path "$release/FantasyTactics.pck")) { throw 'Windows export failed; see release logs.' }
Copy-Item "$project/RELEASE.md" "$release/README.md"
Copy-Item "$project/docs/licenses/GODOT-LICENSE.txt" "$release/GODOT-LICENSE.txt"
Copy-Item "$project/docs/licenses/GODOT-THIRD-PARTY.txt" "$release/GODOT-THIRD-PARTY.txt"
Copy-Item "$project/assets/audio/LICENSE.txt" "$release/AUDIO-LICENSE.txt"
Copy-Item "$project/assets/characters/LICENSE.txt" "$release/CHARACTERS-LICENSE.txt"
Copy-Item "$project/assets/courtyard/LICENSE.txt" "$release/COURTYARD-LICENSE.txt"
Copy-Item "$project/assets/branding/LICENSE.txt" "$release/BRANDING-LICENSE.txt"
Get-ChildItem -LiteralPath $release -File | Where-Object Name -ne 'SHA256SUMS.txt' | Get-FileHash -Algorithm SHA256 | ForEach-Object { "$($_.Hash.ToLower())  $([IO.Path]::GetFileName($_.Path))" } | Set-Content "$release/SHA256SUMS.txt"
Write-Output "Export ready for smoke testing: $release"



} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
}


