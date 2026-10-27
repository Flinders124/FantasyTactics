# Stability regression suite

Godot 4.7.2 standard; no additional dependencies. From the project directory:

```powershell
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category fast
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category all
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category stress -StressEncounters 60
```

The runner imports/type-checks first, requires exit zero, an explicit zero-failure result and empty stderr, and records logs/durations in ../verification/stability (override -ReportDirectory). Categories integration and simulation are available. The all category includes six quick stress scenarios; expensive stress is separate.

Tests use private save paths, never the active campaign slot. For completely isolated settings/caches, set APPDATA and LOCALAPPDATA to a disposable absolute directory. Never use player save directories. Report writers create directories and explicitly fail on write errors.

## Reproduction

```powershell
& $Godot --headless --fixed-fps 60 --path . --script res://tests/combat_stress_tests.gd -- --start-case=39 --encounters=1 --report-root=C:/Temp/oath-tests
& $Godot --headless --fixed-fps 60 --path . --script res://tests/session_lifecycle_tests.gd -- --cycles=12 --report-root=C:/Temp/oath-tests
```

Simulation uses real commands, navigation, AI and outcomes. Test movement speed/presentation are accelerated; production balance is unchanged. Reports include seed, party, roster, turns and command counts. Development-only CombatController.diagnostic_snapshot() includes pending completion, eligible actors and a bounded 24-transition history.

Known failing long scenario: case39, seed1740, Ranger/Mage versus Ashfang, Easy/Open Courtyard. Ranger and healer continue legal turns without a terminal result within240turns. The harness fails instead of skipping/resetting it. This is a tactical bot stalemate, not an observed stuck action; changing tactics/balance is outside this milestone.

session_lifecycle_tests exercises real navigation, results, debrief, private saves and cleanup twelve times. Deaths are explicit outcome fixtures, not naturally played battles. combat_stress_tests provides naturally resolved battle coverage separately.

Fast tests cover rules, campaign consequences, save failures, reentrant cancellation and resource cleanup. Integration covers input/settings/pause/setup/navigation/objectives/tutorial/transitions. Simulation covers fixed-seed encounters. Stress covers longer runs and all pairs/factions/larger rosters. No CI provider was found; the runner returns nonzero on failure for later CI integration.

## Export smoke procedure

Export the existing Windows Desktop preset with the matching template. Run EXE and PCK together outside the project. Check title, tutorial entry, skirmish, campaign, equipment, deployment, completed encounter, debrief and headquarters. Close during an enemy turn; Continue must restart the same deployment. Reload at debrief and confirm rewards unchanged. Use isolated application data.

Native EXE startup and an external standard-engine --main-pack harness are distinct checks. The harness exercises the exact exported pack; the release template ignores --script. Do not call pack-harness coverage a manually completed native-EXE playthrough.
Automated exported-pack smoke (four independent processes, private data, bounded failures):

./tests/run_export_smoke.ps1 -Godot C:/Tools/Godot_console.exe -Pack C:/Build/FantasyTactics.pck -ReportDirectory C:/Temp/oath-export-fresh

Use a new report directory each run. Native executable startup is an additional separate check.

Build command (create the output directory first, install the matching Windows template):

```powershell
& $Godot --headless --path . --export-release 'Windows Desktop' C:/Temp/oath-build/FantasyTactics.exe
```

Check export logs as well as its exit code: an engine/platform file error can occur even when export returns zero. Configure a writable TEMP/TMP location in restricted environments. Do not accept a resource pack produced alongside export errors.