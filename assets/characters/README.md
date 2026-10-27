# Original fantasy roster

Six original, equipped, skinned glTF 2.0 characters replace the capsule/cone visual layer. No third-party art, textures, animation packs, modelling plugins or online services are required. Blender was not installed in the checked local locations; the editable source is a dependency-free procedural modeller/exporter, rather than a `.blend` file.

| Asset | Appearance | Triangles | Material surfaces |
|---|---|---:|---:|
| `models/knight.glb` | Warden: blue tabard, plate armour, crested helmet, sword and heraldic shield | 1,818 | 7 |
| `models/ranger.glb` | Scout: forest clothing, hood, leather bracers, recurved bow and arrow-filled quiver | 1,708 | 7 |
| `models/mage.glb` | Arcanist: violet robe, pointed hat, gold trim and crystal staff | 1,774 | 8 |
| `models/cleric.glb` | Dawnkeeper: ivory vestments, armour, circlet, sacred chest emblem and flanged mace | 1,934 | 7 |
| `models/raider.glb` | Green-skinned hostile fighter: red cloth, dark plate, horned helmet, shoulder spikes, sword/shield | 1,824 | 7 |
| `models/sentinel.glb` | Green-skinned hostile archer: plum hood/cloak, leather harness, bow and quiver | 1,708 | 7 |

## Editable source and regeneration

`source/build_roster.py` contains the original anatomy/clothing ring profiles, curved sweeps, bevelled equipment outlines, palette, shared rig, skin weights and animation curves. Run from any directory:

```powershell
python path/to/assets/characters/source/build_roster.py
```

Only Python 3's standard library is used. It writes the six GLBs and `manifest.json` deterministically beside this document. Reimport in Godot afterward. GLBs also contain editable meshes, materials, skin and animations and can be imported into a DCC tool later. Source files are authoritative: edits made only to exported GLBs will be overwritten by regeneration.

## Rig, materials and conventions

All roles use the same 18-joint humanoid hierarchy: root, hips, spine, chest, neck, head; bilateral upper arms, forearms, hands, thighs, shins and feet. Shaped meshes use rigid joint weights for a deliberately faceted cutout-armour style. Equipment vertices are weighted to hand joints; quivers and capes to the chest. There are no gameplay collision shapes in the imported assets.

Units are metres, Y-up, with a floor-level origin and local forward **−Z**. Body height is approximately 1.8 m; hats/horns reach roughly 2.13 m. Opaque flat-colour PBR surfaces provide steel, cloth, leather, skin, hair, gold, light details and optional emissive crystal. No image textures or alpha sorting are involved. Godot Compatibility renderer was used for review.

Imported surfaces are flat shaded and double sided to keep thin clothing/equipment silhouettes readable. Each character is one skinned mesh with 7–8 surfaces; four battle units total roughly 7,200 triangles, excluding existing effects/UI. The models share rig structure and palette conventions; glTF exports are self-contained and therefore duplicate their small material/mesh resources across different roles. Repeated instances of one role share its imported resources through Godot's loader cache.

## Clips and integration

Every model contains `Idle` (2.4 s loop), `Walk` (0.8 s loop), `Attack` (0.65 s), `Cast` (0.85 s), `Hit` (0.32 s), and `Death` (0.85 s, held). Archers have an aim/draw/release motion with a counter-rotated bow hand; fighters swing their weapon and raise their off hand. Mage basic attacks use `Cast` in combat. All roles can cast because existing abilities include healing and magic on several weapon roles.

`UnitDefinition.visual_id` selects the model independently of balance. `CharacterVisual` owns only presentation: actual displacement selects Walk, stopped movement returns to Idle, and facing rotates only the visual root. A subsequent move can interrupt an unfinished action pose. Committed combat actions trigger Attack/Cast, health loss triggers Hit, and the once-only death path triggers Death. Restart stops playback, resets all bone poses and returns to Idle without adding model instances or signal connections. Imported clips contain no method/audio/damage tracks. CombatController's existing resolution timer remains authoritative and does not wait for animation completion.

Collision, picking capsule, floor anchor and gameplay attack/target markers remain on CombatUnit at their existing locations. This preserves range/obstruction rules. The 0.8 m attack marker represents the torso/hand-height gameplay origin, not an animated staff-tip socket. Health bars now anchor at 2.4 m to clear the Mage hat. Active/hover/target rings remain independent of the rig.

Party cards render the exact equipped models in isolated SubViewports with input disabled. They are not separate painted portraits. The portrait camera preserves a fixed aspect at both supported resolutions.

## Review

Open `scenes/character_showcase.tscn` and run it with F6. **1/2/3/4** select front/side/rear/tactical views. **Q/W/E/R/T/Y** play Idle/Walk/Attack/Cast/Hit/Death; **Space** cycles clips. Changing a clip safely resets the previous pose and retains the selected view.

The game controls remain unchanged: **M** Move, **T** Attack, **1–3** abilities, **E** End Turn, **Escape** cancel; right-drag orbit, middle-drag or WASD/arrows pan, wheel zoom, **F** focus active. Normal startup still uses title → two-unit party selection → generated encounter.

## Scope and limitations

This is a cohesive, very low-poly roster with simple reusable skeletal motions, not photorealistic characters. Clothing/capes use rigid weighting, fingers do not animate independently, bows have a static string and there is no foot IK, facial animation, cloth physics or ragdoll. Sword grips, bow grips and equipment remain skinned to their hands; there is no equipment swapping. Close-up cinematic deformation is outside the chosen tactical level of detail. The full-arena opening view makes every unit small; existing focus and zoom controls provide closer inspection without automatic camera tracking.

All geometry, palettes and animation curves in this folder are original project assets; see `LICENSE.txt`. No third-party attribution is required. See [the verification record](../../../verification/CHARACTER_VERIFICATION.md) for the actual validation performed.
