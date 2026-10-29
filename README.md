> **29 October 2026 — campaign balance:** modern campaign opposition is capped at2/2/3/3/3 by prior victories; failed missions return12 Supplies and ignored-offer threat is capped at1 per board. Existing frozen missions are preserved and known older saves migrate transactionally. See [rules, actual campaign results and remaining limits](docs/CAMPAIGN_BALANCE_MILESTONE_1.md). This is provisional tuning, not release signoff.
> **Permanent visual direction: Option C / The Lantern Oath.** Normal gameplay now uses graphic blue-stone materials, copper vegetation, the selected character treatment and shared lighting across battles, portraits and headquarters. The former A/B/C scene remains a development comparison. See [production art sources and rules](assets/art/README.md). Gameplay rules, collision, seeded layouts and save formats are unchanged.
# Fantasy Tactics — Windows release candidate

Current development phase: tactical AI. Role-aware decisions, meaningful support, public elite-warning avoidance and bounded movement memory are implemented in the existing command pipeline. See [Milestone2 behavior, tests, measurements and limitations](docs/TACTICAL_AI_MILESTONE_2.md). Historical milestone notes below retain their original verification counts.


Version **0.12.0-rc1** adds validated campaign autosaves, explicit backup recovery, Continue Campaign, frozen interrupted-mission restart, guarded headquarters transactions and final-result saving. **47 regression suites pass**; see [save policy](SAVES.md), [Windows build instructions](RELEASE.md), [release verification](../verification/RELEASE.md), [balance changes](docs/release_balance.md) and [measured performance](../verification/release/performance/README.md). Earlier milestone notes below are historical.

Headquarters now opens as an **interactive 3D camp**: select the Mission Board, Companions’ Tents, Training Yard, Armoury Tent or Commander’s Table to use the existing campaign menus. Idle heroes, original canvas tents and camp props, hover highlights, projected labels, bounded orbit/zoom, keyboard navigation and settings-aware input are integrated. **44 regression suites pass**, including the complete five-mission campaign; rendered interactions pass at both target resolutions with maximum text settings. See [camp controls/assets](CAMP_HEADQUARTERS.md), [verification](../verification/CAMP_HEADQUARTERS.md) and [running-game screenshot](../verification/camp/1920-default-overview.png).

Milestones 9–10 add **New Campaign → The Lantern Watch headquarters → choose a mission and two heroes → battle → debrief → headquarters → campaign ending**. The four heroes keep XP, permanent training choices, owned equipment and injuries within a seeded five-victory run. Threat and ignored missions create pressure; settings and standalone **Skirmish / Tutorial** remain available. Campaign saving was added in milestones 11–12; see [save policy](SAVES.md). **43 regression suites pass**; a command-driven Easy campaign reaches five-mission victory, and HQ/preparation/training/armoury/debrief reviews pass at both target resolutions and larger text. Read [exact campaign rules, catalogue and architecture](CAMPAIGN.md) and [verification/manual playtest checklist](../verification/CAMPAIGN.md). Balance remains provisional; next: milestone 11, save and load.

Milestone 8 adds one transactional **Settings / Pause** interface: display rollback, audio, key/mouse rebinding, camera preferences and readability options. **P** or protected **F10** opens it; combat freezes until it closes. Apply saves, Cancel restores the opening values, and category defaults preserve tutorial completion. **40 regression suites pass**; rendered reviews pass at 1280×720 and 1920×1080, and native display rollback passes on Windows. See [settings defaults and architecture](SETTINGS.md) and [verification/manual checks](../verification/SETTINGS.md). Historical milestone 8 baseline. Human accessibility and audio playtesting remain outstanding.

Milestone 7 adds a fixed, replayable **Tutorial** with event-driven movement, melee, ranged ability and turn demonstrations. **F1 Help** and **Briefing** explain controls/objectives and pause combat safely; hover/focus tooltips are bounded and input labels come from the InputMap. Completion is remembered alongside audio preferences. Normal skirmish rules and balance are preserved. See [tutorial sequence, architecture and manual playtest checklist](TUTORIAL.md) and [current verification](../verification/TUTORIAL.md). Historical milestone 7 baseline: **38 regression suites pass**, plus rendered tutorial runs at both target resolutions. Human new-player playtesting is still required.

Milestone 6 extends the same setup screen with **Easy / Standard / Hard**, optional seed/Randomize, adjusted enemy summaries and versioned **FT1 encounter codes**. All levels retain two enemies; Standard preserves the existing baseline. Retry rebuilds from frozen unadjusted definitions without compounding modifiers, New Battlefield retains settings, and Change Setup preserves the draft. Results show actual completed rounds and defeated units. **36 regression suites pass**, including 135 generated difficulty configurations and all six hero pairs. See [exact tuning, configuration format and controls](SETUP_DIFFICULTY.md) and [verification/screenshots and clipboard limits](../verification/DIFFICULTY.md). Next: milestone 7, tutorial and usability. Difficulty tuning remains provisional pending human playtesting.

Milestone 5 adds **Open Courtyard, Ruined Lanes and Central Plaza**, plus **Elimination, Hold Ground and Extraction** in party setup. Objective progress, world markers and result reasons use a dedicated runtime controller; outcomes remain authoritative after atomic actions. Enemies contest/intercept while retaining one move and one action. Retry preserves the preset/objective/layout/dressing; New Battlefield keeps the setup and changes the seed. Nine original scenery meshes add landmarks, props, ground detail and subtle vegetation motion. **32 regression suites pass**, including the 90-seed objective matrix and replay checks. See [setup, rules, generation and editable sources](OBJECTIVES.md) and [verification/screenshots](../verification/OBJECTIVES.md). Next: milestone 6, encounter setup and difficulty.

Milestone 4 adds deterministic role profiles and bounded utility planning for current actions, move-then-act, act-then-reposition and movement-only turns. Enemies compare effective damage, defeats, useful healing/statuses, safe area attacks and positioning while retaining one move and one action. Existing stats and rules are unchanged. **27/27 regression suites pass**, plus rendered full encounters at both target resolutions. See [tactics weights and limits](TACTICS.md) and [verification and remaining weaknesses](../verification/TACTICS.md). Next: milestone 5, battlefield variety and objectives.

Combat sound/effects milestone: 40 original local audio assets (editable synthesis/score source), spatial movement/weapon/ability cues, menu/combat music, courtyard ambience, result stings, shared event IDs, readable feedback glyphs and per-unit flashes. **Audio / F10** opens persisted Master/Music/SFX/Ambience sliders and mutes from the title or combat. Settings are independent of encounter state; the modal now pauses combat (milestone 8). See [audio assets and architecture](assets/audio/README.md) and [current verification/listening limits](../verification/SOUND_EFFECTS.md). No combat balance or rules changed.

Battlefield art milestone: generated encounters now use an original 16-mesh ruined-courtyard kit, matching collision, irregular flagstones, moss/ivy, boundary ruins, instanced foliage, daylight and reversible scenery fading. Gameplay layout and cosmetic RNG are separate; Retry reproduces both. Read [the courtyard asset/source documentation](assets/courtyard/README.md) and [current verification](../verification/COURTYARD.md). Open `scenes/courtyard_showcase.tscn` with F6 to review seed 7; F8 rotates and F9 toggles the combat HUD. Normal F5 flow and combat controls remain unchanged.

Stabilization audit (21 October 2026): **23/23 regression suites pass**, all six hero pairs complete generated encounters, 25 fixed seeds pass connectivity, and replay/lifecycle stress checks pass. See [the current defect and verification report](../verification/STABILIZATION.md). Run `tests/run_regressions.ps1 -Godot C:/path/to/Godot_console.exe` to repeat the checks.


Open `project.godot` in **Godot 4.7.2** and press **F5**. Main scene is now `scenes/main.tscn`: title → select exactly two of Knight, Ranger, Mage and Cleric → generated battlefield → combat result. Typed GDScript; Compatibility renderer; no external art or package dependencies. The .NET distribution of Godot 4.7.2 stable (`ed1daf0bf`) was used, but the game contains no C#.

Six original low-poly GLB characters replace the old capsule/cone visuals. Read [the asset documentation](assets/characters/README.md) for sources, triangle counts, rig, animations, licence and limitations. Open `scenes/character_showcase.tscn` and press **F6** to review them. **1–4** change view, **Q/W/E/R/T/Y** play Idle/Walk/Attack/Cast/Hit/Death; **Space** cycles clips. Party cards render the same equipped models used in combat.

New Encounter generates a fresh seed. Result screens provide **Retry Battlefield** (same heroes, enemies, seed and layout; fresh runtime state), **New Battlefield**, **Change Party** and **Main Menu**. The HUD shows the seed; command-line `-- --seed=7` reproduces the first newly started battlefield. Loading blocks world commands until geometry, navigation baking/synchronization and spawn/path validation finish. Generation uses bounded deterministic retries and a clear fallback arena. The fixed development arena remains available by running `scenes/combat_encounter.tscn` directly.

Generation configuration is in `BattlefieldSettings`, selected hero IDs/enemy setup/seed/cached layout in `EncounterConfiguration`. Default arena is 28 × 22 m with seven obstacles, 1.5 m obstacle clearance, separated spawn zones and a 0.5 m navigation agent radius. `SceneFlow` retires cancelled encounters after asynchronous setup returns, so stale AI/navigation work cannot enter a replacement scene.

Previous sound/effects verification: **25 dependency-free suites pass**, including sound/effect deduplication, travel-driven footsteps, settings and presentation cleanup. Rendered review and full generated encounter checks passed at 1280×720 and 1920×1080; **subjective listening quality was not assessed**. See [the sound/effects report](../verification/SOUND_EFFECTS.md) for results and manual listening steps. The [courtyard](../verification/COURTYARD.md), [stabilization](../verification/STABILIZATION.md) and [character](../verification/CHARACTER_VERIFICATION.md) reports document earlier milestones. Historical milestone details below describe preserved combat systems.

## Controls

| Control | Action |
| --- | --- |
| Help / F1 · Briefing | Open controls, contextual tips or the current objective briefing; combat pauses until closed |
| Settings / F10 · Pause / P | Unified settings and pause; Apply saves, Cancel restores; display previews revert after 12 seconds unless confirmed |
| Move / M | Select movement; hover ground for full route, destination and affordability; left-click to move |
| Attack / T | Toggle equipped-attack targeting; hover a unit for type, range, damage and legality; left-click to attack |
| Ability buttons / 1, 2 and 3 | Select the corresponding equipped ability; hover a unit and left-click to use; hover its button for description/cost/cooldown |
| Fireburst ability | First world click selects a point; the next world click confirms that locked point. Escape cancels; UI clicks never select/confirm it |
| Escape | Clear targeting and select neither mode |
| End Turn / E | End the active hero turn while awaiting commands |
| Right mouse drag | Orbit, pitch clamped from -80° to -14° |
| Middle drag, WASD or arrows | Pan |
| Wheel | Zoom, 5–40 m |
| F | Explicitly focus active unit |
| Retry Battlefield | Cancel pending actions/presentation and recreate the same generated setup |

UI clicks never issue world commands. Camera controls and Restart remain available during actions and enemy turns. Enemy turns run automatically; players cannot control enemies. Changing modes, losing targets, starting actions, changing turns or ending the encounter clears obsolete previews.

## Roles and turn rules

The four-unit initiative remains **Warden (hero-01, 16) → Raider (enemy-01, 14) → Sentinel (enemy-02, 12) → Scout (hero-02, 12)**. Ascending stable IDs break ties. Dead schedule slots are skipped without changing the cursor; rounds advance after a full cycle.

| Units | Role / visual | Basic attack | Health |
| --- | --- | --- | --- |
| Warden / Raider | Melee [M], capsule | Melee Strike, 0–1.5 m surface gap, 4 damage | 20 / 16 |
| Scout / Sentinel | Ranged [R], tapered cylinder and bow prop | Bow Shot, 2–8 m marker distance, 4 damage | 14 / 18 |

Each unit receives **6 m base movement and one shared action** at its own turn start. Multiple moves share that allowance. Attacking does not end the turn or spend movement: move, attack, move again. End Turn cannot interrupt resolution. A basic attack or ability consumes that action. Mutable health, movement, action availability, cooldowns and statuses live on individual CombatUnit instances, never shared definitions.

## Abilities and turn timing

| Ability | Equipped by | Effect | Range | Cooldown |
| --- | --- | --- | --- | --- |
| Power Strike | Warden [1], Raider [1] | 7 fixed damage to a living hostile unit | 0–1.5 m melee surface gap | Next two owner turns |
| Mend | Warden [2], Scout [2], Sentinel [2] | Restore up to 6 HP to a living injured friend, including self | 0–6 m 3D marker distance | Next two owner turns |
| Crippling Shot | Scout [1], Sentinel [1] | 2 fixed damage and Slowed if target survives | 2–8 m 3D marker distance | Next two owner turns |
| Fireburst | Scout [3], Sentinel [3] | 3 fixed damage in a 2.5 m radius, including allies/caster | Ground within 8 m of attack origin | Next two owner turns |

All values are editable `.tres` resources under `definitions/`. AbilityDefinition extends the existing attack geometry configuration, adding stable ID, description, target faction rule, effect (damage/heal), magnitude, cooldown and optional status. Ability effects use **magnitude**; the inherited basic-attack damage field is not their effect amount. Only the four authored abilities and Slowed are implemented; there is no effect scripting language.

UseAbilityCommand carries actor ID and ability ID, plus either a unit ID or an explicitly present ground position. Missing, conflicting, wrong-type and incompatible target data rejects before resolution. Vector3.ZERO is a real position, distinct from missing data. The original three-argument unit command remains compatible. CombatController checks equipped ability, the same active/living actor and shared action allowance, cooldown, faction, living target, range and obstruction. Mend rejects full-health targets and corpses. Self-Mend has zero marker distance with default coincident markers and needs no ray against the caster. Offensive unit-targeted abilities cannot damage friends; Fireburst uses its separate area faction flags. Previews, AI decisions and command submission call the same validator, with final revalidation immediately before commitment. Invalid commands spend neither action nor cooldown. One commit spends the action, starts the cooldown and applies clamped health changes/status once. The existing bounded controller resolution timer completes abilities; presentation callbacks cannot apply effects or unlock actions. The common action-completion signal retains its `attack` kind for attack/ability compatibility.

**Cooldown timing:** each unit increments its own owner-turn counter only at turn start. Using a two-turn-cooldown ability on owner turn N stores ready turn N+3. It is blocked on N+1 and N+2 and becomes available at the start of N+3. Example: use on turn 1, blocked on turns 2 and 3, ready on turn 4. The button shows COOLDOWN; its tooltip gives the exact number of future owner turn starts until ready. Neither round changes alone nor elapsed seconds advance cooldowns. Each ability has its own per-unit ready-turn entry, independent of shared definitions.

**Slowed timing:** StatusEffectDefinition contains configuration (default stable ID `slowed`, two affected turns, movement multiplier 0.5). Each CombatUnit creates its own StatusEffectInstance with a future-allocation counter and an affected-current-turn flag. Application queues two future turn starts; it never changes movement already granted. At each affected start, allocate `base movement × 0.5`, then decrement future allocations. The status remains through the second affected turn and expires at that turn's end. The following turn returns to 6 m. Initiative and the one action remain unchanged. Movement always derives from UnitDefinition's base, never the prior modified allowance.

Reapplication refreshes **two future allocations**, preserving any already affected current turn and its granted movement. It never adds a second instance or multiplies another penalty. Thus refreshing during an affected turn means that current turn plus the next two starts remain affected. Indicators distinguish `future turn(s)` from `+ current`; they appear in the active panel and passive world health labels. Natural expiration is logged once. Death discards statuses and skips the dead unit normally. Restart clears all status instances, owner counters and cooldown entries, pending action timing, stale AI decisions, targeting and presentation effects.

The log records authoritative ability use, damage or actual healing, status application/refresh/expiration and death/result events. A rejected command or repeated preview produces no entry. Mend has a green floating actual-healing effect; offensive abilities reuse attack feedback/tracers. Definitions never contain mutable counters.

## Shared attack rules

AttackDefinition exports type, damage, maximum range, optional minimum range and obstruction mask. `definitions/melee.tres` remains compatible through the stored `melee_range` alias; Warden/Raider share it. Scout/Sentinel share `definitions/ranged.tres`. Configure definitions independently in the Inspector.

**Melee distance** preserves the horizontal collision-capsule surface gap: `max(0, horizontal centre distance - attacker radius - target radius)`. The current radii are 0.35 m, so 1.5 m reach allows 2.2 m centre separation. This convention assumes upright overlapping capsules in the flat arena.

**Ranged distance** is the full 3D distance from the attacker's AttackOrigin marker to the target's TargetPoint marker. Both default to 0.8 m above the unit origin. CombatUnit exposes their NodePaths, and the scene markers can be repositioned. Minimum and maximum boundaries are inclusive with **0.000001 m** comparison slack. Minimum zero disables the close-range restriction.

Both types use the same marker-to-marker physics ray for obstruction. AttackDefinition's mask defaults to world layer 1: static geometry and all living unit bodies block. The attacker is excluded; the intended target is an allowed first hit. Dead units have collision disabled and block neither shots nor movement. This is a single visibility ray, not cover or a swept projectile volume; low geometry below the ray does not block it.

`CombatController.evaluate_attack` centralizes state, active/living actor, hostile living target, attack allowance, valid configuration/markers, range and obstruction checks. `evaluate_attack_position` shares the geometry with AI hypothetical positions; the old melee helper delegates to it. Previews, AI and execution use these helpers. Ranged rejection reasons include **Too close**, **Out of range**, and **Line of sight blocked**. Invalid attacks spend nothing.

The existing AttackCommand still carries actor/target IDs. The controller revalidates immediately before commitment, including after entering RESOLVING_ACTION, then spends once and applies clamped damage once synchronously. A configurable 0.22 s controller timer gates subsequent commands. No effect callback owns damage or action completion. A cosmetic ranged tracer/bead lasts 0.18 s by default (configurable 0.05–0.4 s); at most 12 tracers exist. Actor/target death, encounter completion and restart clear them. Repeated inputs cannot duplicate damage.

Death runs once, disables collision and selection, clears resources and removes the unit from future turns. Instances remain safely addressable until scene teardown. Both factions use one outcome evaluator: only enemies eliminated means VICTORY; only heroes eliminated means DEFEAT; both eliminated means DRAW. Terminal states reject gameplay commands. Restart cancels action timing, movement, AI epochs and visual work; restores transforms/health/resources/collision; and starts round 1 without reconnecting signals.

## Fireburst ground targeting and geometry

Scout and Sentinel share editable `definitions/fireburst.tres`: magnitude **3**, maximum cast range **8 m**, minimum **0 m**, area radius **2.5 m**, cooldown **two subsequent owner turns**, no applied status. AbilityDefinition adds GROUND targeting and relative affected-faction flags: **1 hostiles, 2 allies, 4 caster**; Fireburst defaults to **7 (all)**. Its own caster flag is independent of the allies flag. A valid empty cast is allowed and spends resources; AI avoids it.

Press **3** on Scout's turn (or click Fireburst). Hover ground to see the radius, full cast distance and actual expected HP loss per unit. First left-click **selects** a valid point without spending. The point is then **LOCKED**: the next left-click on world ground confirms the locked point, even if the cursor moved. To retarget, Escape and select Fireburst again. UI clicks never select or confirm; hovering UI temporarily hides previews while retaining the selected point. Changing mode/turn, starting an action, results and restart clear pending targeting. Camera controls stay independent.

The orange radius is a geometric ground cross-section of the sphere; walls can shield units inside it. The highlighted units and HUD hit list are authoritative. Hostile hits use green rings plus HIT/damage text; friendly hits use warning crosses plus ALLY HIT/damage text. The HUD always warns **FRIENDLY FIRE ON**, including caster. SELECT/LOCKED labels and explicit HUD instructions distinguish the two click phases. Invalid casts turn red, explain the reason and clear affected-unit highlights. Preview queries recompute every frame from current state, including while a point is locked; resolution recomputes again immediately before commitment.

AreaTargetingService, owned locally by CombatController, supplies the same query to player, AI and resolution:

- **Cast range:** full 3D distance from AttackOrigin to the requested ground point, not to the elevated blast origin. Default AttackOrigin is 0.8 m above unit origin.
- **Area inclusion:** full 3D distance from the point to each living unit's **GroundAnchor** Marker3D (default at unit origin/feet). Capsule radius does not extend area reach. Ground anchor path is configurable on CombatUnit.
- **Cast visibility:** ray from AttackOrigin to `point + UP × 0.15 m` by default. **Blast visibility:** ray from that offset point to each candidate's TargetPoint marker (default 0.8 m above its origin). Offset and obstruction mask are editable on AbilityDefinition.
- **Physics masks:** area rays default to **8, layer 4: Static arena visibility**. Arena obstacles use layer bits 1+8; floor uses 1+2+8. Unit bodies use 1+4 and are excluded from both area ray queries by RID, including the caster. Thus bodies block ordinary attacks as before, while neither cast nor blast rays are shielded by living/dead units. Static geometry blocks both rays. New static geometry must include layer 4 or the configured area mask. Ground mouse/surface queries use **2, layer 2**; unit picking remains layer 3.
- **Boundaries:** inclusive cast minimum/maximum and radius comparisons use **0.000001 m** slack. A requested point must be within **0.02 m** of an actual layer-2 ground surface. Its navmesh projection must be within **0.08 m horizontally** (NavigationService endpoint tolerance) and **0.65 m vertically**, accounting for the baked mesh's height. Querying waits for map synchronization. Ground is required to be navigable; a movement path from caster to cast point is not required. The requested point is not silently flattened or replaced.

Each affected stable ID is returned once, sorted ascending. The query snapshots current health and clamped post-damage health. CombatController validates the command, enters RESOLVING_ACTION, revalidates state/cooldown/range/visibility and **recomputes the entire affected set**. It spends one action and starts one cooldown, then applies every snapshotted health result while encounter/death scheduling is deferred. Only after all health changes does it publish area/hit events, deaths and one outcome check. Killing the caster cannot abort the rest of the blast. If both factions have no survivors the result is **DRAW**; one faction eliminated produces the usual victory/defeat. If the caster dies with both factions surviving, scheduling advances once to the next living unit.

Logs record one area summary, one hit per affected unit (including actual HP loss and FRIENDLY FIRE), deaths and a single result. A short expanding sphere and damage labels display resolved events only. Default blast lifetime is **0.35 s**, editable 0.1–0.8 s, capped at four effects. Effects have no physics/damage callbacks and cannot gate gameplay; restart frees them and all targeting work. The existing 0.22 s controller action gate is independent of presentation.

## Enemy decisions

EnemyController chooses actions; CombatController alone accepts commands and spends resources. AI submits the existing MoveCommand, AttackCommand and EndTurnCommand, at most one move and one shared action per turn.

1. First use legal Mend on a living ally (including self) at or below 50% health. Otherwise consider a safe two-opponent Fireburst, then an available legal targeted offensive ability, then a basic attack. Stable target IDs and equipped ability order make choices reproducible.
2. Otherwise use the existing basic-attack approach search to sample reachable, unoccupied attack positions around each living hero. Melee uses two rings; ranged uses three rings between minimum and maximum reach, accounting for marker height and horizontal offsets. Shared validators check navigation, range and obstruction. Never plan to the occupied target centre.
3. Choose shortest full navigation route. Costs within 0.0001 m tie by target ID, ring, then angle. Default 12 samples per ring, configurable 4–16: for two heroes, melee checks up to 48 default/64 maximum positions, ranged 72/96. Search runs once per turn, not every frame.
4. For a route beyond budget, consider up to eight progressively shorter path prefixes, with a 0.02 m safety margin. Requery endpoint reachability, occupancy and actual full cost before submission.
5. Await actual action-completion signals, reassess healing/offensive abilities/basic attacks, then end. Rejection/blockage falls back to a currently legal attack or End Turn without indefinite retries.

Area AI evaluates at most **12** deterministic points per equipped ground ability: living opponents’ ground anchors in stable-ID order, then nearby pair midpoints (separation no greater than twice the largest equipped area radius). With the current two heroes this is at most three candidates. Shared queries determine all hits. Expected actual hostile HP loss scores positively and friendly HP loss negatively; any caster/ally hit rejects the candidate, and at least two opponents must be hit. Highest score wins; equipped order, stable target/pair order break ties. The search runs only when making a turn decision, before/after the one permitted move, never every frame. Mend keeps its existing critical-health priority. No suitable/legal area shot falls back to existing behaviour. All commands, completion waits and restart epochs are unchanged.

A configurable 0.15 s presentation delay (0–0.5 s) is cancellable. Turn serials and cancellation epochs invalidate stale work on turn changes, death, results and restart. Duplicate turn notifications cannot create a second routine. Player/HUD submissions additionally require an active hero; the trusted command entry point also supports AI actors.

## Movement and interface

NavigationService waits for baked-map synchronization before queries and rejects disconnected partial paths. Costs sum the full route around obstacles. MovementMotor follows that approved polyline with physics-step `move_and_collide`, charging actual ground-plane displacement, including recovery. It never requests more than remaining budget. Configurable defaults: speed 3 m/s, arrival tolerance 0.005 m, blocked timeout 0.6 s. Overall deadline is three times planned travel time plus timeout. Budget overshoot tolerance is **0.002 m per turn** for numerical collision recovery; route affordability slack is 0.000001 m.

Navigation endpoints must project within 0.08 m horizontally and 0.65 m vertically of the baked surface. Paths flatten to the ground plane. Destination capsule occupancy includes static geometry and living bodies, excluding the actor. Bodies are not baked into navigation; a body along a route can cause a bounded stop without rerouting, preserving spent movement.

The anchored/container UI is checked at 1280×720 and 1920×1080. Initiative cards show living order, active highlight, faction and M/R role. The active panel shows health, movement, attack availability/type/range/damage. Selected Move/Attack buttons, disabled-action reasons, enemy/action status, previews and a compact help panel explain available actions. World active/hover/valid/invalid indicators combine shapes/text with colour. Screen-projected health bars track the camera, hide behind it and ignore mouse input. Floating HP/death feedback and the last 40 authoritative combat-log records clear on restart. Attack logs include attack type/name; rejections and UI refreshes create no false records. Result overlays provide Restart. Camera never automatically fights player input.

## Files and responsibilities

Area milestone adds `scripts/area_targeting_service.gd`, `definitions/fireburst.tres`, and `tests/area_tests.gd`, `area_enemy_tests.gd`, `area_input_tests.gd`. Existing command/controller/player/AI/HUD/log/presentation and unit scene were extended in place, with static collision-layer names in `project.godot`.

Earlier ability files: `scripts/ability_definition.gd`, `status_effect_definition.gd`, `status_effect_instance.gd`, `use_ability_command.gd`; `definitions/power_strike.tres`, `mend.tres`, `crippling_shot.tres`, `slowed.tres`; focused `tests/ability_tests.gd` and `ability_enemy_tests.gd`. Existing unit definitions equip them. Controller, unit, player/AI controllers, HUD, log and presentation were extended in place.

- `scenes/combat_encounter.tscn`, `scripts/combat_encounter.gd`: local systems, greybox arena, navigation bake and four units; no autoloads.
- `scripts/attack_definition.gd`, `definitions/melee.tres`, `definitions/ranged.tres`: reusable attack configuration; UnitDefinition references it.
- `scripts/combat_controller.gd`: shared command validation, action flow, spending, damage and outcomes.
- `scripts/player_controller.gd`: input, explicit targeting modes and previews.
- `scripts/enemy_controller.gd`: bounded deterministic command decisions and cancellation.
- `scripts/navigation_service.gd`, `movement_motor.gd`: path calculation and collision-aware execution.
- `scenes/combat_unit.tscn`, `scripts/combat_unit.gd`: mutable unit state, collision, role visuals, markers and signals.
- `scripts/turn_manager.gd`: initiative scheduling, rounds and dead-unit skipping.
- `scripts/combat_hud.gd`, `combat_log.gd`, `combat_presentation.gd`: signal-driven interface, authoritative history and disposable visual effects.
- `scripts/*_command.gd`: shared typed command pipeline.

## Validation

Run from this project directory, replacing `godot` with your Godot 4 executable:

```powershell
godot --headless --path . --editor --import --quit
$tests = @('run_tests','movement_tests','player_input_tests','attack_tests','targeting_tests','enemy_tests','playable_encounter_tests','interface_tests','ranged_tests','ranged_enemy_tests','ability_tests','ability_enemy_tests','area_tests','area_enemy_tests','area_input_tests')
foreach ($test in $tests) {
    godot --headless --path . --fixed-fps 60 --script "res://tests/$test.gd"
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
}
godot --headless --path . --quit-after 120
```

All **fifteen dependency-free suites passed with zero failures** on the documented Godot version. Main-scene smoke passed. Editor import loaded resources and exited 0 without parser or missing-dependency errors; immediate import-and-quit also printed internal `self_list.h:80` cleanup errors after loading. Those messages were not observed in the tests or graphical game runs. The suites cover foundation/scheduling/resource isolation, navigation and movement budgets/blockage, player input/UI isolation, melee/targeting, AI/cancellation, full encounters, interface and ranged rules/AI. New area checks cover full 3D inclusion/range boundaries, synchronization, static cast/blast obstruction, body non-blocking, faction flags/self damage, unique stable ordering, strict command data, preview/commit agreement and fresh membership, once-only spending/hits, atomic multiple deaths, victory/defeat/draw, dead-caster advancement and initiative successor integrity, presentation independence, bounded AI safe-hit/midpoint/fallback/rejection/restart, actual two-click UI isolation/cancellation/revalidation and both resolution layouts. Existing ability checks cover shared action lockout in both directions, once-only spending/effects, exact two-subsequent-turn cooldown timing, elapsed-time independence, exact Slowed allocation/expiration/refresh, no permanent base changes, self/friendly clamped healing and invalid-target rejection, independent runtime state, actual move–ability–move, range/obstruction, late revalidation, ability buttons/pointer/shortcuts, healing/offensive/basic AI priorities, bounded rejection/unreachable fallback and restart cleanup. Basic-attack-only enemy suites duplicate their fixture definitions and clear abilities to preserve their original assertions; the new AI suites and full encounter use equipped abilities. Ranged checks include inclusive minimum/maximum boundaries, 3D/offset markers, optional minimum, invalid/missing configuration, walls and intervening friendly/hostile/dead bodies, target-first-hit, preview/submission agreement, late revalidation, once-only spending/damage, move/attack order, tracer independence/cleanup, legal AI shots and firing positions, budget prefixes, unreachable targets, target death, restart cancellation and defeat.

Full default-stat encounter simulations use real commands and automatic enemy turns: a simple fighting policy and passive heroes lose in round 5; a support opening wins in round 6. The support opening moves Warden first to (-4, 0, 5), then (-1, 0, 5), before the normal test hero driver continues. Tests assert one AI routine and at most one move/attack per enemy turn. They verify completion, not human difficulty or balance.

Graphical runtime checks ran at **1280×720 and 1920×1080**: Fireburst hover/locked confirmation previews, friendly hits/effect, invalid cast line, wall blast shadow, actual enemy Fireburst, restart during its resolution, staged simultaneous-elimination draw, and complete original-spawn/default-stat victory (round 6) and defeat (round 5). Preview/draw/enemy close-ups use staged placement or health; full encounters restore default spawns/stats first. See [area verification and screenshots](../verification/area-checks.md). Representative captures were visually inspected at both sizes. Human hardware-input playtesting, arbitrary DPI/window sizes and balance playtests were not performed.

The installed .NET executable could not locate assemblies when launched from Downloads; a workspace scratch copy ran successfully. Editor import reports the existing editor-settings safe-save warning and the immediate-quit cleanup messages noted above. Their root cause has not been established; they did not prevent game execution. See the [import log](../verification/area-editor-import.log).

## Manual verification

Fireburst checks:

1. F5; End Warden's turn and let enemies act. On Scout's turn press **3**. Hover clear ground within 8 m: inspect the 2.5 m radius, cast distance, hit names/HP loss and FRIENDLY FIRE warning. Move/pan the camera; indicators remain world-aligned.
2. First left-click locks a point without damage, action spending or cooldown. Click a UI background: it must not confirm. Escape cancels all indicators/resources unchanged. Select again, lock, then click world ground again: one blast, one action and one cooldown. Repeated clicks during resolution cannot repeat damage or movement.
3. Include a friendly unit/caster deliberately: preview must say ALLY HIT and the listed units take 3 nominal damage, clamped at zero HP. Units behind walls inside the radius are not highlighted/hit; another unit standing between two candidates must not shield either. Test out-of-range/off-nav points for useful rejection without spending.
4. On the next two Scout turns, Fireburst is on cooldown; it is available on the third subsequent start. Movement remains available before/after it within the same turn budget. Existing targeted abilities/basic attacks use that same single action.
5. Run `area_tests.gd` for exact boundaries, wall-shadow, atomic multiple deaths, all three outcomes and self-kill scheduling fixtures. Run `area_enemy_tests.gd` for safe two-hero blasts, midpoint choice, no-friendly-hit policy, bounded fallback and restart while AI resolves.
6. Restart during selection or the orange blast. All health, statuses, cooldowns, pending points, highlights, effects and logs reset. Repeat, then run `area_input_tests.gd` for actual pointer/button/key confirmation and GUI isolation checks. Check both 1280×720 and 1920×1080, including DRAW overlay Restart. These remain human usability checks beyond the scripted runtime checks above.


Ability-specific manual checks (scripted runtime checks already passed; human input/usability remains to be checked):

1. F5, hover Warden's ability buttons for descriptions, one-action cost and cooldown. Press **1** to select Power Strike. Move into melee reach, hover an enemy and verify 7 damage; click. Basic Attack and Mend must become unavailable, while remaining movement and End Turn remain usable.
2. End turns normally through automatic enemies. Power Strike must be unavailable on Warden's next two turns and ready on the third subsequent turn. Waiting in real time must not change this. Hover a COOLDOWN button to inspect its ready-start countdown.
3. When a hero is injured, select **Mend [2]**. Hover self or a friendly: preview is min(6, missing HP). Use it and inspect the actual healing log/float. Full-health, enemy, dead, out-of-range or obstructed targets must reject without cooldown/action spending.
4. On Scout's turn, press **1** for Crippling Shot. With an enemy at clear 2–8 m range, preview 2 damage plus Slowed and click. That enemy's next two turn starts grant 3 m, with a full action and unchanged initiative. It expires after the second turn ends, then grants 6 m. Run `ability_tests.gd` for repeatable refresh-during-current-turn and shared-definition isolation fixtures.
5. Observe enemies use Mend at or below 50% health, offensive abilities otherwise, and basic attacks on cooldown. Restart during an enemy ability and repeatedly afterward: full health, first Warden turn, ready abilities, no statuses, one fresh turn log, no old effects/actions.
6. Repeat at 1280×720 and 1920×1080; confirm tooltips, selected states, status labels and ground clicks. Camera orbit/pan/zoom remains responsive throughout.

Existing movement/ranged regression checks:

1. F5: confirm four units, M/R labels, initiative order and 6 m/one attack. Move Warden twice and inspect combined spending and obstacle detours. Invalid/occupied destinations spend nothing.
2. End Turn: Raider and ranged Sentinel act automatically. Camera orbit/pan/zoom remains responsive. Player clicks and End Turn cannot control or interrupt them.
3. On Scout's turn, press T. Hover enemies: compare the marker-distance preview with 2–8 m range and 4 damage. Too-close, out-of-range and wall/body-obstructed targets must reject without spending. The ranged test script supplies repeatable staged boundary/obstruction fixtures.
4. Fire a clear legal shot: exactly four damage and one attack, one tracer. Repeated clicks cannot duplicate damage. Move afterward with remaining budget; a second shot rejects. Check Warden/Raider still use surface-gap melee reach.
5. Kill a unit: its card/bar/targeting clears and its body no longer blocks shots or movement. Finish both outcomes; overlays stop gameplay. The playable-encounter and ranged-enemy scripts provide repeatable victory and defeat runs.
6. Restart while an enemy moves or a tracer is visible, repeatedly: original four units/full health/round 1, one fresh log entry, no old actions or effects. Confirm UI clicks never also move/shoot.
7. At 1280×720 and 1920×1080, inspect layout, projected health labels while orbiting, preview reasons and result Restart. These are remaining human-usability checks beyond the automated/runtime visual checks.

## Known limits and next milestone

Flat arena movement only; no avoidance or dynamic rerouting. Bounded position samples can miss narrow legal firing spots. LOS uses one marker ray, not cover or ballistic flight. Damage is instantaneous; the tracer is cosmetic. Health bars do not hide behind walls. Ability UI currently provides three equipped slots, matching this roster. AI reuses basic-attack firing/approach positions rather than searching independently for healing positions; it heals only when already legal. There is only one status type. Area previews use a ground circle plus authoritative hit labels/list rather than drawing wall-clipped volumes. Friendly fire is intentional for Fireburst only. No persistent ground hazards, destructible terrain, cover bonuses, summons, reactions, mana, inventory or progression were added.

Recommended next milestone: editable encounter/scenario resources and balance playtests, with several deterministic obstacle layouts and mixed-role rosters. The current playable slice supports this iteration without adding more combat systems.




Mission variety development: [Milestone 3 report](docs/MISSION_VARIETY_REPORT.md), including templates, layouts, compatibility, real captures and measured verification limits.


Milestone4 roster/rescue and the approved Aegisbearer + Chainbinder classes: see [roster report](docs/ROSTER_SPECIALISATION_REPORT.md). New campaigns start with four individual sword recruits; use Camp → Training to specialise at Level2. Campaign HUD adds Stabilise, Carry, Drop and Extract. Unextracted companions are permanently lost on retreat.
