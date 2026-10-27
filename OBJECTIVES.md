# Battlefield variety and objectives

F5 opens the existing title and two-of-four party flow. Choose a **Battlefield** and **Objective** above the hero cards. The description explains victory before Start Encounter. Defaults remain Open Courtyard / Elimination. Camera, movement, attacks and ability controls are unchanged. No difficulty setting or new combat mechanic was added.

## Configuration and reproducibility

Editable presets live in `definitions/presets/`: `open_courtyard.tres`, `ruined_lanes.tres`, `central_plaza.tres`. They use BattlefieldSettings, including arena/spawn geometry, placement/retry limits, gameplay clearance and independent cosmetic densities. SceneFlow's Open Courtyard settings reference the shipped open preset and can be overridden in the Inspector. The other choices use the corresponding resources. Configuration snapshots duplicate settings/objective definitions, retain selected hero IDs/enemy definitions and cache the accepted layout.

Generator **version 2**, preset ID, objective ID, original seed and geometry are recorded in BattlefieldLayout/signatures. Retry reproduces that accepted layout and deterministic dressing; New Battlefield clears the layout and changes only the seed. Cached configurations with mismatched seed/preset/objective/version are rejected rather than silently generating something different. Reproduction is supported within the shipped Godot 4.7.2 generator; cross-engine-version bit-identical output is not promised.

- **Open Courtyard:** seven scattered obstacles by default, broad paths, original fountain blocker, cracked paving and planted outer garden clusters. Open rectangle fallback.
- **Ruined Lanes:** four seeded wall segments divide upper/lower lanes from the interconnected central route. Doorway facades and an exterior ruin front establish the location. Canonical four-wall fallback.
- **Central Plaza:** four corner structures (one damaged guardian statue and three columns), an unobstructed centre, muted radial paving emphasis and exterior monument/column groups. Canonical four-structure fallback.

The two structured presets deliberately use four structural blockers; their topology is authored in BattlefieldGenerator, not inferred from arbitrary obstacle_count. Arena dimensions and seeded segment offsets determine their placement. Invalid structural clearance triggers bounded regeneration then canonical preset geometry. Fallbacks use canonical 28x22 m settings; a long configured extraction distance can expand fallback width. No terrain elevation is introduced.

Original placement has at most three generation attempts and 40 trials per scattered obstacle by default (clamped to eight attempts / 200 placement trials). The final attempt is the known preset fallback. All four spawns undergo collision-clearance and navigation connectivity validation after synchronous baking and map synchronization. No units or world commands are enabled beforehand. Objective placement precedes obstacles and dressing. Navigation failure gives a readable setup failure instead of hanging.

## Objective definitions and timing

Editable definitions live in `definitions/objectives/`. They hold immutable configuration; ObjectiveController owns progress, inclusion counts, required hero IDs and the last checked round. Radius defaults to **2.8 m**. Ground-anchor inclusion uses full 3D distance on this flat battlefield, inclusive within **0.000001 m**. Double circular outlines with eight radial ticks and HOLD/EXIT labels distinguish objectives from ability targeting. HUD progress remains visible when units overlap world labels.

| Objective | Success | Defeat / other outcomes |
| --- | --- | --- |
| Elimination | All enemies dead | No heroes: defeat; both factions eliminated in one atomic batch: draw |
| Hold Ground | At least one living hero and no living enemy inside at three consecutive round-end checks | No heroes: defeat, taking precedence over progress; killing enemies alone does not finish |
| Extraction | Both originally selected heroes alive and inside after a completed action | Either required hero dead: defeat after the atomic batch; killing enemies alone does not finish |

Hold Ground samples **once when TurnManager wraps the initiative schedule**, after the last scheduled living unit's End Turn, including skipped dead slots. Empty, enemy-held or contested checks reset progress to zero. Duplicate round numbers cannot increment it. A final result halts scheduling before incrementing into another round. With no enemies left, heroes continue taking turns and can complete the three checks.

Extraction's exit is at 24% of arena width east of centre, away from the west hero zone. Default minimum navigable travel is **12 m**, measured as each hero's path-to-centre cost minus zone radius, a conservative lower bound on entry travel. Routes from all spawns and eight perimeter points are checked. Hold Ground also validates opposite approach gates 1.2 m beyond its reserved radius. The 0.5 m navigation-agent clearance remains unchanged. Eliminated units never contest or count toward arrival; units at the exit remain in combat.

CombatController is the sole outcome authority. ObjectiveController proposes a result/reason. Movement completion and committed attack/ability/area batches evaluate success; all area health/death changes precede evaluation. Presentation timers do not apply damage or own victory. Results are emitted once, stop commands/AI and display the objective-specific reason. Lifecycle epoch checks reject stale proposals during restart. In-place restart resets progress/required IDs; scene replay reconstructs a clean objective and one marker/round callback.

## Objective-aware enemies

Elimination retains milestone-4 tactics. Other objectives add at most nine zone candidates to the existing bounded search, before combat rings. Extraction adds up to two hero-to-exit intermediate interception points. Candidates still require real affordable routes, occupancy checks and shared command validation. Position utility rewards getting near the zone/exit by an editable default **5 utility points per metre**; offensive opportunities retain existing damage/defeat/healing values. Diagnostics show a separate objective contribution. One movement and one action attempt per enemy turn, post-move reassessment and bounded recovery/cancellation remain unchanged. This is a public-state positional heuristic, not coordinated interception or path prediction.

## Environment and review

The existing ruined-courtyard kit now includes nine additional original saved triangle meshes: fountain, statue, facade, bench, barrel, crate, broken cart, cracks and leaf litter. Fountain/statue blockers have matching exported colliders. Solid dressing props are beyond the inaccessible arena boundary; flush ground marks and vegetation have no collision/navigation contribution. Architectural clusters avoid overlapping exterior bounds. Large scenery uses existing reversible occluder fading, now also protecting the objective centre.

`detail_density`, `vegetation_density` and `rubble_density` default to 1 (0–2). They only affect the salted cosmetic RNG stream. Repeated ground/foliage/fragments use shared meshes/materials and MultiMesh batches; small props do not cast shadows. Opaque shader vegetation sways subtly; no transparent particle system or extra dynamic lights were added. Ground detail remains below paths and target indicators. Editing density cannot change spawns, obstacles or objective placement.

Editable art source: `assets/courtyard/source/courtyard_detail_source.gd`. Rebuild with `Godot_console.exe --headless --path . --script res://tests/build_courtyard_details.gd`. The nine meshes add 14–384 triangles each; exact counts/classification are in `assets/courtyard/details_manifest.json`. All art is original, with no third-party downloads or attribution dependency. See the kit README for materials, masks and older sources.

Reproducible showcase: launch with `-- --seed=7`, choose any preset/objective, and orbit at tactical zoom. Automated `tests/objectives_review.gd` captures all presets at three angles; `-- 1080` selects 1920x1080, `-- showcase` skips full bot playthroughs. `tests/run_regressions.ps1` includes objective timing, generation (90 seeds), tactics, playthrough and five-cycle replay checks. See `../verification/OBJECTIVES.md` for what actually ran and remaining limitations.

