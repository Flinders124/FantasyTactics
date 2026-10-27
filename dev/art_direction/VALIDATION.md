# Validation record - art-direction exploration

Engine: Godot 4.7.2 standard, Compatibility renderer. GPU: NVIDIA RTX 500 Ada Generation Laptop GPU, OpenGL 3.3, driver 596.71. Validation performed 23 October 2026.

## Passed

- All three options instantiate and render in the existing project.
- Switching A/B/C preserves camera transforms for all three presets, with five fixed character positions.
- Each character retains Idle, Walk, Attack, Cast, Hit and Death. All clips were sampled in each option; reset recovers from Death.
- The lab contains no combat physics/collision objects and introduces no gameplay rules.
- After all nine option/view combinations are exercised and the lab is disposed, the normal title opens and a generated encounter starts with the configured enemy count and exactly two heroes.
- Character regression suite: `CHARACTER RESULT: 0 failures`.
- Faction visual regression suite: `FACTION VISUAL RESULT: 0 failures`.
- Courtyard regression suite: `RESULT: 0 failures`; determinism, cosmetic isolation, collision masks and occluder cleanup checked.
- Windows export-scope suite: `EXPORT SCOPE RESULT: 0 failures`.
- A normal Windows PCK was exported to an isolated work directory. A separate packed-resource smoke test reported `ART EXPORT SMOKE RESULT: 0 failures`: normal main scene retained, title opens, preview scene and experimental shader absent from the pack.
- Twelve individual PNGs captured: gameplay/detail/architecture at 1920 x 1080 for A/B/C, and gameplay at 1280 x 720 for each. Three contact sheets assemble real captures.
- Inspected matching detail, overview, architecture and 720p renders. Directional shadows are present, floor markers clear the paving, characters face the camera, and assets/shaders load without missing-resource or shader-compilation errors. No screen effects mask the underlying geometry.

## Existing regression failure found

The broader `tests/flow_tests.gd` suite reports **1 failure**, at its assertion that the total roster must equal four units. A diagnostic run printed:

    selected=[cleric, mage]
    configured=[cleric, mage]
    units=5 enemies=3 heroes=2

The selected heroes transfer correctly; current faction configuration supplies three enemies. The old fixed four-unit expectation is inconsistent with variable faction rosters. This milestone does not change those production systems or silently alter the legacy test. The lab's normal-game check validates the configured total (`2 + configured enemy count`) and two-hero count instead.

## Warnings and build scope

Normal-game/courtyard teardown emits ObjectDB/resource-in-use warnings in several existing smoke tests; these are recorded rather than treated as a clean shutdown. The isolated visual-only comparison test passed without those messages before the normal-game lifecycle check was added.

The first export attempt hit a sandbox temporary-directory/safe-save error. Repeating with TEMP, TMP, APPDATA and LOCALAPPDATA directed to writable work folders produced a valid pack and the packed smoke test passed. No application settings were changed to bypass safe saves. The delivered milestone is source previews and screenshots; a new installer, signed executable, clean-machine certification and a full 47-suite release regression run were not performed.

## Performance sample

| Option | Median wall-frame ms | Approx. p95 ms | Reported draw calls | Reported primitives |
| --- | ---: | ---: | ---: | ---: |
| A | 1.413 | 2.596 | 1062 | 235090 |
| B | 1.448 | 2.700 | 1092 | 243006 |
| C | 1.385 | 2.117 | 956 | 234136 |

90 uncapped frames after 20 warm-up frames at 1920 x 1080, fixed gameplay overview, frozen Idle. Counts include shadow passes; timings are CPU/SceneTree wall-frame intervals, not GPU timestamps. One short laptop-GPU sample cannot establish full-game performance or minimum supported hardware. Shader compilation, option rebuild cost and first-run loading are excluded from the steady-state sample.

## Prototype limits

These scenes establish shape, colour, materials and lighting direction. They retain the existing short animations, rigid weighting, simple faces and much of the existing character construction. B is a brushed-material/proportion prototype rather than a full realistic resculpt. Repeated hills/tree crowns and simple cloth are visible at close range. The UI is a comparison overlay in the current game language, not a complete combat-HUD redesign. The lab is not a playable combat encounter. No external concept art was substituted for captures.

The recommended direction remains a proposal. Stop here for the user's selection before polishing or rollout.
