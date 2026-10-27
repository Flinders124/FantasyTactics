# Faction tuning

`definitions/factions/*.tres` owns faction descriptions, introduction stage, regular IDs, elite ID, two regular composition templates, elite supports and budgets. Edit these resources in Godot without changing the catalog. Regular templates are ordered: expensive later entries may be omitted when the remaining budget is spent. Keep their first two entries affordable under the lowest budget. Elite support lists should begin with a cost-one troop so every encounter has at least two opponents.

Easy/Standard/Hard composition budgets are 3/4/5, with one additional point from stage 2. Elite budgets have a minimum of 4 to guarantee one escort. Regular troops cost 1 or 2; elite leaders cost 3. Rosters have 2–4 regular enemies, or an elite and 1–2 supports, and never exceed four enemy spawns. Difficulty's existing stat multipliers apply independently. The base troop health is 10–19, elite health 23–25; every base attack remains 4 damage. These restrained values target the existing two-hero party.

Ashfang introduces at campaign stage 0, Hollow at 1, Verdant at 2. Elite definitions introduce at stage 3; campaign orchestration decides elite opportunities from stage 3 and requires one on final stage 4. Catalog generation deliberately also supports explicit custom battles of every faction at every stage.

Each faction has melee, defender, ranged and support/caster units and one elite. Existing melee/ranged/support/spellcaster profiles retain the established bounded query limits. The three elite abilities are editable under `definitions/abilities/elite_*.tres`: ground targeting, 8 m range, 2.5 m radius, two-turn cooldown, 4/5 damage and all-faction damage. Chieftain also carries Power Strike, Castellan Crippling Shot, Grovekeeper Mend. Existing AI uses the equipped abilities; telegraph resolution is managed by combat.

`FactionCatalog.choose` and `roster` use independent seeded local RNG streams, preserving replayable composition without perturbing arena generation. `EnemyCatalog.VERSION` remains 1 and legacy `raider`/`sentinel` lookups keep old encounter codes working. Its `ids()` lists only the fifteen new IDs.

Run `Godot --headless --path . --script res://tests/faction_tests.gd` for identity, role, legacy, seed, spawn count, budget, editable-template and elite ability checks.

Support introductions: Ashfang Shaman stage1, Hollow Warden2, Verdant Tender3. Initial Ashfang stage0 avoids support. Initial 4/5/6 budgets produced two immediate generic-bot Easy defeats; reduced to3/4/5 before final regression. Balance remains provisional.
