# Opening Campaign, Headquarters Growth and Equipment — Proposed Design

Status: approved for full implementation by the user, 2 November 2026. Execution plan and evidence are recorded separately.

## Agreed direction

Extend the opening/pacing milestone with purchased headquarters squad-capacity upgrades, level-gated equipment slots, visible camp growth and a periodic premium trader. Reuse the current Armoury, Supplies, inventory instances, camp overview and transactional campaign saves. Preserve individual initiative, free movement, one action per turn, class compatibility and permanent companion identities.

## Commander’s Tent and deployment

The current Commander’s Table becomes the Commander’s Tent interaction. Keep campaign history accessible within it and through existing navigation. Add two sequential, permanent-per-run purchases:

| Upgrade | Proposed availability | Proposed price | Effect |
| --- | --- | --- | --- |
| Field Command | After first victory | 20 Supplies | Maximum deployed party rises from 2 to 3 |
| Expanded Command | After second victory and Field Command | 30 Supplies | Maximum deployed party rises from 3 to 4 |

Costs and prerequisites remain editable; these are initial tuning proposals. Deploy any number from two up to purchased capacity, not a compulsory full squad. Injured/dead/recovering people retain existing rules; capacity purchases never create heroes or extra actions. Preserve recruitment-reserve protection.

Support variable campaign parties end to end: configuration validation, encounter codes, clear connected spawn positions, combat IDs, initiative/HUD, results, XP, injuries, retreat, saves and interrupted-mission recovery. Extraction requires every originally deployed companion alive at safety, including carried companions. Existing skirmish/tutorial defaults remain unchanged for this campaign-focused pass.

## Visible camp progression

The purchased command tier determines presentation, not a separate construction simulation:
- Tier 0: current modest encampment and commander’s shelter.
- Tier 1: larger command tent, improved map table/banner, an extra sleeping shelter and organised stores.
- Tier 2: reinforced command pavilion, more companion shelters and training/armoury dressing, improved paths and restrained lantern placement.

Reuse current camp/courtyard assets and original simple additions as necessary. Changes must be apparent at normal overview zoom, deterministic after loading and compatible with reduced motion/effects. Keep destination labels, camera framing and click areas readable. Camp dressing does not affect battlefield generation or combat geometry.

## Permanent camp shop and equipment

Turn the current Armoury into a clearly presented permanent equipment shop: a merchant counter/workbench, displayed weapons and armour, item cards, prices and a basket/owned-stock presentation consistent with the existing camp art. Reuse available meshes rather than introducing a separate explorable shop scene. The Armoury handles browsing and purchasing; it does not equip items or automatically select a recipient. Purchases enter the shared campaign inventory. The visiting trader uses the same purchasing pattern for its premium stock.

Move equipment management to the individual companion character screen/dossier, reached from the roster or companion tents. Show the actual character model/portrait, adjusted stats and clearly labelled weapon, armour, helmet and accessory slots. Selecting an unlocked slot opens a filtered chooser of owned, class-compatible items for that slot. Show current item, projected stat differences, required level and ownership; confirm equipping, unequip or explicitly transfer from another companion. One owned instance cannot be equipped by two heroes. Equipment on another hero is labelled and requires a transfer confirmation. Locked slots show their unlock level and cannot equip items; an empty unlocked slot explains where to buy compatible gear. Keep fallback gear usable.

Shop cards show price, slot, class/level requirements, owned count and exact effects before purchase. Buying is separate from equipping; show a short confirmation with a link to the relevant character screen where appropriate, without automatically changing loadouts. A sword is a weapon type, not a universal slot forced onto archers or casters.

Proposed levels:
- Level 1: weapon and basic body-armour slots (preserves current baseline).
- Level 2: helmet slot.
- Level 3: accessory slot.
- Level 4: advanced role-compatible items for existing slots.

Levelling unlocks eligibility, never grants purchased items. Show locked slots, required level/class, price, owned/equipped status and exact projected changes. Do not sell a restricted item as immediately usable. Keep existing equipped gear usable when migrating old campaigns; no surprise removal or compounded modifiers. Catalogue size stays curated rather than introducing crafting or a loot-rarity framework.

## Visiting trader — recommended cadence

Arrive after every two committed mission resolutions (2, 4, 6...), including victories, defeats and confirmed abandonment. Tutorials, practice, skirmishes and cancelled setup do not count. This uses mission-based time, never real time.

The trader remains until the next mission is committed, so players can inspect other camp pages and think without a timer. Display next arrival, present stock and departure rule clearly. A visible wagon/stall and trader interaction appear only while visiting.

Freeze three premium offers when a visit is generated, using a separate campaign-seeded trader stream. Refreshing pages, loading, changing equipment or restarting the app cannot reroll/refill stock. Each offer has one available instance. Owned equipment remains after departure; unsold stock departs. Purchases use existing validated inventory ownership and transactional saves.

Premium items should be stronger than comparable ordinary shop items within a modest documented envelope, with proposed initial prices around 30–45 Supplies. Respect class/level eligibility; guarantee useful options for the actual roster where possible. Avoid extra actions, stacking cooldown abuse, resurrection, new currencies or mandatory trader purchases. No trader-only item is required to finish the campaign. Show its exact benefit over current gear, not merely a rarity colour.

## Opening missions and pacing

Improve the first three encounter situations so specialisation and additional squad slots have a clear purpose. Do not simply multiply enemy count to cancel every upgrade. Test two-, three- and four-person deployments and tune encounter composition/rewards deliberately. Measure complete encounter time as well as rounds: extra heroes can increase choices and lengthen rounds even when they reduce rounds-to-victory.

## Save safety and compatibility

Persist purchased command tier, slot eligibility through hero level, owned gear, trader visit ID, frozen stock and sold offers. Continue using safe transactional replacement/backup and duplicate-operation guards. Failed purchases change neither Supplies nor stock. Frozen deployments preserve party size/equipment across interruption. Explicitly migrate known save formats without rerolling missions, removing gear or retroactively charging for upgrades. Trader content changes need stable IDs and supported snapshots/revisions.

## Delivery order

1. Variable party support and Commander’s Tent purchases, with two/three/four-person save, spawn, objective and result tests.
2. Equipment slot progression, a dedicated permanent shop presentation and character-screen slot/owned-item selection, including purchase/equip separation, compatibility, transfer and modifier tests.
3. Trader schedule, seeded stock, ownership and persistence tests.
4. Camp visual tiers/trader presentation, opening encounter tuning and complete integration regression.

Keep the game runnable after each phase. Do not include new factions/classes, campaign construction, crafting or unrelated combat mechanics.

## Required verification

- Every capacity transition, minimum/maximum selection, duplicate purchases and insufficient funds.
- Two/three/four hero spawns, navigation, HUD, initiative, objectives, rescues/deaths and interrupted recovery.
- Slot gates, class eligibility, shop purchases never auto-equipping, character-slot filtering/selection, equip/unequip/confirmed transfer, inventory uniqueness, stat previews and old save migration.
- Trader arrival after resolutions, departure on commit, limited stock, fixed-seed reproduction, reload/repeated-click/write-failure safety.
- Camp tiers and trader visible/readable at 720p/1080p, enlarged UI and reduced effects.
- Representative opening campaigns at each squad size; report human balance as provisional.
- Existing campaign/event/tutorial/settings regressions and available PCK smoke tests. Retain honest reporting of the prior native-shutdown risk and missing Windows EXE template.

## Review requested

Approve or adjust the proposed upgrade prices/unlock timing, equipment unlock levels and two-mission trader cadence before writing the implementation plan. These values are proposals, not implemented changes.

## Latest user clarification

The permanent Armoury must feel like a shop. Purchase items there (or from the visiting trader), then equip them from the individual character screen by selecting an unlocked slot and choosing owned compatible equipment. Preserve this separation throughout navigation and feedback.

## Equipment picture set

The user requested common, rare and legendary inventory illustrations and alternative legendary pictures. Twelve original generated transparent PNG assets are delivered under assets/equipment/icons/generated_v1: common/rare sword, helmet and torso armour, plus two legendary designs per category. Exact prompts and validation metadata are in manifest.json. These are UI illustrations, not new equipment stats or 3D model replacements.

When implementing the shop, show rarity in readable labels as well as styling. Store a stable legendary art variant on the owned item when created; preserve it through equip/transfer/save/load and interrupted deployments. Variations are cosmetic unless an item definition explicitly provides different rules. Shop/trader integration and rarity economy remain part of the proposed implementation, not completed by producing these images.
