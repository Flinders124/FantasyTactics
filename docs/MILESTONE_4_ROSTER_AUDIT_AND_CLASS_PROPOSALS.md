# Milestone 4 — Roster audit and class proposals

28 October 2026 · Project: `C:/Temp/FantasyTactics`

**Approval document only. No new class, ability, model, animation, progression, recruitment or survival implementation has begun.** Your brief requires choosing exactly two of the four candidates before Part 2. Every proposed number below is provisional, editable tuning rather than a change to the current game.

## 1. Verified baseline

Godot 4.7.2 standard, typed GDScript, Compatibility renderer. The existing fast regression category passed **17/17 suites**, including combat scheduling, tactical decisions/cancellation, objectives, difficulty, campaign progression, persistence, save integrity, resource/visual lifecycle, factions, compatibility and mission templates. All exited 0 with explicit zero-failure results and empty stderr. Evidence is under ignored `verification/roster-m 4/baseline/`. Import/type checking passed first. This was a focused baseline, not another full 73-suite, graphics or standalone-export run.

No AGENTS.md was found in the project during this audit. Existing uncommitted M2/M3 work is retained. No game rules, definitions, models, animations or saves were edited for this approval phase.

## 2. The actual four existing specialisations

Names below are the current display/archetype names; individual persistent recruit names do not exist yet.

| Existing class / ID | Base HP / initiative / movement | Weapon and basic attack | Starting activated abilities |
|---|---|---|---|
| **Warden / Knight** (`knight`) |20 /16 /6 m|Sword and heraldic shield;4 damage,1.5 m melee reach|Power Strike 7 melee damage; Mend 6 healing within 6 m|
| **Scout / Ranger** (`ranger`) |14 /12 /6 m|Bow and quiver;4 damage,2–8 m|Crippling Shot 2 damage + Slowed; Mend 6; Fireburst 3 damage,2.5 m radius,8m cast range|
| **Arcanist / Mage** (`mage`) |12 /13 /6 m|Crystal staff; Focus Bolt 4 damage,0–8 m|Fireburst 3 damage,2.5 m radius,8m cast range|
| **Dawnkeeper / Cleric** (`cleric`) |22 /10 /6 m|Flanged mace and sacred emblem;4 damage,1.5 m melee reach|Mend 6 healing within 6 m|

All currently start specialised at Level 1. Every listed activated ability has a two-subsequent-owner-turn base cooldown. Basic attacks and abilities share the single action allowance. Movement is separate and can occur before/after an action. Fireburst affects the caster and allies; Slowed halves the next two future movement allocations. Healing currently targets living, injured units only.

### Existing progression and tactical identity

- **Warden:** frontline burst and self/ally sustain. Level 2: +3 HP or +1 basic damage; Level 3: +0.5 m movement or +2 Mend; Level 4: +2 offensive damage or +4 HP. Strong initiative and melee burst; no ranged basic attack and every heal costs its attack opportunity.
- **Scout:** flexible ranged pressure, slowing, healing and area damage. Level 2: +1 m basic range or +1 basic damage; Level 3: +0.5 m movement or +3 HP; Level 4: +1 offensive damage or +2 Mend. Versatile, but 14 HP, a 2 m basic-shot dead zone, and friendly-fire risk limit it.
- **Arcanist:** ranged damage without a basic-shot dead zone, plus ground area attacks. Level 2: +1 offensive damage or +1 m basic range; Level 3: +3 HP or +0.5 m movement; Level 4: +2 offensive damage or reduced Fireburst cooldown. Lowest health, no healing and dangerous friendly-fire positioning.
- **Dawnkeeper:** durable healer whose specialisation becomes stronger through progression/equipment. Level 2: +2 Mend or +3 HP; Level 3: +0.5 m movement or +1 basic damage; Level 4: +2 Mend or reduced Mend cooldown. High health and healing scaling; lower initiative and no ranged basic attack.

There are **no additional activated abilities unlocked by higher levels today**: the existing higher-level choices change stats/healing/cooldowns. Warden and Scout already share Mend with Dawnkeeper, and Scout already shares Fireburst with Arcanist. Those overlaps are real; preservation means not removing those abilities to manufacture gaps for new classes.

The clearest missing roles are proactive protection, positional displacement, damage suppression/status removal, and a committed long-range firing role. There is no cover, armour-reduction, accuracy, critical-hit or reaction system to assume.

## 3. Systems audit and implementation implications

| System | What exists | Limitation relevant to M4 |
|---|---|---|
| Persistent roster | Four plain hero records keyed by class IDs; XP, level, upgrades, injury, equipment | No independent person/class identity, recruit generation, duplicate-class heroes, personal names, mission counts or memorial |
| Deployment | Exactly two distinct heroes; private encounter definitions; results map back to records | HeroCatalog, deployment validation, overrides, equipment and saves assume four fixed IDs |
| Experience | Participation 10 XP + success 15 XP; levels 1–4 at 0/20/50/90 XP | New recruit reaches Level 2 after one victory; current Level 2 already contains an upgrade choice, so class selection must be a separate guarded decision |
| Training | Two permanent upgrade choices at each level 2–4 | No reserve XP or replacement catch-up training service |
| Equipment |16 items; weapon and garb slots; owned instances; safe transfer; familiar fallback gear | Compatibility is tied to the four class IDs, not new unique hero IDs or an unspecialised recruit |
| Supplies |30 initial; normal success 22, recovery 14, failure 4; weapons generally 16–18; recovery service 12 | Recruitment cost and late-campaign replacement readiness still need design/testing |
| Injuries | Battle strain 2 / severe 3 subsequent mission resolutions; deployment recovers 1, rest 2; recovery success adds 1; penalties−3 HP/−0.5 m | All heroes survive campaign zero-HP outcomes today; injured heroes can deploy |
| Tactical death | Zero HP immediately runs death once, disables collision/selection/actions and skips future turns | No downed state, bleed-out, stabilisation, carry, rescue, revived scheduling or persistent death |
| Healing | Fixed healing for living injured allies, including self | Cannot currently revive a zero-HP unit; permanently dead vs downed must become distinct |
| Extraction | Objective requires both original heroes alive in the exit after a completed action; they stay in combat | Not a retreat system and not a rescue/removal interaction |
| Debrief | Immutable result record; rewards/injuries/XP applied once | Records health/max health, not extracted/recovered/abandoned/dead outcomes |
| Save/load | Version 1, strict four-hero schema, validated fingerprints, temp/backup writes, interrupted deployment restart | Needs explicit migration; never reset veteran class/XP/equipment or overwrite an unsupported save |
| Missions/AI | Nine templates, five layouts, three objectives; deterministic bounded utility AI and public commands | New survival states/abilities must use those pipelines; no separate class combat engine |
| Visuals | Four dedicated hero GLBs, rendered portraits, class icons, editable original character source;18-bone rig, Idle/Walk/Run/Attack/Cast/Hit/Death | No recruit outfit, carry/drag pose, new-class equipment or downed/stabilised presentation yet |
| Export | Current resource pack passed external-engine smoke in M3 | Matching native Windows release template remains absent; no new EXE verification is implied |

The active visual contract is `assets/characters/IMPORT_WORKFLOW.md` and the `oath_models` exports, not just the older six-model README. These are actual skinned meshes with original editable procedural sources, not primitive placeholders. They offer a viable base for two new silhouettes after approval; no new assets are claimed now.

### Important risks to resolve after class selection

1. Split persistent hero identity from specialisation/template identity throughout deployment, equipment, results and saves; otherwise two heroes of the same class would collide.
2. Replace the tactical “HP>0 means alive” assumption with explicit conscious/downed/stabilised/extracted/dead semantics. Turn eligibility and target eligibility must use the appropriate predicate.
3. Separate the existing Extraction objective from the new retreat/rescue interaction. Define atomic results when the last conscious hero exits or falls, without silently rescuing or killing everyone.
4. Preserve old Level 1 specialists as legacy veterans, with their existing class, XP, level and gear. New recruits alone follow the new unspecialised-start rule; do not silently grant/reapply class bonuses.
5. Protect replacement readiness before the locked finale. Current reserves gain no XP and the finale offers no easy training detour. Recruitment pricing alone does not solve that potential softlock. A focused recovery/training rule must be agreed and tested as part of implementation.
6. Define downed/healed scheduling, additional-damage behaviour, carrying penalties and round-based bleed timing explicitly. Basic stabilisation and rescue must not require either new class.

## 4. Proposal rules shared by all four candidates

- Exactly **two** candidates may be implemented, after your selection. The other two remain prose only.
- Each new class receives a normal basic attack plus two Level 2 abilities below; attacks and abilities spend the existing one action. No extra turns, free attacks or extra action allowance.
- Normal movement remains separate, paid and bounded. No accuracy rolls, crit system, armour/cover system or hidden AI information is added.
- Base ability cooldowns below mean subsequent owner turns, using the existing semantics. New class cooldown improvements have a minimum one-turn cooldown.
- New finite effects do not stack; previews, AI and resolution share the same authoritative calculations. Atomic area actions consume a one-use modifier once, rather than separately reapplying it per victim.
- Level 3/4 proposals fit the existing two-choice-per-tier structure: ability improvements or modest passives, not more actions. Exact numbers and class base stats remain provisional until approved.
- Stabilise, pickup/carry/rescue and extraction are universal roster mechanics. Selecting no new support class must remain viable.

## 5. Comparison

| Category | Option A | Option B | Option C | Option D |
|---|---|---|---|---|
| Class name | **Aegisbearer** | **Chainbinder** | **Hexweaver** | **Arbalist** |
| Combat role | Preventive frontline protection | Positional controller / rescue support | Damage suppression / status removal | Committed ranged execution / marking |
| Primary weapon | Tower shield + short spear | Hooked polearm + chain | Short rune rod + ritual book | Heavy crossbow |
| Signature ability | Aegis | Reel In | Dulling Hex | Braced Shot |
| Tactical strength | Keep fragile allies alive without healing | Move a threat or ally into a better position | Weaken dangerous actions and clear Slowed | Reward established firing lanes and focus fire |
| Main weakness | Low damage, no healing | Short reach, geometry-dependent control | Fragile, low burst, no healing | Slow, vulnerable up close, shot restriction |
| Visual identity | Broad shield and stone-rune silhouette | Lean armour, hook and coiled chain | Layered cloth, book and restrained rune effects | Broad crossbow stock, bolts and braced stance |
| Implementation complexity | Medium | High | Medium | Medium |

## Option A — Aegisbearer

1. **Name:** Aegisbearer; a defensive Watch specialist, distinct from the Warden's burst/healing kit.
2. **Role:** Prevent incoming damage and hold useful approaches.
3. **Weapons/equipment:** Tower shield and short spear; heavier armour, reduced mobility. Proposed basic attack 3 damage,1.5 m reach.
4. **Identity:** Finite, proactive absorption rather than a second Mend user, taunt, immunity or reaction attack.
5. **Level 2 abilities:** **Aegis** places a 3-point damage-absorption ward on a conscious friendly target, including self, within 4 m and clear line of sight; cooldown 2. It lasts through the target's next two future turn ends or until consumed. Reapplication refreshes/replaces up to the configured ward, never adds pools. **Shield Bash** deals 2 melee damage and applies existing Slowed for two future movement allocations; cooldown 2. Its reused Slowed effect is supporting utility, not the class's unique selling point.
6. **Advanced progression:** Level 3 chooses **Long Vigil** (+1 m Aegis range) or **Stoneheart** (+3 HP). Level 4 chooses **Deep Aegis** (+1 absorption) or **Quick Brace** (Bash cooldown 2→1).
7. **Strengths:** Protect Arcanist/Scout, screen objective occupants and buy time to rescue. Absorption can prevent a casualty, but cannot restore lost health or stop bleed-out.
8. **Weaknesses:** Low personal damage, shorter movement allowance than mobile heroes, no ranged basic attack/heal. Multiple small hits can exhaust its finite ward; area attacks threaten the unprotected partner.
9. **Visual design:** Adapt the original humanoid rig with a clearly larger shield, spear, angular pauldrons and an etched stone motif. Guard/cast lifts the shield; use a restrained impact ripple and a labelled ward counter, respecting reduced effects.
10. **AI behaviour:** Ward meaningfully threatened allies using public initiative/geometry, retain important objective positions, and Bash only when slowing movement matters. Prefer a legal finishing attack over redundant protection.
11. **Balance:** Warden retains stronger melee burst, initiative and Mend. Aegisbearer spends an attack opportunity to absorb a small finite amount; it grants neither free retaliation nor permanent reduction. All damage types in this game's fixed-damage pipeline use the same ward calculation.
12. **Complexity — Medium:** One new finite absorption status, authoritative damage/preview integration, expiry/spending tests and shield/spear adaptations. No forced movement, taunt AI, reaction system or general buff language.

## Option B — Chainbinder

1. **Name:** Chainbinder; an original polearm controller.
2. **Role:** Reposition units and create openings rather than primarily deal damage.
3. **Weapons/equipment:** Hooked polearm with a coiled chain, fitted leather/metal harness. Proposed basic attack 4 damage,1.8 m melee reach; medium durability.
4. **Identity:** Controlled displacement, with collision, occupancy and public line-of-sight constraints.
5. **Level 2 abilities:** **Reel In** deals 2 damage to a hostile within 5 m and pulls it up to 2 m toward the caster to a legal unoccupied position; cooldown 2. **Towline** draws a conscious or incapacitated friendly unit up to 2 m toward the caster from within 4 m; cooldown 3. Towline does not heal or stabilise, and does not replace universal adjacent rescue. A cast with no useful legal displacement is rejected without spending resources.
6. **Advanced progression:** Level 3 chooses **Long Chain** (+1 m targeting range, no extra pull distance) or **Anchor Stance** (+3 HP). Level 4 chooses **Rending Hook** (+1 Reel In damage) or **Practised Haul** (Towline cooldown 3→2).
7. **Strengths:** Pull shooters away from safe positions, expose targets to melee, help a rescuer close distance and contest an objective.
8. **Weaknesses:** Shorter reach than ordinary archers; walls, intervening bodies and occupied landings defeat pulls. Its own attack opportunity is spent helping a unit move; forced movement grants no extra action to either unit.
9. **Visual design:** Lean silhouette with hooked polearm, visible chain coil and gauntlet. Use existing swing/cast foundations plus an authored tug/recovery pose and a short chain-line effect. No ragdoll or physics-rope simulation.
10. **AI behaviour:** Prefer a useful landing over maximum pull distance; do not pull an ally into a warning or expose a downed unit. Score objective displacement and urgent rescue; retain the existing one normal move/one action limit.
11. **Balance:** Cannot pull through walls, swap across inaccessible spaces, add attacks or guarantee a finish. Displacement uses a bounded collision-aware effect owned by CombatController, not commands pretending the target is the active actor.
12. **Complexity — High:** Target movement is new infrastructure. It needs shared endpoint previews, collision-aware execution, cancellation, carrying/downed interactions and clear partial-blocking semantics. This is the largest technical/animation risk of the four choices.

## Option C — Hexweaver

1. **Name:** Hexweaver; a restrained rune-and-omen caster.
2. **Role:** Reduce dangerous incoming attacks and remove movement hindrances.
3. **Weapons/equipment:** Short rune rod and ritual book; layered cloth/light armour, distinct from the Arcanist's tall staff/hat. Proposed basic ranged attack 3 damage,0–6 m; low durability.
4. **Identity:** Prevent damage by suppressing the opponent's next damaging action, plus focused cleansing. It has neither Mend nor Fireburst.
5. **Level 2 abilities:** **Dulling Hex** deals 2 damage within 6 m and applies **Dulled**: the target's next damaging action loses 2 damage per affected victim, with damage floored at 1; cooldown 2. One charge expires after two future target turn ends, does not stack, and is consumed once when damage actually resolves. Healing and an elite's preparation do not consume it; a later resolving elite blast can. **Unbind** removes existing Slowed from a friendly unit within 6 m; cooldown 2. It does not refund movement already granted/spent, heal, stabilise or erase injuries.
6. **Advanced progression:** Level 3 chooses **Far Hex** (+1 m Dulling Hex range) or **Warded Threads** (+3 HP). Level 4 chooses **Heavy Omen** (penalty 2→3, still floor 1 and one charge) or **Practised Unbinding** (Unbind cooldown 2→1).
7. **Strengths:** Weaken a high-value offensive enemy, mitigate an announced blast, and free a partner's future movement for extraction/rescue.
8. **Weaknesses:** Low burst/health, no healing or area damage. Hexing an enemy that heals or never attacks can waste the action; cleansing a stationary ally often has little value.
9. **Visual design:** Offset book/rod silhouette, stitched rune panels and muted violet/cream accents. Reuse the shared rig with appropriate book-hand poses; short rune tracers, a readable DULLED marker and no flashing curse cloud.
10. **AI behaviour:** Select threats from public attacks, cooldowns, initiative and warnings; value the expected prevention without pretending to know future commands. Avoid redundant refreshes and pointless cleansing; prioritise universal rescue when it is more urgent.
11. **Balance:** Does not stun, remove turns, reduce damage below 1, weaken healing, or multiply penalties across repeated callbacks. Scout retains longer-range pressure and Slow; Arcanist retains stronger burst/area potential; Dawnkeeper retains actual healing.
12. **Complexity — Medium:** A one-charge damage modifier and a narrowly scoped existing-status removal effect. Both require shared preview/AI/atomic-damage integration but no displacement or new resource system.

## Option D — Arbalist

1. **Name:** Arbalist; a deliberate long-range crossbow specialist.
2. **Role:** Establish firing lanes, finish priority targets and enable focused basic attacks.
3. **Weapons/equipment:** Heavy crossbow, bolt case and reinforced bracers. Proposed basic attack 4 damage at 2.5–9 m; slower movement/initiative than Scout and no healing.
4. **Identity:** A committed shot rewards not moving before the action, while a finite mark supports a partner. It is not another all-purpose bow/heal/area kit.
5. **Level 2 abilities:** **Braced Shot** deals 7 damage at 3–10 m with clear line of sight, usable only if no actual movement has been spent this turn; cooldown 3. The hero may still move afterward using the normal remaining allowance. **Focus Mark** marks a hostile within 10 m for +2 damage on the next friendly **basic** hit, including the Arbalist's own; cooldown 2. One nonstacking charge expires after two future target turn ends. It does not amplify Fireburst, Power Strike or an entire area action.
6. **Advanced progression:** Level 3 chooses **Long Sight** (+1 m basic range) or **Reinforced Stocks** (+3 HP). Level 4 chooses **Patient Aim** (Braced Shot cooldown 3→2) or **Keen Bolts** (+1 basic damage).
7. **Strengths:** Long clear lanes, dangerous single targets, coordinated turn-order focus fire. Bracing before a retreat can trade damage for position without adding movement/actions.
8. **Weaknesses:** Significant close-range dead zone, modest health, slower relocation. An enemy can pressure it into moving and deny the signature shot; walls and intervening living units still block it.
9. **Visual design:** Broad crossbow stock and bolt silhouette, braced upper-body pose and authored reload/recovery. Adapt the archer rig after approval; use a restrained bolt tracer and a labelled one-use mark.
10. **AI behaviour:** Braced Shot from an already legal lane, otherwise reposition once for a normal attack. Mark only when a partner can plausibly exploit it; prefer an immediate basic kill to wasted overkill/setup. Reassess after movement.
11. **Balance:** Scout retains better mobility, less severe minimum range, Mend, Slow and Fireburst. The 7 damage signature has setup/cooldown constraints; the mark costs its own action and helps exactly one basic attack.
12. **Complexity — Medium:** Track actual distance moved rather than clicks/rejected commands, add a one-use basic-damage mark, and author crossbow equipment/animation. No cover, accuracy, piercing or reaction system.

## 6. Recommended pair: A + C

**Aegisbearer + Hexweaver** add proactive protection and enemy-action suppression/status removal, the two strongest gaps given the current three Mend users and two Fireburst users.

- Aegisbearer + Arcanist protects a fragile area caster without making the protector another healer.
- Hexweaver + Warden creates a control/frontline pair; Warden supplies burst/healing while Hexweaver suppresses threats and counters Slowed.
- Either new class complements Scout without taking away its established broad kit.
- Both new classes together form a cautious protection/control party with real weaknesses: low damage and no specialised healing beyond universal rescue.

Both require moderate extensions to the current status/damage pipeline and can share its tests. Chainbinder offers the most novel geometry play, but has substantially higher displacement/rescue/collision integration risk. Arbalist is feasible and distinct, but overlaps the already represented ranged-damage role more than the recommended pair.

This is a recommendation only. **You choose exactly two: A, B, C or D.** Nothing from the unselected proposals will be implemented. Gameplay implementation remains stopped at your mandatory approval checkpoint.
