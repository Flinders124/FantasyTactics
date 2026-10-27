# Encounter setup and difficulty

F5 → New Encounter opens the existing four-hero screen. Select exactly two heroes, battlefield, objective and difficulty. Enter an optional unsigned decimal seed (0–4294967295), or leave it blank to use the displayed random draft seed. **Randomize** chooses and displays another seed. The summary shows the actual party, settings and adjusted enemy health/basic damage before Start. At 720p the settings sidebar scrolls to sharing controls; all four cards and Start stay visible. Back and New Encounter preserve the draft.

## Initial tuning (provisional)

All objectives use the following explicit two-unit rosters. We retained two enemies because generation, validation and interface scheduling were established around four units; adding a third enemy would require broader work unrelated to modest difficulty tuning.

| Difficulty | Roster | Enemy HP multiplier | Offensive damage multiplier | Resulting HP | Basic damage each |
| --- | --- | --- | --- | --- | --- |
| Easy | Raider + Raider | 0.85 | 0.85 | 14 + 14 | 3 |
| Standard | Raider + Sentinel | 1.00 | 1.00 | 16 + 18 | 4 |
| Hard | Raider + Sentinel | 1.10 | 1.15 | 18 + 20 | 5 |

Rounding is **floor(base × multiplier + 0.5)**, minimum **1**, independently for health and every offensive damage value. Power Strike is 6 / 7 / 8 damage on Easy / Standard / Hard. Crippling Shot remains 2 and Fireburst remains 3 after integer rounding (Sentinel is not in the shipped Easy roster, but the adjustment function supports it). Mend stays 6 healing. Slowed remains two future affected turns at 50% movement. Hero stats, initiative of each base enemy type, movement, one shared action, cooldowns, objective requirements, range and obstruction rules do not scale.

| AI limit per decision | Easy | Standard | Hard |
| --- | --- | --- | --- |
| Accepted positions, including current | 16 | 24 | 32 |
| Raw candidates | 32 | 48 | 64 |
| Path queries | 32 | 48 | 64 |
| Shared action-validator calls | 512 | 768 | 1024 |
| Ring directions | 6 | 8 | 10 |

Two endpoint evaluations per frame, role scores, public-state access, one movement/one action attempt, one bounded recovery replan and authoritative completion/cancellation stay unchanged. Counts refer to shared validator invocations, not individual physics rays. Command revalidation is outside planner counters. Standard's adjusted resource content matches the existing base definitions exactly. Hard searches more positions; it does not receive extra actions, movement, range or information. Profile behavior is described in `TACTICS.md`.

Edit `definitions/difficulties/easy.tres`, `standard.tres` and `hard.tres`. DifficultyDefinition stores ID/name/description, configuration version, per-objective roster IDs, modifiers and optional AI caps (zero keeps the equipped profile's baseline). Each roster has exactly two existing catalog IDs: `raider` and/or `sentinel`. An optional alternate roster can be configured; selection uses its own seeded RNG (`seed XOR 0x524f53544552`). Shipped definitions have a single fixed template per objective, so changing the battlefield seed changes terrain, not the default roster. No composition is selected from arbitrary resources or new enemy classes.

## Runtime safety and replay

EncounterConfiguration stores selected heroes, generator/preset snapshot (version 2), objective snapshot, difficulty snapshot (version 1), original seed, accepted layout/attempt, frozen unadjusted enemy definitions/IDs and roster version 1. EnemyCatalog contains only the two existing roles/assets. Configuration snapshots deep-copy enemy graphs and tuning. DifficultyDefinition derives local enemy UnitDefinition/AttackDefinition/AbilityDefinition/profile copies once during spawn. Healing/status definitions are never scaled. Adjusted offensive descriptions and previews use actual values.

In-place restart resets units against their already-derived definitions. Retry rebuilds from frozen **unadjusted** bases, applying modifiers once. New Battlefield retains party/preset/objective/difficulty, chooses a new seed, clears the accepted attempt/layout and resolves the configured roster again. Change Setup restores the previous selections and accepted configuration; editing a field clears cached layout/attempt while retaining other imported tuning. Main Menu retires motors, AI, objectives, effects and scene UI; only a definition-only draft remains.

Result screens use authoritative outcome snapshots: difficulty, objective reason, completed rounds, round of termination and defeated hero/enemy names. “Completed rounds” excludes a partial final round. Internal `change_party` transition identifiers remain compatible with older harnesses, but the player-facing button is **Change Setup**. No rewards or progression are present.

## Encounter codes

**Copy code** in setup fills/selects a text field and attempts native clipboard copy. **Import** validates pasted data before replacing the draft. The combat **Copy code** control also opens a selectable-text panel; Escape/Close dismiss it. A code represents setup only: never current health, positions, movement, action availability, statuses, cooldowns or combat progress. Import starts a fresh encounter.

Format: `FT1.<base64url(zlib JSON)>.<8 hex checksum>`. Typical shipped configurations are about 1,000 characters. Maximum input is 8,192 characters; decompressed JSON is bounded to 32,768 bytes. Exact whitelisted schemas validate scalar/vector types, IDs, versions, seeds, attempts, dimensions, prop heights, densities, modifiers and query limits. No arbitrary file paths, Resource loading or object/variant deserialization are accepted. The checksum detects accidental corruption; it is not authentication.

Codes contain generator/objective/difficulty settings snapshots, resolved roster IDs, accepted attempt (0 before generation), engine version and hero/enemy definition fingerprints. They reconstruct a prepared layout by the same deterministic attempt without embedding geometry. A fallback's accepted attempt is preserved too. Different engine/content/generator versions are rejected with readable feedback instead of silently changing initial stats/layout. Codes require matching base unit content; they are not a migration format for future balance changes. Bump format/definition versions when making incompatible generation/tactics/content changes.

Gameplay placement, roster choice and dressing have separate RNGs. Audio/effect/global random calls cannot change roster/layout. Modifying decoration density leaves gameplay geometry unchanged.

The automated Windows runtime could not open the native clipboard. Selectable text, generation/import, code modal and UI isolation were verified with native-copy calls disabled in the harness. Native Ctrl+C/Ctrl+V transfer still needs a normal desktop check; production controls attempt it by default and keep the selectable code available. No clipboard access was claimed as passing.

## Verification and next milestone

Run `tests/run_regressions.ps1 -Godot C:/path/to/Godot_console.exe` (the two generation matrices have bounded longer watchdogs). Focused scripts: `difficulty_tests`, `difficulty_generation_tests` (135 settings/seeds plus six hero pairs), `difficulty_flow_tests` and `difficulty_encounter_tests`. `difficulty_review.gd` renders both resolutions, selectable sharing/import, full difficulty encounters, and restarts during effects/planning (`-- 1080` for 1920×1080). Reports/screenshots: `../verification/DIFFICULTY.md`.

Tuning is provisional. Bot outcomes demonstrate execution and broad trends, not human fairness or universal difficulty ordering across every party/objective. Human playtesting and long-duration/minimum-spec performance checks remain necessary. The next milestone is **tutorial and usability**, including teaching objective timing, seed/code sharing and setup choices.
