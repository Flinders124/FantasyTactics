# Milestone 3 — character implementation review

The project now loads replacement skinned GLBs for all 21 existing visual IDs: four heroes (Knight/Warden, Ranger/Scout, Mage/Arcanist, Cleric/Dawnkeeper), the two legacy enemy visuals, and all five variants in each of Ashfang, Hollow and Verdant. The approved Lantern Oath / Option C palette and Milestone 2 environments are retained.

**This is a substantial technical low-poly replacement and animation pass, not professionally sculpted final character art.** The environment has no installed sculpting/DCC package. The editable offline mesh/pose pipeline and direct GLB replacement workflow are implemented, and the remaining artist work is listed below. Production character-art quality has not been certified against the user's full definition of done. Review the actual renderer results before approving further work. Milestone 4 has not begun.

## What is implemented

- Dedicated GLB per visual ID, with indexed mesh topology, one skinned body/equipment mesh, 18 shared bones, 7–8 material surfaces, and approximately 3,300–4,300 triangles. Existing faction bodies' many rigid runtime attachment parts are bypassed during normal gameplay.
- New cross-section anatomy and facial landmark topology: jaw, cheeks, temple, brow/eye planes, nose bridge, mouth line, ears and hair/headgear. Faces remain deliberately stylised and share an anatomical foundation; these are not unique artist-sculpted heads.
- Continuous arm and leg profiles with blended weights around elbows, knees, waist and robe hems. Palm and curled finger geometry encloses the weapon shaft. Boots have shaped soles/toes; Verdant uses split root feet. There is no finger animation rig.
- Layered breastplates, bevelled pauldrons/greaves, belts, split robe panels, rear cloaks/shrouds, recurved bows, diamond-edged blades, cleaver profiles, maces, shields and forked staves. Equipment is part of the skinned asset, so it cannot drift away from a hand attachment node during playback.
- Hero silhouettes: crest/shield; hood/quiver; swept hat/two-handed staff; ivory robe/mace. Faction silhouettes: broad horned/tusked Ashfang, exposed rib cages/funeral crowns/shrouds for Hollow, antlers/leaf shoulders/root feet for Verdant. Shields, bows, staffs, crowns and tabards distinguish each faction's existing jobs. The legacy Sentinel remains a bow user; Verdant Sentinel retains its shield.
- Controlled skin/cloth/metal/leather/trim/hair materials use the existing Lantern shader and world lighting, preserving imported material colour, metalness and roughness. No new textures or runtime dependencies were added.
- Seven native skeletal clips: Idle, Walk, Run, Attack, Cast, Hit, Death. Offline two-bone pose solving maintains planted stance feet and two-handed staff contact. Walk/Run are scaled from measured actor displacement; movement speed and collision remain authoritative in the original movement system.
- The AnimationPlayer blends complete poses for all animated joints rather than stopping and resetting the skeleton between clips. Permanently static root/spine/neck joints need no channels; constant curves use two keys. Movement turns the visual smoothly; facing an attack target remains immediate.
- Death uses a staged visual fall, delayed vertical descent to keep feet clear during the fall, bent knees/elbows and wrist corrections that lay weapons/shields above the floor. There is no ragdoll or collision-driven animation. Checks cover intermediate poses as well as the final pose.

## Timing and gameplay contracts

Combat already applies damage immediately when an attack is accepted and uses a 0.22 s action-resolution window. Those rules, all abilities, definitions, hitboxes, ranges, movement speed, objective positions and campaign behaviour remain unchanged. The replacement clips start at contact/aim/release and provide short interruptible recovery: Attack 0.38 s, Cast 0.45 s, Hit 0.26 s, Death 0.85 s. Recovery can continue after the gameplay lock ends; a new movement or action interrupts it. No animation completion signal unlocks combat and no animation method track applies damage.

This timing contract limits conventional attack anticipation. A full wind-up before an immediate damage event would be misleading; it was not added. Ready poses and recovery carry the motion. Truly richer authored anticipation would require a separately approved timing/presentation design.

Walk's canonical stride is 1 m per 0.5 s cycle; Run is 1 m per 1/3 s cycle. Runtime playback follows actual movement, selecting Run above 2.8 m/s. Stance targets stay fixed vertically, and feet move backwards relative to the travelling body. This reduces sliding during steady travel; there is no runtime terrain IK or bespoke start/stop clip, so some transition sliding remains possible.

## Inspect and compare

Open `review.html` in a browser. It contains 50 matched comparison choices: roster groups, front/side/rear views, animation poses, face/hand/equipment details, gameplay-distance views and headquarters integration. Before images come from a full snapshot of the project before this milestone. The corresponding pose is sampled at the same normalised clip time, rather than claiming the old and new motions are identical.

`animation-demo.gif` is a 109-frame actual-renderer animation demonstration, captured at 1024×576 and about 15 fps. It shows inspection clips in place, not a completed combat match. Gameplay was separately exercised by the regression tests and rendered courtyard captures.

For live inspection, open `res://dev/characters/showcase.tscn` in Godot and press F6. Choose any visual ID or roster group, change clips, pause/resume, replay, drag the right mouse button to orbit, scroll to zoom, or use Front/Side/Rear/Tactical/Equipment views. The inspector has no gameplay logic and is excluded from the Windows release. The normal game is still launched through its existing main scene.

## Asset pipeline and modified files

| File or directory | Change |
|---|---|
| `assets/characters/source/build_characters.py` | New offline mesh, skinning, pose-target and indexed GLB exporter. Uses the existing legacy source's rig/math helpers and Python standard library. |
| `assets/characters/oath_models/` | 21 dedicated imported GLBs and their Godot import metadata. |
| `assets/characters/manifest-v3.json` | Current per-ID geometry/material/bone/clip metrics. |
| `assets/characters/IMPORT_WORKFLOW.md` | Artist replacement contract, rig/clip conventions, rebuilding and limits. |
| `scripts/character_visual.gd` | Loads dedicated assets, preserves materials, blends complete poses, matches gait to displacement and smooths movement facing. Legacy comparison/fallback remains. |
| `dev/characters/showcase.gd`, `showcase.tscn` | Development-only all-roster inspector. |
| `tests/authored_character_tests.gd` | Normalised/blended weights, mesh costs, clip isolation, stance contacts, staff grips and intermediate/final skinned floor bounds. |
| `tests/character_tests.gd` | Counts indexed triangles correctly and recognises both speed-matched gaits; existing authoritative damage/restart tests retained. |
| `tests/faction_visual_tests.gd` | Tests dedicated skinned faction assets and their collapse/reset rather than requiring the retired rigid runtime body assembly. |
| `tests/run_regressions.ps1` | Adds authored-character coverage. |
| `export_presets.cfg` | Excludes all development scenes from release. |

No battlefield/environment or headquarters-construction scripts, combat calculations, unit definitions, movement code, camera controls, full HUD or combat effects were redesigned. The existing shaders and geometry assets outside the character pipeline remain intact. See `preservation-checks.json` and `layout-comparison.json` for verified source/layout comparisons.

An artist can open any replacement GLB in a DCC and replace it at the same path while preserving rig/clip conventions. There is no need to use the generator for hand-authored assets. Do not rerun the generator over hand-edited GLBs without preserving those edits. The full contract is in `IMPORT_WORKFLOW.md`.

## Remaining character-art work

- Unique sculpted faces, hair, stronger per-character anatomy and production-quality retopology still require dedicated character art. The current models are assembled offline from authored profiles/surfaces and exported; they are not equivalent to professional sculpts or a fully welded hand-retopologised body.
- Fingers have fixed gripping shapes, not digit bones. Simple full-pose IK targets maintain staves, but there is no general runtime hand IK, reach adaptation or sophisticated hand acting.
- Bowstrings do not deform to the draw hand. A held inspection arrow remains attached rather than being released/hidden by an authored prop track. A bowstring/arrow-specific rig and animation pass is still needed; this is not claimed as solved.
- Animation is authored through sampled pose targets. More nuanced weight transfer, facial acting, unique class personality, directional hits, starts/stops and richer collapse choreography need an animator. The footage is useful for review, not proof of commercial-quality acting.
- The floor checks permit small contact tolerances. Final extremities can reach about 1.2 cm below collision-ground Y=0 (up to about 3 cm beneath the cosmetic paving top). Larger intermediate penetration found during testing was fixed. There is no runtime foot IK on irregular terrain.
- Cloth has weighted panels, not simulation or dedicated secondary-motion bones. Some robe/cape intersections and stiff folds can remain in extreme poses and close inspection. No automatic LOD, facial rig, ragdoll, animation layering system or extra VFX overhaul was introduced.
- The pre-existing crowded/clipped HUD at 720p, shutdown resource warnings and faction catalogue expectation failures remain outside the character-art work. They are reported rather than hidden.

The replacement roster and inspection workflow are ready for review; the professional sculpt/acting target still needs that remaining art production. Work stops here before Milestone 4.

## Measured rendering costs

Hardware: Intel Core Ultra 7 165H / NVIDIA RTX 500 Ada Generation Laptop GPU, NVIDIA OpenGL 596.71, Godot 4.7.2 Compatibility. No documented minimum hardware or formal frame budget was found. No integrated GPU or other platform was tested.

Two interleaved independent runs per version used identical seeds, unit counts, cameras and quality presets, a 1920×1080 viewport, disabled vsync, no FPS cap, 120 warmup frames and 600 process-frame wall-time samples per scene. Both versions used the same hidden-window process launcher. Means and p95s below average the two runs; p95s are not pooled. These are short wall-frame measurements, not GPU timestamps or a guarantee of minimum-spec performance. Window visibility/focus, power state and host scheduling caused substantial variation across repeated launches.

| Scene | Mean ms before → after | p95 ms before → after | Draw calls before → after |
|---|---:|---:|---:|
| courtyard | 6.316 → 4.144 | 9.368 → 4.950 | 578.0 → 296.0 |
| courtyard-quality-0 | 4.635 → 2.958 | 6.930 → 4.154 | 299.0 → 183.0 |
| courtyard-quality-1 | 5.531 → 3.498 | 7.946 → 4.332 | 578.0 → 296.0 |
| courtyard-quality-2 | 4.970 → 3.887 | 8.390 → 4.760 | 578.0 → 296.0 |
| lanes-hold | 4.697 → 4.889 | 8.454 → 7.620 | 798.0 → 282.0 |
| plaza-extraction | 7.173 → 5.881 | 10.989 → 10.626 | 687.0 → 287.0 |
| headquarters | 3.806 → 8.217 | 4.834 → 13.375 | 721.0 → 700.0 |

Draw calls fell about 49% in the courtyard, 65% in Ruined Lanes, 58% in the plaza and 3% in headquarters. Counts include the existing HUD and shadow passes. This confirms the benefit of replacing many rigid faction parts with a skinned mesh; it does not prove a corresponding frame-time speedup. The independent-run headquarters timings above regressed markedly and were not hidden.

A follow-up controlled headquarters probe swaps only the four character sets inside the same running camp, using Before/After/Before/After blocks, 180 warmup frames and 1,200 wall-time samples per block. It measured 1.991 ms before versus 2.025 ms after (about +1.7%); average block p95 was 2.823 versus 2.780 ms. This does not reproduce the independent-launch spike. The raw blocks are in `hq-controlled-profile.json`. Its lagging TIME_PROCESS monitor values include reload effects and are not used as isolated CPU timings.

Conclusion: batching and indexed geometry reduce submission work, but total frame-time impact is noisy and no universal speedup is claimed. Retest on intended hardware, particularly headquarters and a full six-unit encounter. Animation costs remain bounded to 18 bones, with no runtime IK, physics cloth, ragdolls or textures. Current assets use 3,317–4,239 triangles each and at most eight surfaces; the mesh-cost regression test uses a conservative 6k-triangle limit as an implementation guard, not a minimum-hardware certification.

## Verification results

All 49 core/environment/character suites completed with zero assertion failures. The final authored-character, live character integration, faction visuals and export-scope checks were rerun after the final asset changes and passed. The strict core runner reports 33 clean passes and 16 failures due to the existing shutdown resource warnings. These remain unresolved; stderr is retained in the logs. No core test timed out or reported another script error.

Faction visual, spawn and compatibility checks passed. The separate faction catalog suite still reports its recorded pre-existing 126 failures in 12,367 checks. Those introduction/budget expectations were not changed. Overall, 52 of 53 distinct suites have zero assertion failures; that catalog suite retains its known failures. See `regression-results.json` and `regression-logs.zip`.

Coverage includes real movement-to-gait transitions, healing/casting, actual attack/hit/death events, no repeated damage while seeking animation, reset after death/restart, all 21 assets, valid normalised/blended weights, bounded indexed mesh counts, planted stance samples, two-handed staff contacts and four intermediate/final skinned floor samples. The full gameplay suite includes navigation/objectives, pause/resume, settings, five-mission campaign, headquarters interactions and save/retry flows. Model poses and details were inspected in front/side/rear and actual gameplay views. This is sampled QA, not exhaustive certification of all mesh intersections.

`combat-contact.png` and `combat-death.png` are staged captures from the real encounter controller: only fixture positions/initial health were set by an external capture script. The normal attack command applied the original four damage, triggered the hit/death animation and kept the original resolution timing. No production combat code was changed.

The final Windows release exported successfully. A separate packed-content smoke loaded all 21 dedicated assets, checked their rigs/clips/scales, loaded all three battlefields and headquarters, and confirmed the inspector/tests were excluded from the release. A bounded native executable smoke exited 0. Editor/import and render captures had no missing-asset or parser errors; known shutdown warnings remain.

## Delivery and rollback

The original project is edited in place. `source-changes.zip` contains changed/new sources and GLBs using project-relative paths; `modified-files.json` records original and updated SHA-256 hashes. `rollback-originals.zip` contains the original versions of changed existing files. To revert, close Godot, preserve later edits, restore those originals into the project, then remove the paths marked `added` in the manifest (including the replacement model directory, new source/inspector/tests and documentation). Godot will rebuild its import cache. A full pre-milestone project snapshot remains in the chat scratch workspace.

Extract the Windows build ZIP and run FantasyTactics.exe beside FantasyTactics.pck. Extract the visual-review ZIP and open review.html. The developer inspector is intentionally available in the source project rather than the release build.
