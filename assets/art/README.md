# The Lantern Oath - permanent Option C art

Option C is the default production presentation. F5, skirmishes, tutorial encounters, campaign battles, portraits and the headquarters camp use this style without opening the development reference.

## Runtime sources

- `scripts/lantern_art.gd`: palette, local material creation, hero/faction treatment, decorative pointed arch, camp theming and shared light rig.
- `assets/art/lantern_surface.gdshader`: opaque graphic bands, restrained material highlights, actor edge lift and optional foliage movement.
- `assets/art/lantern_fade.gdshader`: transparent sibling used only while foreground scenery obscures a unit. Ordinary materials remain opaque.
- `assets/art/lantern_shapes.gd`: small original faceted mesh builders used for armour and the decorative arch.
- `CharacterVisual.load_role`: applies C once to each loaded model. The historical development comparison explicitly opts out before applying its own A/B/C variants.
- `CourtyardKit`, `CourtyardDressing`, `CourtyardAtmosphere`: production courtyard materials, decorative arch and lighting.
- `CharacterPortrait` and `CampOverview`: use the same style and light rig.

No runtime production asset depends on `dev/art_direction`; that directory remains excluded from Windows export.

## Art rules

Blue stone `#556D83`, paving `#50677E`, pale teal edges `#85A5AB`, ground `#273B50`, copper foliage `#C57655`, darker fallen material `#754B53`, brass `#EFB875`. Warm key `#FFD0A1`, cool ambient `#A2BAD0`, non-shadow-casting fill `#9ECBDE`. Direct light uses graphic value bands; materials avoid high-frequency detail and screen effects.

Warden: teal cloth and pale teal steel. Arcanist: vermilion cloth with warm crystal accents. Scout: muted teal clothing. Dawnkeeper: ivory cloth with shared teal metal. Ashfang remains crimson/copper, Hollow parchment and cold blue/mint, and Verdant lighter teal bark and pale leaves/eyes. Selection rings, path legality colours and the readable dark HUD remain independent of world shading.

Model proportion changes are below CharacterVisual: wider silhouettes, larger head geometry around existing bind joints, slightly stronger arms, original skeletons and six clips. The visual root, collision/picking capsule, attack markers, movement distances, stats and action timing stay unchanged. Warden gains angular pauldrons and a lantern badge; the Arcanist gains a faceted clasp. Imported GLBs are not overwritten; cloned visible mesh resources retain their skin and source surface materials beneath local shader overrides.

Courtyard blockers keep their original mesh geometry and collision resources. Paving heights, seeded placement, navigation settings, masks and gameplay RNG are unchanged. The newly pointed arch is a decorative exterior landmark only. Native meshes retain their source files and receive production material overrides, so rebuilding old courtyard art does not switch the live game back to its old palette.

## Technical limits

Godot 4.7.2 Compatibility / OpenGL; no new package, texture pack, GI, SSAO, volumetric fog or renderer switch. This rollout styles the existing game; it does not replace every prop with a bespoke sculpt or overhaul existing animation and combat effects. The historical reference courtyard remains a small hand-composed benchmark rather than a replacement for procedural battlefield layouts.

The existing project has ObjectDB/resource-in-use diagnostics on some automated teardown paths. Those warnings are recorded separately from assertion results in the rollout verification report.
