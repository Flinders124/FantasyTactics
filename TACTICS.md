# Enemy tactics

The existing Raider uses `definitions/tactics_melee.tres`. The existing ranged Sentinel uses `tactics_support.tres`, retaining its offensive abilities and safe Fireburst. `tactics_ranged.tres` and `tactics_spellcaster.tres` are tested editable policies for existing definitions. No unit stats, abilities or combat rules changed. Profiles are read-only resources; caches belong to individual decisions.

## Planning and execution

EnemyTactics compares current action, move then action, action then reposition, and movement alone. It retains one best action per candidate position rather than enumerating every sequence. Targets/abilities use stable IDs; equal scores use target/ability keys and candidate order. There is no decision RNG.

Actions use shared CombatController targeting helpers. Hypothetical-origin queries translate markers without moving units. Melee uses collision-surface gap; ranged uses marker distance. Actual equipped attack geometry always determines legality. AI area commands require at least two opponents and no ally/caster hits. CombatController rechecks this safety constraint immediately before commitment, including after state notifications. Player Fireburst retains friendly fire.

EnemyController submits existing commands only. Attempt flags precede submission: at most one move and one action attempt. After movement it evaluates actions afresh at the actual position. After acting it can plan one useful movement if unused. Authoritative completion signals resume decisions; effects own no damage or resource rules. Rejected/blocked movement falls back to a current legal action then End Turn. Rejected actions end the turn.

## Editable utility defaults

| Component | Default |
| --- | --- |
| Effective damage capped at remaining health | 10 per HP |
| Defeat | +45 per opponent |
| Effective healing capped at missing health | 6 per HP; minimum 3 HP |
| Healing at or below 50% health | +24; support +36 |
| Healing a target threatened by lethal current basic damage | +36 |
| Useful Slowed | up to +25, proportional to additional future affected turns |
| Additional area targets | +6; spellcaster +8 |
| Cooldown expenditure | -1.25 per configured cooldown turn |
| Actual navigation distance | -0.35 per metre |
| Exposure | -0.15 per expected basic-damage HP; ranged/caster -0.4, support -0.45 |
| Distance preference weight | 0.75; ranged/support/caster 0.6 |
| Ally crowding weight | 1.5 |
| Ranged adjacency penalty | 6 |
| Minimum net reposition gain for no stronger action | 0.75 |

Melee prefers a 0.8 m surface gap; ranged/support 5.5 m horizontal centre distance, spellcaster 6 m. Position utility is an improvement over the current position. Cooldown cost favors basic attacks when they achieve the same result. Slowed covering two future turns contributes no refresh value. Exposure/healing danger estimate legal basic attacks from current public positions, without future movement or abilities.

## Bounds and cancellation

Defaults per decision: 48 raw candidates, 24 accepted positions including current, 48 path queries, 768 shared action-validator calls, two endpoint evaluations per frame, eight directions on two useful-range rings. Maximum configurable limits are 80 raw / 40 positions / 96 paths / 1600 validators / four endpoints per frame / 12 directions. Area search uses at most 12 stable centres/midpoints. Paths above 128 points are rejected. A validator may perform several bounded geometry queries; its counter is not a count of individual physics rays.

NavigationService supplies actual route costs. Long routes are clipped to an affordable prefix, then that endpoint and actual cost are revalidated. Living-body path intersections are conservatively rejected; the planner does not create dynamic body detours. Command submission revalidates routes again.

Health/resources, unit positions, encounter revisions and navigation-map iteration invalidate a decision cache. At most one recovery replan is allowed per turn; another invalidation falls back to a current action or End Turn. With default limits, focused tests bound the entire turn to 144 planning path queries and 3072 validator calls including recovery and post-move evaluation. Accepted movement can add up to two command route checks outside planning metrics. Planning runs only when deciding, never continuously during an action.

Turn serials, epochs and living/active checks guard execution. Setup, restart, turn changes, results and scene retirement cancel timers/planners. Duplicate turn-start notifications cannot restart the same routine. Camera processing is independent. Legacy approach helpers remain for development hero-driving harnesses; production AI uses the bounded planner.

## Diagnostics and verification

Enable EnemyController `diagnostics_enabled` in a debug build for one `AI_DECISION` JSON record per completed plan: actor, turn, seed, profile, score breakdown, candidate rejection reasons, counts and CPU timing. Default is off. `decision_chosen` and an eight-entry `decision_history` support harnesses; restart clears history. No per-frame console output was added.

Run `tests/run_regressions.ps1 -Godot C:/path/to/Godot_console.exe`. Focused scripts: `tests/tactics_tests.gd`, `tests/tactics_encounter_tests.gd`; rendered interaction: `tests/tactics_review.gd` (append `-- 1080` for 1920x1080). See `../verification/TACTICS.md` for actual results.

Limits: finite rings can miss superior positions, one best action per point prunes combinations, conservative body filtering can miss a detour, exposure excludes future abilities/movement, and allies do not coordinate. No general-purpose planner or advanced retreat policy was introduced.
