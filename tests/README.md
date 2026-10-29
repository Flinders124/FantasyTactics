# Stability regression suite

Godot 4.7.2 standard; no additional dependencies. From the project directory:

```powershell
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category fast
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category all
./tests/run_regressions.ps1 -Godot C:/Tools/Godot_console.exe -Category stress -StressEncounters 60
```

The runner imports/type-checks first, requires exit zero, an explicit zero-failure result and empty stderr, and records logs/durations in verification/stability (override -ReportDirectory). Categories integration and simulation are available. The all category includes six quick stress scenarios; expensive stress is separate.

Tests use private save paths, never the active campaign slot. For completely isolated settings/caches, set APPDATA and LOCALAPPDATA to a disposable absolute directory. Never use player save directories. Report writers create directories and explicitly fail on write errors.

## Reproduction

```powershell
& $Godot --headless --fixed-fps 60 --path . --script res://tests/combat_stress_tests.gd -- --start-case=39 --encounters=1 --report-root=C:/Temp/oath-tests
& $Godot --headless --fixed-fps 60 --path . --script res://tests/session_lifecycle_tests.gd -- --cycles=12 --report-root=C:/Temp/oath-tests
```

Simulation uses real commands, navigation, AI and outcomes. Test movement speed/presentation are accelerated; production balance is unchanged. Reports include seed, party, roster, turns and command counts. Development-only CombatController.diagnostic_snapshot() includes pending completion, eligible actors and a bounded 24-transition history.

Historical Milestone1 failure: case39/seed1740 (Ranger/Mage versus Ashfang) was a legal-turn healing equilibrium. Milestone2 now reproduces and resolves it through relevant-status scoring, without changing stats or the watchdog. The dedicated -Repro1740 harness and original combat_stress_tests scenario both verify the correction. Keep the original failure evidence; do not weaken completion assertions.

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
## Milestone2 tactical checks

The all category includes positioning, awareness, execution, compatibility, lifetime and AI simulation suites. Use the standard Godot4.7.2 runtime for GDScript-only regression testing. Source stats/definitions are unchanged. Legacy saves/codes and nondefault profile fingerprint detection are covered.

```powershell
./tests/run_ai_simulations.ps1 -Godot $Godot -Encounters 60 -ReportDirectory ./verification/ai-long
./tests/run_ai_simulations.ps1 -Godot $Godot -Repro1740 -Encounters 1 -ReportDirectory ./verification/ai-1740
& $Godot --headless --fixed-fps 60 --path . --script res://tests/ai_simulation_tests.gd -- --metric-self-test
& $Godot --headless --fixed-fps 60 --path . --script res://tests/ai_benchmark.gd -- --report-root=C:/Temp/FantasyTactics/verification/ai-benchmark
```

The simulation runner isolates settings/saves, retains native exit codes, requires empty stderr and restores caller environment variables on success/failure. Metric fixtures cover automatic elite resolution before turn_started and End Turn synchronously advancing a single surviving hero. Completion failures are never skipped. Diagnostics and actual measured trade-offs: docs/TACTICAL_AI_MILESTONE_2.md.
## Milestone 3 mission variety

Use `-Category mission` for template/composition, real navigation, structural offer inspection, campaign mission simulations, imported-code replay, objective/campaign/persistence and compatibility checks. The ordinary inspector suite samples five complete campaign paths; `dev/mission_inspector.gd -- --campaigns=20 --seed=17 --report-root=...` produces an extended 260-offer report. This longer workload is separate from fast checks. `tests/mission_simulation_tests.gd -- --encounters=45 --report-root=...` runs real generated campaign encounters across parties/stages/difficulties. Watchdogs and command assertions are unchanged; failures are never skipped. See [the mission-variety report](../docs/MISSION_VARIETY_REPORT.md) for actual results, source authoring and renderer captures.

The twelve-cycle session lifecycle workload has a 300-second process budget after a measured 203.5-second complete run. This does not extend combat frame/turn/action watchdogs. Per-cycle diagnostics include full cycle time, creation/checkpoint cost, navigation, node/object/resource counts and static memory.

## Milestone4 roster, specialisation and rescue

`-Category roster` runs the new definition, runtime, art, UI, rescue validation, campaign, migration, full-flow and six-encounter simulation tests. `-Category fast` also includes the four fast roster rule/save suites. `-TestNames` selects named suites without silently accepting misspellings. Use isolated APPDATA/LOCALAPPDATA and a private report directory, as the existing runner instructions describe.

```powershell
./tests/run_regressions.ps1 -Godot $Godot -Category roster -TimeoutSeconds 180 -ReportDirectory ./verification/roster
./tests/run_regressions.ps1 -Godot $Godot -Category all -TimeoutSeconds 600 -ReportDirectory ./verification/all
```

The generous full-suite process budget accommodates complete map matrices; internal action, turn, generation and simulation watchdogs remain unchanged. Historical fixed-four scenarios explicitly use `LegacyCampaignFixture`. New roster tests use actual recruits and schema2 campaigns. Capture actual UI/models with `dev/roster_showcase.gd` under a renderer; it uses a private campaign slot. See `docs/ROSTER_SPECIALISATION_REPORT.md` for rules, compatibility and verified results.

## Campaign balance and recovery

`campaign_recovery_tests` is included in `-Category roster` and `all`. It checks the editable rules-v2 cap/reward policy, permanent-loss/XP semantics, reserve readiness, rest recovery, duplicate-result rejection and a captured pre-balance v2 save. Historical v1 migration stays covered by roster-save tests. New tuning does not overwrite frozen offers.

Run six deterministic campaign scenarios (3 Standard seeds, an early-loss development fixture, Easy and Hard) with isolated user folders:

```powershell
./tests/run_campaign_balance.ps1 -Godot $Godot -ReportDirectory ./verification/campaign-review
```

The harness uses real commands and legal training/rest/specialisation decisions. It records campaign victories AND defeats; `passed` means the scenario completed cleanly with zero assertions, not that the player won. A nonzero native exit remains failed even after a printed success record. Use a fresh report directory. See docs/CAMPAIGN_BALANCE_MILESTONE_1.md for results, strategy differences and manual-playtesting limits.
