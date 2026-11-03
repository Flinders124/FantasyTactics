# Milestone 2 — Tactical situations, optional goals and courtyard architecture

## Implemented scope

Movement now previews the full navigable route in two parts: green is the executable portion, red is beyond the remaining allowance. A green STOP ring labels the actual endpoint; a red cross marks the requested distant point. Clicking beyond range submits one budget-limited player move. It never queues future-turn movement. Basic strict MoveCommand validation remains available to AI and existing callers.

The shared plan rejects non-active/dead/enemy actors, invalid/unreachable full routes and zero remaining movement. It rechecks affordable endpoints and actual queried path costs, stepping back at most20 candidates in0.15m increments when the boundary is occupied. Submission recalculates the same plan before and after entering resolution. MovementMotor retains collision-aware physics, actual-distance spending and bounded blockage recovery. Existing0.002m numerical tolerance remains; arrival tolerance0.005m can stop a few millimetres short. A0.0001m planning margin avoids floating-point overspending. Living units can still dynamically block travel; static navigation does not pretend to predict their movement.

## Courtyard kit and composition

Original editable source: `scripts/courtyard_architecture.gd`, reusing the project's Lantern Oath materials and bevel/wedge mesh helpers. No third-party art or new external dependency was introduced.

- Arches: actual wedge-stone curved arch and solid piers. Travel runs along X; clear inner width approximately2.6m, central clear height approximately2.9m. Each visible solid part provides matching collision. No invisible full doorway blocker.
- Houses: roofless ruined dwellings with a2m east-facing doorway, rear/side walls and a lintel. Simple single-room interiors; no roof or separate interior system.
- Fountains: polygonal stone basin, opaque stylised water surface, central column and cap. The water is presentation, not a terrain mechanic.
- Carts: wooden bed, side boards, wheels and cargo. Solid parts block as shown.
- Altars: broad base, stone plinth/table and sacred accent.

Generation3 composes these props around clear central routes with small seeded variation; Ruined Lanes adds a dwelling and Central Plaza substitutes a monument. Spawn zones and primary objective zones are reserved first. Architecture uses explicit authored kit footprints/heights (rather than the legacy random-box size/count fields); the existing clearance, arena, retry and objective constraints still apply. Existing decorative streams remain separate. Blocking parts are installed before baking. Small existing dressing is non-blocking. Occlusion bounds hook into the existing reversible camera-fading system.

The initial compositions remain deliberately compact and share kit pieces. Additional house variants/roofs/window dressing and larger sets of authored layout variants are future art/content work. This milestone does not introduce elevation, cover bonuses or destructible props.

## Optional goals

One goal is frozen in each newly created setup using a separate seeded stream. Goals never replace the main objective or cause a failure penalty.

| Goal | Condition | Campaign bonus |
|---|---|---:|
| Recover the Cache | A living hero reaches the blue1.2m circle at a completed-action boundary, then the mission is won |8 Supplies|
| Swift Victory | Main objective won during or at the end of round4 |6 Supplies|
| Stand Together | Win without any deployed hero being downed or defeated, even if subsequently healed |6 Supplies|

Definitions are editable in `definitions/optional/`. Mutable progress stays in OptionalGoalController. Cache inclusion uses full3D ground-anchor distance with0.000001m boundary tolerance and a bounded deterministic search over reachable points. Collection uses the same atomic-action boundary as primary outcome checks, after all damage/deaths. Swift Victory uses the actual ending round, not elapsed time. Stand Together records authoritative downed/death events. Failure, draw and abandonment award no optional Supplies.

Briefing, setup/mission descriptions, HUD, cache world marker, combat log and result/debrief show the goal. Skirmishes show challenge completion; only campaigns grant currency. Bonus rewards are validated against the frozen definition/code, added alongside existing mission rewards and guarded by the existing processed mission ID. There is no new currency, XP bonus, NPC rescue command, enemy-escape script or primary objective.

## Compatibility and lifecycle

- Generation2 remains intact for saved codes/layouts. New party setups and newly generated campaign offers use generation3; old frozen offers gain no surprise goals.
- Encounter code5 freezes the stable optional ID/definition hash, generator settings and party flags; versions1–4 remain readable.
- Campaign save5 migrates actual older schemas, including version4 fixtures captured before this change. Mission result3 adds the optional report; existing results1/2 remain supported.
- Loading remains transactional. Interrupted missions restore their original frozen setup with fresh goal progress. Normal restart resets progress and keeps one marker/controller. Ending/leaving frees scene-owned markers and restores faded materials.
- Settings, tutorial encounters, previous shop/equipment work and combat rules remain in place.

## Verification

Logs and isolated user data: `verification/tactical-situations/`. No player save was accessed.

Baseline6/6 selected existing suites passed. Focused movement/architecture/optional/campaign/persistence checks passed.90 live new-generation maps passed across three presets × three objectives × ten seeds, with2/3/4-hero parties. Three command-driven new-layout encounters completed without stalled turns (automated defeats at rounds18/12/11); these runs demonstrate progression and reset, not player-facing balance. Native initial review captured14 actual-renderer images at1280×720 and1920×1080 from multiple angles.

The visual check reproduced movement feedback falling below the HUD; a focused failing test was added and compact feedback then passed. Skirmish reward wording was also tested as a failing case and corrected. An early test targeted an obstacle edge rather than clear ground; its failed run was retained and the fixture corrected. One import exited0xC0000005 before tests, matching the previously recorded native shutdown risk; that run remains failed rather than being counted as passing.

### Final regression results

- Full source sweep: **104/111 suites passed** in 2416.47 seconds. The seven failures were retained: three mission drivers omitted required camp-event choices, an unavailable rescue tooltip erased survival help, refreshing a frozen old mission board replaced its generation version, the new architecture test had a parsing mistake, and one headquarters suite exited with a native access violation despite zero failed assertions.
- Fixed the drivers to resolve the real event gate; restored tooltip rules; preserved frozen boards. Corrected the test, reproduced the interior-house camera defect with a failing runtime assertion, then fixed fading for units inside walkable scenery bounds.
- **12/12 affected and related suites passed on rerun**, including all seven failed suites, campaign/persistence and visual lifecycle. The modern recruit campaign completed five victories. These were direct runtime checks; a fresh full111 sweep was not repeated.
- Marker wording regression passed after separating skirmish “Bonus Challenge” from campaign reward labels.
- **90 maps plus three forced fallbacks passed**. Existing broader suites also passed150 objective configurations,225 difficulty configurations,93 faction encounters, six combat stress cases/188 enemy commands, and12 session cycles. Session measurements held243 headquarters nodes,2555 objects and261 resources; static memory approximately67.7–67.85MB. This is bounded evidence, not proof of no leaks.
- Final native renderer run: **16 screenshots, exit0, empty error output,27.40 seconds**, covering all three presets at720p/1080p, two angles, detail and staged interior views. The interior view stages a unit in a separately navigation-tested room; it is not a manual playthrough.
- PCK export completed with exit0. External production-package tactical smoke passed with zero failures: interrupted campaign configuration, once-only bonus processing, persistence, partial movement, repeated-command rejection and actual cache collection.
- Existing four-phase external PCK regression also passed **4/4**, exit0 throughout: creation/tutorial/skirmish/settings, interrupted enemy turn, recovered encounter/debrief and a further relaunch. Total39.15 seconds. This uses the exported PCK with Godot, not a standalone EXE.
- Editor import attempts intermittently exited0xC0000005 before tests. Successful runtime/native runs do **not** establish a clean final editor-import workflow; the native risk remains open.

### Build limitation

The configured Windows release template `C:\work\export-templates\windows_release_x86_64.exe` is absent. No standalone EXE was produced or tested. The verified data package is `verification/tactical-situations/release/FantasyTactics-tactical-situations.pck`, run with the available Godot engine. Install the matching4.7.2 Windows template/update the preset, then perform an EXE export and independent application smoke test.

### Modified file groups

- Movement: player move plan, command, navigation slicing, controller/input previews, HUD and field guide.
- Architecture: original procedural kit, layout/generator versioning, camera occlusion.
- Optional goals: three resources, definition/runtime/query/marker scripts; encounter, code/configuration, campaign state/result/save codec and campaign UI integration.
- Regression: five focused suites, legacy save fixtures, external pack smoke, showcase; corrected existing mission/event drivers and rescue tooltip assertions.
- Documentation: scope, implementation plan, this report, test index and progress ledger. Existing unrelated dirty work was preserved.

### Remaining issues, in priority order

1. Intermittent native Godot import/shutdown access violation remains unresolved; failures are retained.
2. Standalone Windows EXE export/smoke blocked by the missing template.
3. Human balancing/usability and lower-end hardware checks remain unverified. Three new automated encounters ended in defeat; broader campaign drivers completed victories. Neither proves human balance.
4. Architecture has a compact authored topology with modest seeded variations, not a large library of building layouts. Roofs and further house variants are outside this pass.

Implementation is ready for review; it is not a claim that every runtime/environment risk is closed.

### Measured rendering observations

Windows, Godot4.7.2 standard Compatibility; native tool reported NVIDIA RTX500 Ada Generation Laptop GPU, OpenGL3.3, driver596.71. Default preferences with frame cap60, one rendered battlefield in the review viewport.Final45-frame samples averaged15.93–16.19ms (capped, not an uncapped GPU benchmark). New scenes reported453–596 draw calls and approximately151k–159k primitives. Node counts for the three presets were824/877/775, repeated at both resolutions after scene cleanup. Final setup from request to ready measured0.557–0.848s (earlier review1.23–1.82s; cache/run differences prevent an optimisation claim). These observations are not universal performance guarantees or proof of absence of leaks.

### Reproduce focused checks

```powershell
./tests/run_regressions.ps1 -Godot verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe -TimeoutSeconds 300 -TestNames tactical_movement_tests,architecture_tests,tactical_optional_tests,tactical_generation_tests,tactical_encounter_tests -ReportDirectory verification/tactical-situations/repeat
```

Use fresh isolated APPDATA/LOCALAPPDATA directories first. The runner's `-Category all` executes the complete available source suite. `dev/tactical_situations_showcase.gd` captures the actual renderer; `tests/tactical_pack_smoke.gd` is an external production-PCK harness requiring OATH_TEST_ISOLATED=1 and private user data. Development scripts/tests/docs remain excluded from export.

## Human playtest still needed

Play each primary objective with each optional goal. Click beyond range before and after acting; try an occupied stopping point and a target beyond an arch/house. Compare the preview and actual endpoint. Try cache collection on the final winning action, complete Hold Ground at round-end, revive a downed companion and check Stand Together stays failed, then retry/quit/continue. Evaluate whether the modest bonuses justify detours and whether the new rooms/gateways improve decisions for2/3/4 heroes. Verify low-end hardware and enlarged UI beyond the reviewed defaults.

## Scope rulings

Work stayed in the requested dirty checkout to preserve prior approved changes; rollback is not isolated into a new branch. Initial optional goals/rewards were chosen as the smallest complete extension of existing mechanics, with provisional tuning; captive/escaping-NPC scenarios would require separate content work. No balance/stat changes were made. One independent read-only final review found no confirmed Critical/Important defect; runtime evidence remains the stronger check.

## Actual renderer screenshots

[720p movement preview](tactical-situations/screenshots/open_courtyard-1280-angle0.png) · [Courtyard kit detail](tactical-situations/screenshots/courtyard-detail-1920.png) · [House interior fading](tactical-situations/screenshots/house-interior-1920.png) · [Ruined Lanes](tactical-situations/screenshots/ruined_lanes-1920-angle0.png) · [Central Plaza](tactical-situations/screenshots/central_plaza-1920-angle0.png). All16 PNGs are in the screenshots directory.
