# Combat presentation implementation

The Lantern Oath presentation remains a consumer of confirmed CombatController events. No VFX callback applies damage or unlocks an action.

`CombatController._publish_event` → sequence/identity gate in `CombatPresentation._on_event` → `_present_oath` / existing labels and sound queues → `oath_combat_fx.gd` cached burst pool and animated weapon ribbons.

`CharacterVisual.weapon_landmark`, `weapon_edge` and `emission_point` transform mesh-source landmarks through the authored skin joint. They do not modify gameplay AttackOrigin / TargetPoint markers. Basic attacks remain instant-hit; ranged visuals are resolved-path afterimages at the confirmation frame.

The new renderer retains 32 burst nodes and caches nine angular meshes. At most eight ribbons retain eight recent edge samples each. Cosmetic priorities can evict low-priority bursts; authoritative warnings and targeting remain independent. Low quality halves area decoration. Reduced effects clear/suppress bursts and ribbons. Existing tracer, glyph, blast, text and audio caps remain bounded. Reset/shutdown clears active effects and camera impulses while the sequence watermark rejects stale events after restart.

F10 → Camera → Impact shake supports 0–1. Reduced camera motion disables impulses. Displacement affects only the Camera3D child, with a short envelope; controlled yaw, pitch, zoom and rig position remain unchanged.

Open `dev/combat/showcase.tscn` and run F6 to inspect twelve real-command fixtures. Replay prepares an elite warning; click again to resolve at the caster’s next turn. The quarter-speed switch is inspector-only. The scene and tests are excluded from release exports.

`tests/combat_fx_tests.gd` checks command acceptance, confirmation timing, real grip/joint transforms, stale delivery, camera accessibility, exact warning radius, bounded priority/lifetime behavior, combat-text separation and reset cleanup. It is included in `tests/run_regressions.ps1`.

Existing audio is reused; there are no new recordings or dependencies. Specialist VFX texture/audio refinement and subjective listening review remain. Full review captures, performance measurements and rollback/source archives are delivered separately with Milestone 4. No Milestone 5 work is included.

Roster integration detail: non-bow ranged actors (including the Hollow Castellan and Verdant Tender) use magical heads/cues and the existing Cast clip. Their old fallback visual-role tags do not classify them as archers. The Tender emits from its authored staff crown. Fireburst keeps its ember silhouette when cast by another existing class, including Scout. No attack definitions or timings were changed.
