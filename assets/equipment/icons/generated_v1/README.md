# Equipment inventory art — starter set v1

Twelve original AI-generated UI illustrations created with the built-in image_gen tool on 2 November 2026. No third-party stock photographs, downloaded asset packs or external fonts used. Full prompts, source provenance, hashes, alpha bounds and dimensions are recorded in manifest.json. Existing Lantern Oath steel/copper/teal art direction supplied the palette.

| Category | Common | Rare | Legendary A | Legendary B |
| --- | --- | --- | --- | --- |
| Sword | common_sword.png | rare_sword.png | legendary_sword_a.png | legendary_sword_b.png |
| Helmet | common_helmet.png | rare_helmet.png | legendary_helmet_a.png | legendary_helmet_b.png |
| Torso armour | common_armour.png | rare_armour.png | legendary_armour_a.png | legendary_armour_b.png |

All originals are 1254x1254 RGBA PNGs with real transparent backgrounds. Files preserve generated pixels/alpha; no raster editing or downscaling was performed. Some originals contain very faint low-alpha residue outside the main silhouette; the manifest records raw and alpha>=128 bounds separately. Core silhouettes are not clipped. A final artist edge-cleanup/small-size review may still be appropriate. Rarity labels and frames are not baked in: use textual rarity/slot labels in the interface.

Legendary A: Lanternward sword, Beacon Crown helmet, Beacon Cuirass armour. Legendary B: Thornbound Oath sword, Oathkeeper Visor helmet, Duskward Mantle armour. Names identify art variants, not new gameplay definitions or balanced item statistics. Each has distinct geometry/motifs rather than only a recolour.

This is 2D inventory/shop artwork. It does not replace equipped 3D character meshes, implement rarity rules or wire the proposed new shop. Manifest equipment_type is an art category, not the current saved slot key.

When integrating, bind stable art IDs to item definitions/owned variants and persist the selected legendary variant; do not change pictures on page opening or loading. Keep shared gameplay stats unless deliberately designing different items. Retain the full-resolution originals and use Godot texture import limits for suitable runtime UI sizes after review.

Validation: twelve files decoded; square dimensions, RGBA and alpha extrema0..255 checked; core silhouette bounds remain inside the canvas. Original generated images were visually reviewed. Faint low-alpha residue is disclosed rather than falsely claiming every nonzero pixel has margin. Godot import evidence is under verification/equipment-art; no combat/save tests are claimed for these asset-only additions.
