# Stability milestone 1 — audit and verification

Scope: Lantern Oath, Godot4.7.2 standard Compatibility, Windows. No balance, art, gameplay, tactics or save-schema changes. Source remains in the existing FantasyTactics project. This milestone does not start smarter allies/enemy tactics.

## Baseline

An isolated pre-fix project snapshot and source hashes are retained under work/stability-baseline and baseline-manifest.json. The original50-suite runner produced32 strict clean passes and18 failures (six timed-out report writers; other failures include shutdown/material diagnostics). Baseline export succeeded. A separate previously excluded faction data suite had126 assertions based on obsolete tuning assumptions, reproduced against both versions before fixture correction. These failures were not silently discarded.

## Confirmed defects and fixes, by impact

| Priority | Defect and reproduction | Root fix / regression |
|---|---|---|
| High | Shutdown/restart from End Turn feedback/state/resource notifications could still advance the old scheduler. | Epoch/turn checks after each notification; turn_lifecycle_tests RED then GREEN,250 legal pass turns. |
| High | Prepared elite blast resolution could continue after shutdown from its resolving-state notification. | Epoch/serial check before committing damage/resources; telegraph regression RED2 failures, GREEN zero. |
| High | Movement progress listeners stopping/restarting the motor allowed the old physics continuation to run against replacement state. | Motor generation token, checked after notification; lifecycle regression. |
| High | A structurally accepted save could contain a future/duplicate processed resolution, or premature final offer; winning the latter produced an unsaveable ending. | Validate resolution coverage/uniqueness and final-offer timing before load commit; three RED rejection assertions, save_integrity_tests GREEN. Existing valid version1 saves preserved. |
| Medium | Static enemy/theme caches retained definitions and script dependency graphs at shutdown. | SceneTree-owned cache lifetime and explicit tree-exit clear.403 weak-reference/sharing checks plus clean verbose shutdown. Baseline difficulty reproduction19objects/17resources retained; fixed none. |
| Medium | Same-frame destruction of character batches with private shader surface overrides produced material-null engine errors. | Detach overrides while models/materials are valid, restore exact materials on reentry; visual_lifecycle_tests and renderer reproductions. Art/material definitions unchanged. |
| Medium | Fresh-checkout tests wrote reports into nonexistent directories, called methods on null files, and never quit. | Shared test-only checked report writer with directory creation; real failure reporting and isolated output paths. |
| Low | Faction tests had obsolete introduction/budget fixtures and one suite used a nonstandard result marker. | Fixtures now assert documented shipped values; standardized explicit success record. No roster/stat changes. |

Save-store staging was audited and failure-injected; it already preserves current or backup across the examined replacement windows, so no unnecessary rewrite was made. SceneFlow epoch retirement, navigation synchronization, bounded AI and authoritative action resolution are reused. No broad refactor was necessary.

## Regression organization

The local PowerShell runner imports/types-checks before execution, then requires zero exit, zero assertions and empty stderr. Fast/integration/simulation/stress categories keep long workloads separate. Each report/log records its exact outcome. See tests/README.md for commands; player campaign saves are never used.

Added real-rule tests cover reentrant shutdown, movement interruption, dead actors, rapid input, bounded diagnostics, shared-resource lifetime, batched visual destruction/reentry, malformed saves, future/duplicate processed IDs, independent campaign records, injected write/replacement/recovery failures and repeated lifecycle cleanup. Existing suites retain attacks, abilities, statuses/cooldowns, area/death/draw, objectives, settings/pause, tutorial, progression/equipment and navigation matrices. The command-driven seed17 Easy Knight/Ranger campaign completed five victories (rounds5,5,6,5,5) and reached campaign victory; it is an automated playthrough, not human usability evidence. The generation suite covers135 configurations across all preset/objective/difficulty combinations and all six hero pairs; separate objective/faction matrices are retained, including90objective seeds/nine fallbacks and93faction encounters/270bounded AI decisions covering15roles.

## Stress result — an outstanding failure is preserved

60 unique fixed-seed combat scenarios were exercised with real commands/navigation/AI, all six hero pairs, three factions and2–4enemies.59 reached a terminal result; one failed the bounded240-turn battle limit. Case39/seed1740: Ranger/Mage versus Ashfang, Easy/Open Courtyard, stage4. A surviving Ranger and War Shaman keep taking legal turns without ending the battle. This is a tactical bot stalemate, not a stalled single action. Its full positions, rejected commands, turn history and AI diagnostics remain in combat-stress-case39.json. The final-source reproduction also fails explicitly (two assertions in one scenario), takes29.18seconds and records246enemy commands; case39-final/combat-stress.json reproduces the same positions and turn241 after the final fixes. The explicit suffix run40–59 is recorded separately; the aggregate retains the failed case rather than treating a rerun as success. Quick six-case stress passes, including178 enemy command checks. Production movement/action timing was not changed; only test fixtures accelerate presentation/travel.

## Repeated lifecycle and resources

Twelve full campaign creation/private save/decode/HQ/settings/roster/deployment/navigation/outcome/debrief/menu cycles passed. Outcome deaths in this harness are development fixtures, not claimed as naturally played victories. WeakRefs confirm old encounters are released and retired scenes empty. Baseline and final settled nodes242 throughout; after warm-up baseline2430objects/178resources, final2431/179. The extra loaded diagnostic/report script is stable, not growth. Both runs increased static allocation by393792bytes from cycle2 to11 while object/resource counts remained flat. This observation does not establish an unbounded memory leak or prove none exists. Final elapsed142.61s versus baseline88.73s occurred under different concurrent validation load; these are workload observations, not a valid speed comparison. Private encode/decode measurements likewise are not disk latency benchmarks.

## Rendering measurements and limits

1920x1080, Standard, Compatibility/OpenGL3.3, VSync off,60warmup/240sample frames per screen. NVIDIA RTX500Ada laptop GPU, driver596.71. Baseline/fixed median wall frame milliseconds: title1.287/1.278; party1.322/1.293; HQ2.933/3.883; roster2.155/2.585; returned camp3.110/4.621. Raw exact values are in frame-comparison.json (consult it over rounded prose). Draw calls unchanged56/66/710/118/710. Background regression workloads overlapped samples; timings are not controlled enough to attribute differences to code or claim an optimization. No universal FPS claim, GPU-complete frame-time claim or unsupported performance target is made. Lifecycle fixes eliminate demonstrated retained shutdown resources; no speculative rendering optimization was added.

## Export checks

The existing Windows Desktop release preset/template is used. Initial attempt logged an inaccessible sandbox TEMP safe-save error despite exit0; it is rejected as verification. Re-export with a writable isolated TEMP completed cleanly. Native EXE startup executed outside the project, headless and rendered, exit0. Four independent standard-engine processes loaded the exact exported PCK: tutorial/skirmish entry, campaign/purchase/equip/settings; persisted HQ load and interruption during enemy turn; same deployment/layout/roster/config restoration and a legal-command VICTORY in5rounds; debrief reload with no reward/stat mutation. Each phase zero failures. Pack harness coverage is not described as a manually completed native-EXE playthrough.

## Remaining issues / unverified work

1. Long simulation tactical stalemate above remains reproducible; the stress category intentionally fails on it. No confirmed frozen action was found in the tested runs. Address tactics in a separately reviewed milestone, without disguising it as a stability timeout.
2. Physical power-loss/storage durability and full-disk hardware behavior are not established; staged failure injection and corruption/recovery tests passed.
3. Human interaction walkthrough, long-duration native-EXE campaign play, manual keyboard/accessibility/display review and new-player usability were not performed for this milestone. Existing automated interaction/settings tests are narrower evidence.
4. Resource counts cover twelve cycles and shutdown, not unlimited play. Render measurements require quiet-machine repetition before comparative optimization decisions.

Manual follow-up: use an isolated user-data profile; finish tutorial; play campaign/skirmish; pause during movement/enemy action/area effects; reopen settings and rebind/cancel; inspect720p/1080p; close/relaunch during enemy turn; Continue original deployment; finish/debrief/reload; repeat ten menu/encounter cycles. Keep EXE and PCK together.

Final verification:62/62 routine suites passed after the last production fix, including import/type-check and strict empty-stderr gates. The separate numeric balance consistency check also passed; no tuning was changed. Final exported-pack smoke4/4 and native headless/rendered startups passed. Full machine-readable status is in verification-summary.json; build hashes are in build-hashes.json. The long-stress category is NOT fully passing:59/60 terminal outcomes and one preserved tactical stalemate. Therefore the milestone has implemented fixes and regression protection, but its full no-failing-stress definition of done is not claimed. Modified files are listed in modified-files.json. No Milestone2 work is authorized by this report.