# Mission Variety Implementation Plan

**Goal:** editable, deterministic mission variety integrated with existing campaign offers, saves, replay and tactical AI.
**Architecture:** retain CombatController and the three current objective controllers. MissionTemplate Resources describe authored constraints; MissionCatalog selects deterministic bounded compositions. Frozen offer codes remain authoritative on load. Extend existing battlefield presets with Narrow Approach and Split Courtyard; no new renderer, art library or combat mechanics.
**Tech stack:** Godot4.7.2, typed GDScript, .tres definitions, dependency-free headless tests.
**Spec:** user attachment 8df829bc-51c2-4606-8fad-35ff6799ac74/Pasted text.txt.

## Decisions and constraints
- Existing Elimination, Hold Ground and Extraction already supply three distinct goals; retain their exact rules. Protect-target/survival/reinforcements require new actors or mechanics and are outside this bounded implementation.
- Preserve all legacy preset IDs/indexes and generator2 geometry; append two presets with their own topology. Keep cosmetic RNG independent.
- Templates use existing faction roles, one healer maximum, current2–4 regular/elite+support count and difficulty budgets. Rewards reference existing campaign rules.
- New offers freeze template metadata and encounter code. Old offers without metadata remain valid and are never regenerated on load. Keep original save content hash based on the original three presets.
- Preserve M2 uncommitted work; do not commit, reset, rebalance or start M4. Prior65/68 regression failures remain evidence and cannot be reported as resolved without checks.

## Tasks
- [x] A: baseline objective/campaign/save/compatibility/AI tests before mission edits; record actual failures and runtime.
- [x] B: write failing template/offer/compatibility tests; add validated .tres templates and bounded deterministic faction compositions; connect only newly generated campaign boards.
- [x] C: write failing layout tests; append Narrow Approach and Split Courtyard, preserve existing layouts/fallbacks, update setup bounds, navigation and code validation.
- [x] D: freeze and validate optional mission metadata without changing old offer records; focused board/preparation UI and readable briefings; validate deployment, debrief, replay and duplicate results.
- [x] E: add developer mission inspector, fixed-seed structural/navigation matrix and real-command simulation coverage. Capture renderer screenshots where available; report unperformed visual/native-export checks.
- [x] F: run relevant/full regression, inspect failures, record timings/variety/reproduction examples and modified files in docs/MISSION_VARIETY_REPORT.md. Stop for review before M4.

## Review focus
Frozen old missions, malformed metadata, template edits, blocked objectives, spawn capacity, no-healer spam, separate RNG streams, campaign failure/threat timing, duplicate result processing and interrupted recovery. No test may overwrite player saves or silently skip a stalled match.

2026-10-28 resumed: real renderer captures at both target resolutions succeeded. Expanded generation suites passed150objective/preset and225difficulty/objective/preset configurations, plus allsixpairs. Finalall-suite and45freshmissions stillrunning; nofullsignoffyet. Initialfocusedbatch interrupted aftera newerrorbranchparsefailure; fixedwithreadablerejectiontest. Importedroster overwrite andcaster-in-archerslot regressions observedRED thenGREEN. Earlierinterrupted24-simulation batch retained, notcountedas45completed.

Final verification: 71/73 in the full batch; both targeted followups passed. Twelve lifecycle cycles completed in 203.51 seconds with flat nodes and bounded objects/resources; normal batch limit is now 300 seconds. Fresh 45 matches completed with no rejected commands. Both four-phase packed-resource smoke runs passed, including outside-project cwd. Full single-batch repeat after test-only corrections and native-EXE export were not performed. See docs/MISSION_VARIETY_REPORT.md. Stopped before M4 for review.
