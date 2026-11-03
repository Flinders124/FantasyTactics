# Milestone 2 — Smarter Allies and Enemy Tactics

Project: C:/Temp/FantasyTactics. Godot4.7.2, typed GDScript, Compatibility renderer. This implementation extends the existing planner; it adds no abilities, stats, action allowances, faction definitions, objectives or player automation controls. Normal heroes remain player controlled. The shared planner supports either faction in development simulations because no allied-autoplay gameplay system exists.

## Audit and before/after behavior

The game already had four hero roles, three factions with15enemy types/elites, bounded utility planning, command-driven movement/actions, Mend/Slowed/Fireburst, committed elite warnings, Elimination/Hold/Extraction, campaign persistence and lifecycle tests.

Confirmed weaknesses:
- Full Slowed utility was awarded to stationary ranged targets. Exact case39/seed1740 produced a Ranger/Shaman healing equilibrium, reaching turn241/round115 without an outcome. Both actors continued legal turns; this was not a frozen action. The corrected decision reaches VICTORY at turn33, without raising the240-turn watchdog or changing damage/healing.
- Slowed also received full value against melee already beside a different ally. A new test reproduced Crippling Shot beating a useful basic shot. The correction checks legal attacks against every ally, rather than distance only to the shooter.
- Healing danger used the single strongest attacker instead of combined observable threats.
- Only friendly elite warnings affected path selection. Opposing committed blasts could be ignored.
- Full-route body collision checks discarded safe movement when the blocking body was beyond this turn's reachable prefix.
- Healing candidate generation repeated inside the opponent loop; roles without explicit resources made Cleric act as melee and Mage as ordinary ranged in simulations.
- Planning could advance under guidance pause, and there was no small cross-turn memory for repeated blocked endpoints/revisits.

## Decisions and fairness

EnemyTactics remains read-only. AITacticalContext contains decision-local estimates and caches; every physics/action check uses the planner's existing query budget. EnemyController schedules and cancels work. CombatController remains the sole authority for legality, resource spending and effects. All actions still use MoveCommand, AttackCommand, UseAbilityCommand and EndTurnCommand.

No hidden state, future commands, random tactical rolls, extra actions, ignored collision, line-of-sight exceptions or bonus stats were introduced. There is no cover or reaction mechanic to exploit. Ground abilities retain the current no-friendly-fire AI policy and revalidation at commitment.

Role behavior:
- Frontline units value screening threatened ranged allies while retaining existing aggression/defence profiles.
- Ranged units retain useful clear shots, seek distance where worthwhile and avoid needless movement.
- Support units consider effective healing, critical health, combined legal incoming damage and access to meaningful patients. Full-health/dead/hostile patients remain illegal through shared validation.
- Spellcasters retain safe multi-target area utility. Slowed is valuable when it can deny useful movement, rather than automatically preferred to damage.
- Hold values retaining the last useful occupant/contester, with urgency from current progress. Extraction allies value the exit; enemies also value observable interception positions. Objective rules are unchanged.

Warnings use only public pending telegraphs: actual faction masks, ground anchors, blast radius/tolerance, targeting markers, static obstruction masks and the existing clear-line helper. Overlapping damage is combined. A planned defeat removes that caster's warning from the hypothetical position score. When every reachable position is dangerous, select a lower-risk legal position or act/end safely; no fake immunity or teleport is used.

## Editable utility tuning

Existing damage10/HP, defeat45, healing6/effectiveHP, minimum meaningful healing3, critical ratio50%, critical bonus24(default support36), threatened-healing36, useful-status25, multi-target6(default caster8), cooldown1.25/turn and movement0.35/metre remain. All values live in EnemyTacticalProfile; these are decision weights, not combat stats.

New defaults:

| Weight | Value | Meaning |
|---|---:|---|
| warning_damage_weight |12| Cost per predicted committed-blast HP |
| protection_weight |3| Modest frontline screening benefit |
| focus_fire_weight |1| Existing missing health as a focus hint |
| target_threat_weight |0.5| Current legal basic-threat value |
| support_access_weight |3| Access to meaningful wounded allies |
| objective_commitment_weight |12| Last useful Hold occupant/contester |
| oscillation_penalty |3| Soft cost for returning to a recent position |

Slowed movement relevance: stationary ranged with a legal shot0; engaged melee0.15; melee needing approach1; ranged without a shot0.5; objective/warning movement can raise relevance to0.75. Existing remaining-status-duration utility still applies. Incoming danger sums at most one strongest currently legal basic/ready targeted attack per opponent. It is a public-state heuristic, not a prediction of future movement or a guarantee about the next turn.

## Bounds, memory and diagnostics

Default candidate24/raw48/path48/action768 limits are preserved; hard clamps40/80/96/1600 apply. Existing difficulty overrides remain. Context checks share the action-query budget. Two endpoints per frame remain the default. At most eight local warning-escape samples and four nearby-body detours are added inside the existing raw-candidate cap. Actual path cost and approved movement prefixes are revalidated, including living-body clearance. Pursuit progress measures reduced remaining navigation cost to the same goal, not distance spent wandering.

Each enemy remembers only three turn-start positions and three failed endpoints. Failure memory expires after actor movement over0.5metres, changed living-unit occupancy or navigation-map iteration. Reset/end clear it. It does not persist in campaign saves. The revisit penalty is soft, so legitimate returns to objectives/safety remain possible. There is still at most one move and one action per enemy turn, one bounded stale-plan recovery, and authoritative completion-driven execution.

Set EnemyController.diagnostics_enabled in a development scene/Inspector to print AI_DECISION JSON. Normal play leaves it disabled. last_diagnostics and eight-entry decision_history provide actor/role/health/position/seed/turn, chosen plan, score components, query counts, rejection reasons and bounded alternatives. Wall-clock timings are diagnostic and are not deterministic; tactical choices are.

## Prerequisite and test infrastructure fixes

A committed UTF8 BOM made dev/combat/showcase.tscn fail fresh Godot import at line1. Only the BOM was removed; content/visuals are unchanged. The initial failure is retained in verification/ai-m2/baseline-clean/import.log. Baseline AI tests use an isolated Git archive with this prerequisite normalized, leaving the original ZIP unchanged.

After relocation, default regression output pointed outside the repository. It now uses ignored verification/stability. Export filters exclude verification/* and build/* so local runtimes, baseline copies and test outputs cannot enter a resource pack. The export-scope regression failed before and passed after this change. Heavy campaign/FX suites get measured180second process limits; combat frame/turn watchdogs were not raised. The baseline full run recorded three60second process timeouts under concurrent workloads; individual reruns passed, and those failures remain recorded.

Two legacy tactical fixtures were made genuinely comparable without weakening assertions: the action-first test temporarily places Crippling Shot on cooldown to isolate the basic-shot ordering tie; the symmetric target-ID test uses equal target attack/health profiles because distinct role threats intentionally no longer have equal utility.

## Verification

Final machine-readable results are under ignored verification/ai-m2. See the final verification summary for exact suite counts, durations, simulation metrics and supported export checks. Passing scenario tests cover healing, relevant Slowed, prefix blockers, role mapping, warning masks/geometry/overlap/no escape, objective commitment, frontline screening, query caps, memory, duplicate turn starts, pause, death, restart and stale completions.

Final standard-runtime simulation batch: **60/60 encounters completed**, 1,254 completed turns, 3,053 commands, **zero rejected commands**, and 1,781 bounded decisions. Outcomes were 24 hero victories and 36 defeats. Recorded effective healing was 634, overhealing 26, telegraph damage 15, pass turns 26 and movement revisits six. Warning damage is not automatically classified as avoidable; focused fixtures separately check escape, overlapping warnings and unavoidable-risk fallbacks. Six repeated fixed seeds matched outcomes, rounds, commands, damage, healing and movement metrics. This sample spans all six hero pairs and the existing factions, elites, objectives, presets and difficulties; it is not an exhaustive Cartesian match matrix or a balance assessment.

The exact pre-existing seed1740 healing stalemate exceeded the original 240-turn watchdog (turn241, round115). With the improved planner it reaches victory on turn33 without changing stats or raising that watchdog. The corrected six-case baseline comparison recorded warning damage11→0, revisits2→0 and passes5→2; these small samples are diagnostic observations, not proof of player-facing balance.

## Commands

From the repository root, substitute the installed Godot4.7.2 console executable for $Godot:

```powershell
./tests/run_regressions.ps1 -Godot $Godot -TimeoutSeconds 120 -Category all
./tests/run_ai_simulations.ps1 -Godot $Godot -Encounters 60 -ReportDirectory ./verification/ai-long
./tests/run_ai_simulations.ps1 -Godot $Godot -Repro1740 -Encounters 1 -ReportDirectory ./verification/ai-1740
& $Godot --headless --fixed-fps 60 --path . --script res://tests/ai_awareness_tests.gd
& $Godot --headless --fixed-fps 60 --path . --script res://tests/ai_benchmark.gd -- --report-root=C:/Temp/FantasyTactics/verification/ai-benchmark
```

Tests use private save/settings data. Production heroes are not auto-played. The simulation harness may accelerate presentation/movement in fixtures only. Test failures are preserved and return nonzero; stalled cases are never silently skipped/restarted.

## Limits and review

This is a bounded heuristic planner, not perfect strategy. It does not plan multiple future turns, infer hidden choices, use cover, reserve future actions or globally coordinate a squad. Danger uses current legal attacks; support access is local. Some movement revisits can be legitimate. Roster/difficulty balance was not tuned, and human playtesting remains required. Existing profile limits can miss good positions on crowded maps.

Old Windows export tooling expects an external standard4.7.2 release template no longer present after relocation. Resource-pack export/smoke testing can run without it; a newly exported native EXE must not be claimed until the template is supplied and that EXE is executed. No Milestone3 work is included.
## Final lifecycle / compatibility findings

The proposed query-callback ownership cycle was investigated with disposable planner WeakRefs and disproved: the original callback already permits planner release. No speculative weak-callback workaround remains. The new lifetime test protects this boundary.

Adding default AI exports initially changed generic definition fingerprints, which broke the shipped v1 campaign fixture. Existing default-metadata compatibility handling now also omits the seven new tactical fields only when they equal defaults. Nondefault tuning still changes fingerprints. RED8 rejection assertions became GREEN; the original faction-compatibility fixture was not altered. Saves and encounter-code versions remain unchanged.

Some headless imports terminated with Windows access violations while using the copied editor cache. A fresh source copy imported successfully; backing up the working copy's generated .godot/editor state and rebuilding it also restored clean imports. The backup is retained under ignored verification/ai-m2/editor-cache-before-native. Preliminary .NET runs also recorded two zero-assertion shutdown access violations; they remain failed evidence, not counted as passes. Final validation uses the matching official standard runtime, whose archive SHA256 was checked against the official release asset digest. One preliminary standard-runtime objective suite also terminated with an access violation after reporting zero assertions; three isolated repeats exited cleanly. These native faults are unresolved evidence, not passing tests or a proven cache-only defect.

Quiet CPU benchmark: Windows, Intel Core Ultra7 165H,22logical processors, standard Godot4.7.2 headless,10warmup/50samples per fixture. Original AI medians10.185ms clear-shot and13.536ms injured support. New unoptimized medians8.084/37.445ms; after decision-local coordinate-key caching and redundant-lookup removal7.193/22.445ms. Optimized p95chunk times2.882/5.532ms; maximum chunks2.997/8.136ms. Query counts and selected plans are unchanged by this optimization. Support evaluates more information than the original planner and remains more expensive overall; camera responsiveness is aided by bounded per-frame chunks. These two CPU fixtures do not establish a universal FPS target or all-map performance guarantee.

Test fixture clarification: ranged_enemy_tests now gives the two symmetric targets equal attack and health definitions while checking the same stable-ID assertions; role-aware threat values intentionally make a Knight and Ranger unequal choices. Simulation command metrics capture the turn serial before synchronous submission, and attribute automatic elite blasts to the actual owner before turn_started. The duplicate-command and zero-failure assertions were retained and tested RED→GREEN.
## Final handoff status

The final serialized all-suite run completed **65/68 strict passes**. Failures are retained in `verification/ai-m2/serial-regressions/results.json`:

- `save_flow_tests`: exceeded 180seconds before a result. A separately instrumented 60second diagnostic progressed through interrupted-mission recovery and into menu checks; it also exceeded its bound. No assertion was suppressed and this is not counted as a pass.
- `combat_stress_tests`: all six encounters reported zero assertions (188 enemy commands), followed by native Windows access violation `0xC0000005`. This process is a failure despite its printed result.
- `session_lifecycle_tests`: exceeded 180seconds during repeated cycles. An earlier completed standard-runtime sample exercised twelve cycles with flat title node counts, but does not erase this timeout or establish absence of leaks.

All new positioning, awareness, execution, compatibility, lifetime and default simulation suites passed in that final run. The separate 60-encounter batch and deterministic six-case replay passed with clean exits. Four external-engine `--main-pack` smoke phases passed against the newly exported resource pack, including interrupted mission recovery and duplicate-reward protection. This is **not** verification of a newly exported standalone EXE. The matching Windows release template is unavailable, and no new human visual/gameplay checks were performed.

The complete regression suite is therefore **not green**, and full stability/release signoff is withheld. Native engine shutdown faults and intermittent long-running persistence/lifecycle checks require further investigation in an unrestricted development runtime with native crash diagnostics. No speculative engine workaround, larger combat watchdog, combat rebalance or hidden automatic retry was introduced. Original failing evidence is preserved.

Important source changes: `enemy_tactics.gd`, `ai_tactical_context.gd`, `enemy_controller.gd`, `enemy_tactical_profile.gd`, default-field compatibility in `encounter_code.gd`, the showcase BOM prerequisite and export exclusions. New tests cover positioning, awareness, cancellation/memory, compatibility, lifetime, simulations and CPU benchmarking; the local runners and test documentation describe exact commands. Definition assets and combat balance are unchanged. Work is stopped for review before Milestone3.

The final isolated original-source save-flow comparison exited0 with zero failures and empty stderr. The initial baseline full batch also had process-timeout variability. This does not establish the cause of the current-source timeout; it remains an open regression risk rather than being dismissed as a confirmed pre-existing defect. The earlier completed twelve-cycle sample held242nodes throughout,179–180resources, and static memory57,480,591→57,939,491bytes (about0.44MiB growth); that finite observation is not evidence of unbounded leakage or proof of its absence.
