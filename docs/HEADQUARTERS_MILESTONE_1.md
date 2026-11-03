# Opening campaign and headquarters — Milestone 1

## Player flow

Win missions, specialise companions, then choose where to invest Supplies. The Commander’s Tent sells permanent squad-capacity upgrades. The Camp Outfitter sells shared inventory; it never equips a purchase. Open a companion’s Character & equipment screen, select an unlocked slot, and choose owned equipment. Transferring an equipped item requires confirmation.

- Command tier 1: 20 Supplies after one victory; deploy 2 or 3 companions.
- Command tier 2: 30 Supplies after two victories and tier 1; deploy 2, 3 or 4.
- Camp presentation grows with each purchased tier. Capacity does not increase enemy stats or grant extra actions.
- Weapon and body armour: level 1; helmet: level 2; accessory: level 3; advanced weapons/body armour: level 4.
- Recruitment reserves remain protected. Levelling unlocks eligibility, not free items.

The visiting trader arrives after every second committed mission resolution, including failures and confirmed abandonment. Three seeded, frozen offers each contain one instance. Inspecting preparation does not dismiss the trader; committing a mission does. Bought gear remains in shared inventory. Prices are 30–45 Supplies. Unusable offers show their requirements and cannot spend Supplies.

## Configuration and compatibility

Reusable tuning lives in `definitions/campaign/headquarters_rules.tres` and the equipment resources below. Runtime capacity, stock, ownership and artwork belong to campaign state. A separate trader/art random stream leaves battlefield geometry unchanged. Existing first two hero spawns and enemy RNG are preserved; additional hero positions consume no gameplay random draws.

Save schema 4 migrates old schemas through the existing chain. Old campaigns receive no free upgrades or trader visit, preserve their frozen missions and keep legacy opening generation. Real schema-3 initial/interrupted fixtures are regression-tested. New larger-party encounter codes use version 4; old two-person code formats remain supported. Interrupted deployment restores the full selected party with fresh combat state. Extraction requires every originally deployed companion, rather than a hard-coded two.

New campaigns have authored First Watch / The Watch Expands / A Stronger Line briefings and bounded role compositions. No squad-size enemy scaling was added. Tactical rules, actions, cooldowns and injury processing are unchanged.

## Equipment tuning

Existing items and modifiers remain in the catalogue. New additions:

| ID | Supplies | Minimum level | Vendor | Explicit modifiers |
|---|---:|---:|---|---|
| beacon_blade | 45 | 4 | trader | {"basic_damage": 2, "basic_range": 0.5} |
| beacon_bow | 45 | 4 | trader | {"basic_damage": 2, "basic_range": 0.5} |
| beacon_helm | 35 | 2 | trader | {"health": 3} |
| beacon_hook | 45 | 4 | trader | {"basic_damage": 1, "ability_range:reel_in": 1, "ability_range:towline": 1} |
| beacon_mace | 45 | 4 | trader | {"basic_damage": 1, "healing": 2} |
| beacon_plate | 42 | 3 | trader | {"health": 5, "movement": -0.25} |
| beacon_spear | 45 | 4 | trader | {"basic_damage": 1, "ability_magnitude:aegis": 1, "basic_range": 0.5} |
| beacon_staff | 45 | 4 | trader | {"basic_damage": 1, "ability_magnitude:fireburst": 1, "basic_range": 0.5} |
| crest_helm | 18 | 2 | armoury | {"health": 2} |
| duskward_charm | 40 | 3 | trader | {"movement": 0.5, "basic_damage": 1} |
| pathfinder_charm | 12 | 3 | armoury | {"movement": 0.25} |
| veteran_blade | 28 | 4 | armoury | {"basic_damage": 2, "movement": -0.25} |
| veteran_bow | 28 | 4 | armoury | {"basic_damage": 2, "movement": -0.25} |
| veteran_hook | 28 | 4 | armoury | {"basic_damage": 1, "ability_range:reel_in": 0.5, "ability_range:towline": 0.5, "movement": -0.25} |
| veteran_mace | 28 | 4 | armoury | {"basic_damage": 1, "healing": 1, "movement": -0.25} |
| veteran_plate | 26 | 4 | armoury | {"health": 4, "movement": -0.5} |
| veteran_spear | 28 | 4 | armoury | {"basic_damage": 1, "ability_magnitude:aegis": 1, "movement": -0.25} |
| veteran_staff | 28 | 4 | armoury | {"basic_damage": 1, "ability_magnitude:fireburst": 1, "movement": -0.25} |
| watch_helm | 10 | 2 | armoury | {"health": 1} |
| wayfinder_charm | 22 | 3 | armoury | {"movement": 0.5} |

Modifiers use the existing runtime definition-copy pipeline. Basic damage, healing, ability magnitude and ability range change only through explicitly named modifier fields. New artwork is inventory presentation; equipping does not replace character equipment meshes. Legendary sword, helmet and armour families each have two original image variants, fixed per owned instance and preserved by saves. Other weapon types reuse existing class symbols. Source PNGs are retained; runtime UI imports are capped at 256 pixels.

## Verification

Verification logs are isolated under `verification/headquarters`; player saves are not used. Godot 4.7.2 standard (`ed1daf0bf`), Windows, Compatibility renderer; native rendering reported NVIDIA RTX 500 Ada Generation Laptop GPU / driver 596.71. These are development-machine observations, not hardware targets. Automated combat drivers use real shared rules/commands, not alternate damage logic. Staged campaign results used to reach UI review checkpoints are not human-played victories.

### Repeatable commands

```powershell
./tests/run_regressions.ps1 -Godot verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe -Category headquarters -ReportDirectory verification/headquarters/repeat -TimeoutSeconds 300
```

Set APPDATA and LOCALAPPDATA to a fresh directory inside verification before running. `dev/headquarters_showcase.gd` is a real-renderer, isolated UI review harness and is excluded from production exports. `tests/run_export_smoke.ps1` executes an exported resource pack using the Godot runtime; this is distinct from a standalone Windows executable.

## Remaining limitations

- Initial prices and larger-party pacing need human playtesting; automated victories cannot prove enjoyment or balance.
- Inventory artwork does not imply new equipment attachment meshes.
- An intermittent Windows native shutdown access violation predates this change. Runs with that exit remain failed even if assertions completed.
- The configured standalone Windows release template is unavailable; no newly verified standalone executable is claimed.
- Deferred minor: save validation checks tier against victory count, matching current prerequisites 1/2. If those editable prerequisites are retuned, update validation to use the configured array too.


## Results actually observed

- Baseline: 6/6 selected existing suites passed before implementation.
- Final source regression: **31/31 suites passed**, 768.56 seconds aggregate suite wall time. Import/type checks passed. Includes campaign victory through six actual simulated missions (one failure, five victories), campaign/events, all six original pair deployments, persistence/recovery, objectives, settings/pause, survival and AI lifecycle, plus all nine new headquarters suites.
- Larger-party generation: **90/90 live maps**, five fixed seeds × three presets × three objectives × three/four heroes. All spawn separations/connectivity and deterministic replay assertions passed. Batch work measured50.06s (suite53.45s including startup/cleanup). Original two-hero25-seed generation suite also passed.
- Six real-command opening simulations: all completed with victory and no stalled turns. Seeds17/37: two heroes rounds4/5; three heroes4/4; four heroes3/4. Encounter simulation wall times4.97–6.83s with accelerated fixed-frame tests, not player encounter duration or a balance guarantee.
- Native final interaction run: **passed**, exit0, empty stderr, 144.73s. Actual mouse-driven command purchases, premium purchase, character slot equip, preparation and four-hero generated combat at1280×720 and1920×1080. A second focused native run passed22.86s for scrolled shop views and keyboard focus to equipment slots with1.15UI scale plus larger text. 26 real-renderer screenshots retained.
- Visual regression fixes: item cards now expand to both shop-grid columns; Extraction world label uses the deployed party count. Both new assertions were seen failing before correction, then passed in the final source suite and rendered retake.
- Production resource pack exported successfully (8,071,348 bytes). External headquarters smoke passed from the release directory with isolated user data: definitions/art, limited stock, inventory/equip, save/load and four-hero interrupted-deployment reconstruction/navigation. The four existing production-pack smoke phases also passed: title/tutorial/skirmish/campaign entry, equipment/settings persistence, interrupted enemy-turn recovery, completed encounter/debrief and subsequent relaunch. This is a PCK exercised with the Godot runtime, **not a standalone Windows executable**.
- No universal frame-rate or memory improvement is claimed. UI textures were verified at≤256px; no new measured graphics bottleneck was targeted.

One earlier opening suite completed zero-failure assertions but exited with the known native Windows access violation; it remains failed in phase-d2. Final selected regressions and native runs exited0. An early simulation harness run also remains failed: its inherited setup disabled AI before the first turn; the corrected harness enables AI before setup, without changing gameplay or weakening completion assertions.

### Representative screenshots

- `docs/headquarters/screenshots/camp-tier0-1920.png`
- `docs/headquarters/screenshots/camp-tier1-1920.png`
- `docs/headquarters/screenshots/camp-tier2-trader-1920.png`
- `docs/headquarters/screenshots/shop-1920.png`
- `docs/headquarters/screenshots/trader-1920.png`
- `docs/headquarters/screenshots/slot-chooser-1920.png`
- `docs/headquarters/screenshots/character-large-1280.png`
- `docs/headquarters/screenshots/four-hero-combat-1920.png`

### Remaining manual playtest

Start a new campaign, win once, specialise companions and buy the20-Supplies Commander upgrade. Deploy three and complete a mission. Choose between the second30-Supplies upgrade and visiting-trader gear. Buy gear at the shop, equip/unequip it from the character slot, and transfer it with confirmation. Save/close/continue at camp and during deployment. Complete Hold Ground and all-four-hero Extraction; assess whether larger squads improve pacing without making late encounters trivial. Check discretionary spending versus injury/recruitment reserves. This human economy/usability playtest is still required.

## Important files

- Rules/state/compatibility: `scripts/headquarters_rules.gd`, `definitions/campaign/headquarters_rules.tres`, `scripts/campaign_state.gd`, `scripts/campaign_save_codec.gd`, `scripts/encounter_configuration.gd`, `scripts/encounter_code.gd`.
- Equipment/trader: `scripts/campaign_item_definition.gd`, `scripts/campaign_equipment.gd`, `scripts/campaign_trader.gd`,20 editable resources in `definitions/campaign/equipment/`, existing generated equipment PNG import settings.
- Camp/UI: `scripts/campaign_coordinator.gd`, `scripts/campaign_screen.gd`, `scripts/camp_kit.gd`, `scripts/camp_overview.gd`, `scripts/campaign_onboarding.gd`, `scripts/field_guide.gd`.
- Larger-party gameplay: `scripts/battlefield_generator.gd`, `scripts/battlefield_layout.gd`, `scripts/combat_encounter.gd`, `scripts/objective_controller.gd`, `scripts/objective_marker.gd`.
- Verification: nine `tests/headquarters_*_tests.gd` suites, real schema-3 fixtures, external `tests/headquarters_pack_smoke.gd`, `tests/run_regressions.ps1`, `tests/README.md`, two excluded `dev/headquarters_*showcase.gd` scripts. Existing unrelated work was retained.

## Ruling and deferred minor

Work stayed in the user-requested existing checkout, preserving prior uncommitted onboarding/events/art. Cost: this milestone is not isolated into a separate branch; no reset or commit was performed. The independent read-only final review found no Critical/Important issue. Its one deferred minor is the editable-upgrade prerequisite validation noted above; current1/2-victory defaults are unaffected.
