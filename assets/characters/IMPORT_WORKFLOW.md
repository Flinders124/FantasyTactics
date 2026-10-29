# Lantern Oath character asset contract

The game loads `assets/characters/oath_models/<visual_id>.glb` for the complete existing roster. `CharacterVisual` finds its Skeleton3D and AnimationPlayer and applies the existing Lantern material shader. The old six GLBs and faction kit remain as a comparison/fallback path; set `art_comparison` only in development to request the old path. Normal gameplay uses the dedicated exported models.

## Rebuild and inspect

Run `python assets/characters/source/build_characters.py --representatives` to compile Knight, Ashfang Raider, Hollow Gravebound and Verdant Thornblade first. Inspect these in the courtyard and `dev/characters/showcase.tscn` (F6). Then run the script without arguments to compile all 21 existing visual IDs. Source and output are deliberately separated: mesh generation and IK run offline, never per frame in combat.

The source contains explicit cross-section profiles, facial landmark panels, equipment silhouettes, skinning rules and pose targets. It uses Python's standard library and the existing `build_roster.py` modelling math/rig helpers. This is an editable technical low-poly pipeline, not a sculpting package. It does not replace the need for a character artist to author production topology and unique faces.

## Import artist-created replacements

1. Open a roster GLB in Blender, Maya or another glTF-capable DCC. Preserve its bind pose and transform conventions. Replace or refine the mesh, UVs and skin weights there; export a binary glTF to the same `oath_models` filename. The build script is optional for artist-created replacements: do not run it over hand-edited GLBs unless those edits have been incorporated into the source or safely versioned.
2. Use metres, Y up, front -Z, unit root scale, feet at Y=0. Keep overall crests/antlers within about 2.2 m so the existing camera and health anchors remain appropriate. Physical collision and selection remain owned by CombatUnit, not imported meshes.
3. Preserve the shared hierarchy (`root`, `hips`, `spine`, `chest`, `neck`, `head`, L/R `arm`, `forearm`, `hand`, `thigh`, `shin`, `foot`) for reusable clips. Existing generated models use 18 joints. Do not export root motion into the actor transform.
4. Include named `Idle`, `Walk`, `Run`, `Attack`, `Cast`, `Hit`, `Death` clips. All animated joints have complete transform tracks (permanently static joints remain at their bind pose) so transition blending does not retain a prior death/cast. Idle/walk/run loop; death holds its final pose. Animation tracks must never call damage, spend resources, move colliders or unlock combat.
5. Body and equipment are skinned together. R-hand bind pivot is (0.46,0.88,-0.04), L-hand is (-0.46,0.88,-0.04). The handle runs through the curled fingers at about local (0,-0.04,-0.025). Staff secondary grip is 0.21 m above the primary grip; the offline pose solver maintains both contacts. Fit the mesh to the rig rather than placing a floating object beside a fist.
6. Use distinct skin/cloth/metal/leather/trim/hair materials with controlled roughness. Current models use 7–8 shared-style surfaces, no texture maps, indexed geometry, and about 3.3–4.3k triangles. These are observed prototype costs, not a hardware certification. Optional textures or added detail require new profiling.
7. Let Godot reimport, then use the inspector from front/side/rear/tactical angles. Inspect all seven clips and transitions, especially hands, shoulders, knees, robe hems and the floor. Run `tests/character_tests.gd`, `tests/authored_character_tests.gd`, and `tests/faction_visual_tests.gd` plus the standard regression runner before replacing a release asset.

## Runtime timing

Combat damage remains authoritative immediately when a command is accepted, and the existing 0.22 s resolution lock remains unchanged. Attack/cast clips therefore begin in contact/release poses and provide short, interruptible recovery (0.38/0.45 s). They do not add a fake delayed hit event or hold a turn until a clip ends. Hit is 0.26 s; death is 0.85 s. Walk has a 1 m stride per 0.5 s cycle; Run has a 1 m stride per 1/3 s cycle. CharacterVisual scales playback from actual displacement without changing movement speed, and uses Run above 2.8 m/s.

## Art rules and remaining artist work

Keep the Milestone 1/2 blue/teal/copper/cream palette and graphic lighting. Watch heroes use crest/shield, hood/quiver, swept hat/two-handed staff, and ivory layered robe/mace silhouettes. Ashfang uses a broad upper body, tusks, horns and cleaver profiles. Hollow uses visible ribs, cheek hollows, funeral crowns and rear shrouds. Verdant uses forked antlers, leaf shoulders and split root feet. Equipment and crown/tabard differences distinguish the five roles within each faction.

Current geometry is authored through code profiles and exported as skinned assets. It is not professionally sculpted production art. Dedicated artist work remains: truly unique facial sculpts and hair, more sophisticated joint topology, authored cloth folds/secondary motion, character-specific acting and weight transfer, bowstring draw/release deformation, release/hide logic for the held inspection arrow, directional hit reactions, and improved collapse choreography beyond the verified floor bounds. There is no facial rig, ragdoll, cloth simulation or automatic LOD. These omissions are intentional limits of this implementation, not features claimed as complete.


## Approved Milestone 4 additions

Run `python assets/characters/source/build_roster_v4.py` to build only Recruit,
Aegisbearer and Chainbinder; `--roles recruit` can limit the additive build.
This never rewrites the existing 21 characters or their v3 manifest. The editable
profiles subclass the same anatomical shell/panel, skinning, 18-joint rig and
seven-clip exporter. `manifest-v4.json` records the three added assets only.

Recruit wears a plain teal cloth tunic, cream collar and leather boots/belt with
a basic short sword and no shield. Aegisbearer has a broad rectangular tower
shield with copper stone marks, short spear, low angular helmet and broad plate
pauldrons. Chainbinder has asymmetric lean armour, a hooked polearm, individual
open belt-chain links and chain gauntlet; Cast has a dedicated haul/recovery pose.
No Hexweaver or Arbalist content is included.

`scenes/character_showcase.tscn` shows the Recruit and all six approved advanced
Watch classes together. Portraits use the same visual IDs and GLBs. UI SVGs use
the existing cream outline style. `tests/roster_character_tests.gd` checks import,
rig/clips and survival presentation; offline source checks are in
`assets/characters/source/verify_roster_v4.py`.

Survival presentation reuses the final shared collapse pose for DOWNED and
STABILISED without rewriting existing class animations. `set_survival_pose`
accepts named life states and a carrier boolean; a carrier uses a supporting
forearm brace. Body attachment/position, tint/markers and authoritative rescue
rules remain the caller's responsibility. There is no bespoke carried-body clip,
physics chain, ragdoll or gameplay callback in an animation.
