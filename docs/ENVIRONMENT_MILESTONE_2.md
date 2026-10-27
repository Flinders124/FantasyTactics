# Milestone 2 — The Lantern Oath environments

The existing gameplay uses the approved Option C identity: blue masonry, teal Watch standards, copper foliage, cream/gold accents, angular silhouettes and banded lighting. This milestone extends that identity across Open Courtyard, Ruined Lanes, Central Plaza and the headquarters camp. It does not select a new direction or begin Milestone 3.

## Implemented

- Rebuilt presentation meshes for walls, plinths, pillars, boundary stones, paving and crates. Masonry has separate courses, recessed joints, substantial caps and bevels that catch the key light. Upright blockers retain their original normalized footprint and height.
- Corrected inward winding and smoothed bevel normals in the shared box helper. This removes false surface facets and self-shadow patterns. Camp canvas now consistently faces outward; the original tent shapes and openings remain.
- Replaced large red marks scattered over the combat floor with restrained seam/edge moss and smaller leaves/cracks. Broad paving tones distinguish worn central routes, darker margins and the plaza objective area. Ground shaders use low-frequency world-space variation, without texture maps or added dependencies.
- Replaced needle grass and flat ivy squares with folded copper leaves. Seeded planting islands vary plant height, scale, angle and density. Rear corner groves and Oath standards frame battlefields; upright additions remain outside the traversable rectangle. The player-facing edge stays open.
- Headquarters uses the same stone stepping paths, bevelled timber pieces, banners, vegetation and asymmetric tree crowns. Shared ground extends beyond the old circular camp base. Two modest, shadowless lantern lights mark the front approaches. Existing tents, training equipment, campfire, characters, five pick volumes and destinations remain in place.
- Kept the directional sun and cool fill, raised ambient visibility, tuned shadow bias and retained a 65 m shadow range. Headquarters has a slightly warmer key. Subtle standard distance fog links the ground and background. Linear tone mapping preserves the established flat-colour art direction.
- Fixed quality application so the fill and portraits never acquire redundant shadows. Existing Low/Standard/High choices now apply no/2×/4× MSAA to the main viewport and subviewports. Plant density remains 35%/70%/100%; only the sun casts directional shadows on Standard/High. Structural trees and architecture remain visible on every preset.

## Shared implementation

| File | Responsibility |
|---|---|
| `scripts/lantern_environment.gd` (new) | Reusable presentation mesh factory, folded plants, angular tree crown and Watch standard. No physics or navigation nodes. |
| `scripts/lantern_camp_dressing.gd` (new) | Seeded camp planting, instanced paths and trees, shared standards and two lanterns. |
| `scripts/courtyard_kit.gd` | Selects upgraded visual meshes while loading original collision resources unchanged. |
| `scripts/courtyard_dressing.gd` | Deterministic cosmetic paving, clusters, groves and exterior composition. MultiMesh batching and existing occluder fading remain. |
| `scripts/lantern_art.gd` | Shared palette, material family, battle/camp lighting and explicit shadow-source metadata. |
| `assets/art/lantern_surface.gdshader`, `lantern_fade.gdshader` | Matching broad world-surface variation. Opaque gameplay material still has no alpha output; only the occlusion shader is transparent. |
| `assets/art/lantern_shapes.gd` | Outward, flat-shaded bevelled boxes, also used by small existing armour trim pieces. |
| `scripts/camp_kit.gd`, `camp_overview.gd` | Bevelled camp boxes, outward canvas, new dressing integration and warmer lighting. |
| `scripts/settings_presentation.gd` | AA on viewports, sun-only shadow quality, existing plant-density controls. |
| `scripts/audio_settings_panel.gd` | Accurate descriptions of those three existing presets. |
| `tests/environment_tests.gd` (new), `tests/run_regressions.ps1` | Collider, objective accessibility, mesh normal/bounds and quality regression coverage. |

Mesh resources and materials are shared by each MultiMesh batch. Upright foliage is opaque, with only the small existing vertex sway; it has no individual shadow passes. Cosmetic random streams remain separate from battlefield generation and campaign state. Tall new standards use the existing reversible occluder fade.

## Preserved contracts

Map generator placement rules, seeds, arena dimensions, objective definitions/positions, spawn areas, collision resources/masks, navigation settings, movement, combat rules, cameras, roster, animation clips, HUD and camp interactions have not been redesigned. Changes to the shared bevel helper improve small existing armour trim lighting as well as scenery; no character anatomy or animation work was added.

The original collider resources remain authoritative for both navigation baking and ray tests. Visual details are never allowed to add a collision object. Future environment additions should follow that convention, remain inside an existing blocker footprint or outside the arena, and register conservative bounds if they can obscure a unit.

## Review the actual renderer

Open `review.html` in a browser beside this report. It compares identical cameras, seeds, objectives and unit placement using actual Godot screenshots. Before images are from the project as it stood before this milestone. Idle poses and plant sway phase may differ. The normal gameplay views include all HUD elements; close views use the normal tactical camera at distance 10 rather than an external model viewer.

The gallery includes courtyard, Hold Ground in Ruined Lanes, Extraction in Central Plaza, close materials, exterior architecture/vegetation, headquarters, 720p/900p/1080p and all three graphics presets. Historical Standard/High did not enable MSAA; those comparisons intentionally include the new AA treatment.

## Rendering choices and limitations

The project remains on Godot 4.7.2 Compatibility/OpenGL 3.3. Improvements favour geometry, opaque materials, instancing, one shadow-casting sun, MSAA and ordinary distance fog. No renderer migration, SSAO, volumetrics, bloom, animated foliage simulation, texture downloads or new libraries were introduced. See the [Godot renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) for renderer tradeoffs and [directional shadow documentation](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html) for shadow range/detail tradeoffs.

Remaining refinements: masonry wear is deliberately stylised and restrained; the native fountain, statue, cart and barrel shapes are retained. Planting uses repeatable clusters rather than hand-authored placement for every seed. There is no distance LOD for the small tree population. Shadows retain the limitations of the Compatibility shadow maps, especially at extreme grazing views. Hand-painted environment textures and bespoke distant scenery would be further art production, not implemented here. Integrated GPUs and other operating systems have not been tested. No target hardware or formal frame budget was found in the project documentation.

## Rollback and review files

The project was edited in place. `source-changes.zip` contains changed/new sources using project-relative paths. `rollback-originals.zip` contains the corresponding original files from immediately before this milestone. To revert only this milestone, close Godot, restore those originals into the project, then remove the new `lantern_environment.gd`, `lantern_camp_dressing.gd`, `tests/environment_tests.gd` and their generated `.uid` files. Preserve any subsequent edits before restoring originals. A full pre-milestone project snapshot is also retained in this chat's scratch workspace.

The historical art-direction exploration remains available; no new art selection is required. Work stops here for Milestone 2 review.

## Performance comparison

Measured on Intel Core Ultra 7 165H / NVIDIA RTX 500 Ada Generation Laptop GPU, NVIDIA OpenGL driver 596.71, Godot 4.7.2 Compatibility. No minimum-hardware or formal FPS target is documented.

Two independent before/after runs used identical seeds, objectives, root viewport size 1920×1080, disabled vsync, no FPS cap, 120 warmup frames and 600 sampled process frames per case per run. Table values average the two means and the two p95 values. Draw calls are the engine frame monitor, including HUD and shadow passes. These short wall-frame measurements include scheduling/presentation effects; they are not isolated GPU timestamps, loading benchmarks or a guarantee of performance on other hardware. Raw runs are saved under before/ and after/.

| Scene | Mean ms before → after | p95 ms before → after | Draw calls before → after |
|---|---:|---:|---:|
| courtyard | 3.042 → 2.588 | 3.990 → 3.348 | 968.0 → 578.0 |
| courtyard-quality-0 | 2.555 → 1.793 | 2.947 → 2.430 | 295.0 → 299.0 |
| courtyard-quality-1 | 2.967 → 2.433 | 3.568 → 3.250 | 968.0 → 578.0 |
| courtyard-quality-2 | 3.067 → 3.033 | 3.875 → 4.290 | 968.0 → 578.0 |
| lanes-hold | 4.150 → 3.185 | 5.319 → 4.191 | 1371.0 → 798.0 |
| plaza-extraction | 5.080 → 3.282 | 6.290 → 4.114 | 1169.0 → 687.0 |
| headquarters | 4.007 → 3.102 | 5.408 → 3.734 | 1438.0 → 721.0 |

Standard is the default. Its reduced shadow workload and instanced camp dressing outweigh the added geometry and 2× MSAA in these samples. Standard draw calls fell about 40% in the courtyard, 42% in the lanes/plaza and 50% in headquarters. Low had four more draw calls in the courtyard from new shared standards.

High now includes 4× MSAA where the baseline had none. Its courtyard average was similar, but p95 increased from 3.875 to 4.290 ms (about 11%). This is an explicit quality/cost tradeoff, not a claim that every preset got faster. Low/Standard remain available through the existing settings. Recheck the chosen preset on intended minimum hardware; only this Windows laptop GPU was measured.

## Validation and remaining issues

All 48 core/environment suites completed with zero assertion failures. The strict runner reported 32 clean passes and 16 failures due to shutdown resource warnings, with no test timeouts or other script errors. These warnings remain unresolved; the before and after capture processes both report 33 leaked objects / 31 resources at exit. `regression-results.json` records the distinction rather than hiding stderr.

Coverage includes 25 navigation seeds and detours, all 90 objective/map combinations plus nine fallbacks, 135 difficulty configurations and six hero pairs, movement/commands, reversible occluder materials, live settings and pause/resume, five-mission campaign completion, persistence/retry/save flow, all five camp destinations, camp picking and camera extremes. New environment checks verify outward normals, mesh bounds, original collider faces, objective reachability, material defaults, sun-only shadows and AA presets.

The matched capture fixtures also retain identical geometry signatures, SHA-256 collider geometry signatures, spawns and objective positions across all three maps; see `layout-comparison.json`. Actual images were reviewed at gameplay distance and closer, including material/shadow detail, vegetation, headquarters, three graphics presets and 1280×720 / 1600×900 / 1920×1080. No new missing materials or obvious z-fighting were seen in these views.

At 720p, the existing HUD occupies a large portion of the battlefield and the wide initiative bar can clip controls at the right edge. This is also present in the baseline capture. It is an outstanding UI-layout issue rather than a new environment regression; the complete UI was outside this milestone.

The Windows export completed, and its separate packed-content smoke test loaded all three maps with ready navigation and the five-destination camp. Production shaders/new modules are included and regression scripts are excluded. Additional logs and build details are included with the review.

Additional faction checks: visual, spawn and compatibility suites also passed. The separate faction catalog suite still reports its pre-existing 126 failures in 12,367 checks, matching the recorded pre-rollout baseline. Its faction-budget/introduction expectations were not changed by this environment milestone. In total, 51 of 52 distinct suites have zero assertion failures; the one catalog suite retains those known failures. The final native Windows executable also started and exited successfully in a bounded headless smoke run (exit 0).
