# The Lantern Watch — campaign, progression and equipment

Milestones 9–10 connect the existing tactical game through an original fantasy headquarters. Open **New Campaign** from the title, choose Easy/Standard/Hard and a seed, then use **Mission Board → Prepare → select exactly two → Deploy → tactical result → Mission Debrief → Headquarters**. After four successful missions the only offer is **The Last Beacon**; winning it completes the campaign. Failed missions can be followed by another offer while threat permits. **Skirmish** and **Tutorial** remain independent.

**Campaign autosave and Continue are implemented in milestones 11–12.** See [save boundaries, recovery and interrupted-mission policy](SAVES.md). Settings/tutorial completion retain their separate persistence. Run abandonment and application quit ask for confirmation; leaving an unfinished mission counts as failure. This includes committed missions abandoned during generation. A generation fallback remains bounded and uses the existing battlefield systems.

## Headquarters and preparation

The headquarters landing view is now an interactive 3D camp: select its board, tents, training yard or command table to open the existing strategy pages. See [camp controls and editable asset sources](CAMP_HEADQUARTERS.md).

Mission Board compares three frozen offers (one for the finale), with preset, objective, fixed difficulty, enemy HP/basic damage, rewards and ignored penalties. Roster shows the four permanent identities: Warden/knight, Scout/ranger, Arcanist/mage, Dawnkeeper/cleric. Training holds permanent upgrade choices. Armoury buys/equips/transfers owned gear. History records mission consequences and headquarters actions. The top overview shows progress, threat, Supplies and readiness.

Preparation displays roles, abilities, injuries, equipped instance IDs and adjusted stats. Exactly two distinct heroes are required; injured heroes are always eligible. Deployment freezes the configuration and locks headquarters mutations. No free Retry/New Battlefield or Change Setup exists in a campaign. Result and pause/menu routes lead to debrief or a confirmed mission abandonment, never a free reroll. Standalone replay options are unchanged.

Menus use the existing style, fonts, settings, focus outlines and scroll containers. PgUp/PgDn changes headquarters tabs; Tab/Shift+Tab and Enter/Space navigate buttons. F10/P opens the existing settings interface. Combat controls are unchanged. The equipment catalogue reuses the existing role models; items do not have distinct new meshes.

## Exact initial tuning

| Rule | Default |
| --- | --- |
| Successful missions | 5: four normal/recovery victories, then one harder final victory |
| Campaign difficulty | Chosen once; existing Easy/Standard/Hard enemy rules retained |
| Finale | Existing enemy health and offensive-damage multipliers ×1.15, capped at 1.5; existing rounding, roster, action/movement limits and AI retained |
| Threat | Starts 2; bounded 0–10; reaching 10 ends the campaign unless this result is final-mission victory |
| Mission outcome threat | Victory −1; tactical defeat, draw or confirmed abandonment +2 |
| Unresolved offers | Each ignored normal offer +1; recovery and final offers +0 |
| Supplies | Start 30; normal/final victory +22; recovery victory +14; failure/draw/abandonment +4 |
| Experience | Each deployed participant +10, plus +15 for victory; incapacitated participants receive the same XP; resting heroes gain none |
| Levels | 1–4 at cumulative XP 0 / 20 / 50 / 90; excess XP retained, no levels beyond 4 |
| Upgrades | One permanent choice from two at each of levels 2, 3 and 4; choose pending levels in order; no Supply cost or respec |
| Severe injury | Finishing at 0 HP: 3 subsequent mission resolutions |
| Battle strain | Finishing alive at or below 50% health: 2 subsequent mission resolutions |
| Injury penalty | One nonstacking −3 maximum health and −0.5 m movement while injured; repeated injury refreshes to at least the new duration |
| Recovery | On later mission resolution: deployed heroes recover 1 step, resting heroes 2; recovery-mission success adds 1 to every pre-existing injury |
| Herbwarden treatment | 12 Supplies removes one current injury step; once per hero between mission resolutions; explicit confirmation |
| Between battles | Health restored to the next deployment's adjusted maximum; no tactical statuses, cooldowns, action state or movement spending carried over |

Recovery offers appear in the third slot after odd-numbered resolutions (1, 3, …), until the final offer. They use an existing Elimination battle and trade lower Supplies for extra recovery. Normal objectives rotate across the three slots; presets and battlefield seeds come from the dedicated campaign RNG. The board is not regenerated on refresh or preparation/back navigation.

A final victory has explicit precedence over a simultaneous threat cap, even with edited threat tuning. Other results reaching maximum threat produce campaign defeat. A tactical DRAW remains visibly a draw but counts as a failed campaign mission. Extraction still fails when either deployed hero is incapacitated: surviving in the persistent roster does not change tactical objective rules.

## Exact post-mission order

1. Validate the immutable result's version, active mission ID and participant map. Reject an already processed or stale mission ID. Claim it once, clear the active commitment, increment mission resolutions and (on success) victories.
2. Award participation/success XP, derive levels/pending training choices, then award Supplies. Incapacitation never removes participation XP.
3. Resolve every unchosen offer, add its penalty and the selected mission's outcome threat delta, then clamp threat.
4. Recover **only injuries which already existed before this result**, using deployed/resting rates and any recovery-mission bonus. Remove expired injuries.
5. Add/refresh injuries from this result's final health snapshot. New injuries receive their full duration; this result cannot immediately decrement them. One injury penalty applies regardless of duration/refresh.
6. Evaluate campaign completion: final victory first, otherwise maximum-threat defeat. Record the history/debrief. No further offers are generated after an ending.
7. If ongoing, replace the board using the next deterministic decision index. The tactical result screen stays until the player opens Mission Debrief; acknowledging debrief never reapplies rewards or consequences.

## Permanent upgrade choices

All choices are editable Resources under `definitions/campaign/upgrades/`. “Offensive damage” means basic attack plus damaging abilities, never healing.

| Hero | Level | Choice A | Choice B |
| --- | --- | --- | --- |
| Warden | 2 | Stoneguard: +3 maximum health | Keen Edge: +1 basic attack damage |
| Warden | 3 | Surefoot: +0.5 m movement | Kindled Prayer: +2 Mend healing |
| Warden | 4 | Beacon Blade: +2 basic and offensive ability damage | Unbroken: +4 maximum health |
| Scout | 2 | Longbow Craft: +1 m basic attack maximum range | True Fletching: +1 basic attack damage |
| Scout | 3 | Trailwise: +0.5 m movement | Hardened Scout: +3 maximum health |
| Scout | 4 | Hunting Mastery: +1 basic and offensive ability damage | Herbal Lore: +2 Mend healing |
| Arcanist | 2 | Bright Ember: +1 basic and offensive ability damage | Far Focus: +1 m basic attack maximum range |
| Arcanist | 3 | Warded Robes: +3 maximum health | Light Step: +0.5 m movement |
| Arcanist | 4 | Heartfire: +2 basic and offensive ability damage | Swift Invocation: Fireburst cooldown reduced by 1 subsequent owner turn |
| Dawnkeeper | 2 | Merciful Hands: +2 Mend healing | Sanctuary: +3 maximum health |
| Dawnkeeper | 3 | Pilgrim: +0.5 m movement | Resolute Mace: +1 basic attack damage |
| Dawnkeeper | 4 | Dawn Blessing: +2 Mend healing | Quickened Litany: Mend cooldown reduced by 1 subsequent owner turn |

## Owned equipment catalogue

Each hero starts with a unique owned weapon instance and a unique Watch Kit instance (eight instances total). Two slots: role-compatible **weapon** and shared **garb** (armour/accessory). Starter definitions cost 0 and are not sold. Unoccupied slots use familiar base-stat fallback gear, so transfers/unequipping cannot make a hero unusable.

Buying creates one new stable `gear-NNNN` inventory instance and deducts its price once. It is stored until equipped. Equipping removes it from the previous owner, replaces only that slot, and leaves replaced gear in inventory. Transfers between heroes ask for confirmation. There is no selling, item destruction, stack, ammunition or extra currency. Shop previews include the selected hero's upgrades/injury and replace the current slot's modifiers rather than stacking both items.

| Item | Roles | Slot | Supplies | Effect/trade-off |
| --- | --- | --- | --- | --- |
| Broadwatch Blade | knight | weapon | 18 | +1 basic/offensive ability damage; -0.5 m movement. |
| Pilgrim Mace | cleric | weapon | 0 | Familiar starting weapon; base combat stats. |
| Ember Staff | mage | weapon | 18 | +1 basic/offensive ability damage; -2 health. |
| Guardian Mace | cleric | weapon | 16 | +1 basic damage; -1 Mend healing. |
| Kindled Mace | cleric | weapon | 18 | +2 Mend healing; -1 basic damage. |
| Watch Sword | knight | weapon | 0 | Familiar starting weapon; base combat stats. |
| Lantern Staff | mage | weapon | 0 | Familiar starting weapon; base combat stats. |
| Quiet Focus | mage | weapon | 18 | Fireburst cooldown -1 subsequent owner turn; -1 basic damage. |
| Watch Bow | ranger | weapon | 0 | Familiar starting weapon; base combat stats. |
| Reachguard Sword | knight | weapon | 16 | +0.35 m basic reach, +2 health; -1 basic damage. |
| Stoneweave Coat | knight, ranger, mage, cleric | garb | 14 | +3 health; -0.5 m movement. |
| Trail Mantle | knight, ranger, mage, cleric | garb | 14 | +0.5 m movement; -2 health. |
| Trail Bow | ranger | weapon | 16 | +1 m basic range, +0.5 m movement; -1 basic damage. |
| Votive Charm | knight, ranger, cleric | garb | 12 | +1 healing; -1 health. |
| Ash Warbow | ranger | weapon | 18 | +1 basic damage; -1 m basic maximum range. |
| Watch Kit | knight, ranger, mage, cleric | garb | 0 | Familiar starting clothing; base combat stats. |

## Stat integration

`CampaignStats.derive` is used for preparation, equipment projections and the definitions deployed into combat. It builds an independent UnitDefinition and **explicitly duplicates each AttackDefinition and AbilityDefinition**; deep-copying only the containing unit did not detach external Resources in arrays reliably. No catalogue definition, shared status definition or enemy base is mutated.

Sum flat modifiers from **base + learned upgrades + one equipped instance per slot + the current injury**; clamp once. Hero difficulty modifiers are not applied. Enemy difficulty adjustment remains the existing pipeline, with the final-mission factor applied once to its copied difficulty definition.

- Health: round the summed value with Godot `roundi`, clamp 1–99.
- Movement: sum metres, clamp 1–9. Slowed subsequently affects normal turn allocation from this final base; it does not permanently multiply stats.
- Basic damage: base + `basic_damage` + `offense`, rounded/clamped 1–20.
- Damaging-ability magnitude: base + `offense`, rounded/clamped 1–20; healing uses only `healing`, clamped 1–20.
- Basic maximum range: base + `basic_range`, clamped between existing minimum +0.1 m and 12 m. Minimum range and ability cast/melee ranges remain unchanged.
- Cooldowns: only a named `cooldown:<ability_id>` modifier changes the corresponding cooldown, clamped 0–5 subsequent owner turns. Zero cooldown still does not grant another shared action this turn.
- Initiative, collision, navigation clearance, action allowance, status duration, area radius and obstruction geometry are unchanged. All configured health/damage additions are integers; movement/range use metres.

The existing enemy rule rounds `floor(base × multiplier + 0.5)`, minimum 1; offensive ability damage scales, healing/status durations do not. Final multipliers are Easy 0.9775/0.9775, Standard 1.15/1.15, Hard 1.265/1.3225 (health/damage), before existing rounding. Standard non-final battles retain the established baseline.

## Architecture and save/load boundary

- `CampaignDefinition` and its item/upgrade Resources are reusable tuning; default manifest is `definitions/campaign/lantern_watch.tres`.
- `CampaignState` owns four stable hero records, inventory, Supplies, threat, offers, commitment, processed mission IDs and history. Snapshot schema version 1 is Resource/Node-free dictionary/array/scalar data; rules version is separate.
- `CampaignCoordinator` bridges headquarters/preparation/debrief to `SceneFlow`. Menus request actions; combat still accepts ordinary Move/Attack/UseAbility/EndTurn commands.
- `EncounterConfiguration` optionally carries campaign identity, selected IDs and private hero definition overrides. Its snapshot detaches those overrides. Normal skirmish configurations leave them empty and preserve their own setup draft.
- `CombatUnit.campaign_id` maps the persistent hero to the existing encounter-local tactical stable ID. Fresh instances reset all tactical runtime resources.
- `CampaignMissionResult` deeply freezes its captured payload and returns detached snapshots. Result callbacks check the scene-flow epoch; CampaignState checks active/processed mission IDs. A copied, resolved encounter description records seed, preset/objective/roster, generator/difficulty versions, adjusted enemy factors, generation attempt and layout signature.
- Leaving combat uses existing shutdown/AI/effect cancellation and asynchronous navigation retirement. Loading abandonment has its own named pause owner; its dialog survives loading completion. HQ, guide and settings lifecycles do not retain old encounters.

There is intentionally **no serializer-to-disk, loader, continuation, migration UI or mid-combat save** yet. Milestone 11 must add validated restore/migrations and durable writes around this versioned data model; session callbacks/request IDs must be scoped to the restored session. Full human campaign balance/usability and audio/accessibility playtesting remain outstanding. No base construction, research, recruitment, permanent death or new tactical mechanics were added. New code, terminology and data are original; models/environment/audio retain the project's existing original asset documentation/licences.

