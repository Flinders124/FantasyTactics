# Faction models

All fifteen enemy visual IDs now use original faction anatomy, rather than the friendly or generic enemy body with extra equipment. These are code-authored faceted 3D models, built at load time; no external textures or modelling packages are needed.

- Ashfang: broad barrel chest, heavy jaw, layered hide kilt, thick limbs and boots, tusks and jagged shoulder armour.
- Hollow: exposed spine and separated ribs, narrow paired leg bones, skull and death mask, tattered rear shroud and cold iron equipment.
- Verdant: tapered split-bark torso, root toes, narrow wooden limbs, leaf growth, pointed head and forked antlers.

Each faction has five role variants. Infantry carry blades, guards tall shields, archers complete bows and arrows, supports staves, and leaders crowns and mantles. The Grovekeeper also carries a branch staff. Existing faction colours and role-specific equipment remain in FactionVisualKit.

## Architecture and editing

FactionCatalog and the resources in definitions/factions choose encounter rosters. EnemyCatalog resolves UnitDefinition resources, including their visual_id. CombatUnit owns health, collision and selection; CharacterVisual only owns appearance, facing and animation playback. CombatController remains authoritative for action resolution.

CharacterVisual loads the appropriate original GLB to obtain its shared humanoid skeleton and six animation clips. FactionVisualKit creates local faction and skin materials and calls FactionBody.build, which hides the imported body, clothes and weapons, then creates the faction anatomy. Role equipment is built afterward. All visible new meshes use BoneAttachment3D, so they follow the same animation tracks. Generic enemies and friendly characters still use their original GLBs.

Edit scripts/faction_body.gd for body profiles and complete base weapons. Edit scripts/faction_visual_kit.gd for faction details and role equipment. Dimensions are metres, Y-up, facing -Z. Anatomy uses the existing rest joint positions; gameplay scale, floor origin, collision, picking and range remain unchanged. No animation contains gameplay callbacks.

These are procedural models, not new GLB exports. They intentionally retain the original simple rigid-joint animation style. Thin layered surfaces are double sided, and the shared rig limits how far body proportions can vary. Original hidden GLB meshes remain loaded alongside the skeleton.

## Review

Open scenes/faction_showcase.tscn and run with F6 to inspect all fifteen units. Keys 1-4 select front/side/rear/tactical views; Q/W/E/R/T/Y select Idle/Walk/Attack/Cast/Hit/Death, and Space cycles clips.

Run the anatomy, equipment, clip and death/reset integration checks with:

    godot --headless --path <project> --script res://tests/faction_visual_tests.gd
