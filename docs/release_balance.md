# Release balance audit — 22 October 2026

This is a bounded diagnostic, not human balance certification. Runtime: Godot 4.7.2 Mono, headless, fixed 60 FPS. The harness uses the existing EnemyTactics planner to issue legal hero commands and the production enemy controller. Six distinct hero pairs use seed 7, Open Courtyard, Elimination, on Easy / Standard / Hard. Each match stops at 40 rounds or 36,000 outer frames. The planner is an imperfect player; losses do not prove an encounter is unwinnable.

## Demonstrated issue and approved numeric change

The initial Cleric was strictly dominated by the Knight in unupgraded play: both had movement 6, Melee Strike damage 4, and the identical Mend (6 health, two blocked owner turns). Knight also had Power Strike (7 damage), health 20 and initiative 16; Cleric had health 18 and initiative 10 with no extra ability. Campaign-exclusive training and equipment differentiate later builds but do not remedy this starting/skirmish comparison.

Approved correction: `definitions/cleric.tres` maximum_health **18 → 22**. Initiative remains **10**. The Cleric now trades slower turns and no burst attack for the largest starting health pool. This removes strict dominance without changing shared healing or combat rules. No other tuning is justified by the current small sample.

| Hero | Starting HP before → after | Initiative | Basic attack | Abilities |
|---|---:|---:|---|---|
| Knight | 20 → 20 | 16 | melee 4, range 1.5 | Power Strike 7; Mend 6 |
| Ranger | 14 → 14 | 12 | ranged 4, range 2–8 | Crippling Shot; Mend 6; Fireburst 3 |
| Mage | 12 → 12 | 13 | ranged 4, range 0–8 | Fireburst 3 |
| Cleric | 18 → 22 | 10 | melee 4, range 1.5 | Mend 6 |

## Definitions and strategic checks

- Raiders start at 16 HP / initiative 14 / melee 4 / Power Strike 7. Sentinels start at 18 HP / initiative 12 / ranged 4 / Crippling Shot, Mend and Fireburst. Easy replaces the Sentinel with a second Raider and multiplies health/damage by .85. Hard uses Raider/Sentinel with health ×1.10 and offensive damage ×1.15. Rounding is explicit; enemy healing is unchanged.
- Gear has one instance per slot; training permits one choice at each of levels 2, 3 and 4. Modifiers add once, then clamp. Injuries apply one health −3 / movement −.5 penalty, with duration refreshed rather than stacked. All injured heroes can deploy; equipment purchasing and medical spending cannot block deployment.
- Largest Cleric heal is 13 every third owner turn (Kindled Mace + Votive Charm + Merciful Hands + Dawn Blessing), or 11 every second owner turn (Quickened Litany replaces Dawn Blessing). Healing uses the one action, clamps to maximum health, cannot revive, and has no out-of-combat persistent health resource. No unlimited healing/stacking exploit was demonstrated.
- Largest Mage offense build has basic damage 8 and Fireburst 7 (Ember Staff + Bright Ember + Heartfire). A separate Quiet Focus + Bright Ember + Swift Invocation build has Fireburst 4 with zero blocked turns. These are mutually exclusive level-4/weapon choices. One action per turn and friendly fire remain; zero cooldown is a finite intended build tradeoff, not an extra-action loop.
- A perfect five-win strategic run yields threat 2 → 3 → 3 → 4 → 4 → 3, below cap 10. Starting supplies 30 plus four normal rewards and the final reward yield 140, before optional spending. Choosing recovery on odd boards reduces the reward but offers extra injury recovery. Three successive failures can end the campaign; that is the stated threat loss condition, not a deadlock.
- The final board is intentionally a single Elimination offer, so any pair must fight the finale. No objective requires an ability possessed by a particular hero. Hold Ground and Extraction require navigation/zone occupancy; Extraction intentionally loses if either hero falls. Existing difficulty generation evidence covers 135 layouts (five seeds × three presets × three objectives × three difficulties) and all six pairs initialize on Hard. It is connectivity evidence, not a guarantee of tactical victory.

## Release-readiness boundary

Existing `campaign/play.json` records a completed real command-driven Easy Knight/Ranger campaign. Existing objective encounter evidence reaches results for all three objective kinds; the seed-7 diagnostic loses Elimination and Hold Ground and wins Extraction. Existing suites check tutorial recovery/restart, command restrictions, campaign abandonment while loading, duplicate results, and generation failure return paths. Read-only code inspection confirms campaign abandonment before navigation creates a strategic fallback record instead of trying to read absent combat units.

Save/load, distributable packaging and GPU/platform performance are coordinated separately in this release task. This audit does not certify human accessibility/audio, exported clean-machine behavior, all pair/objective/difficulty victories, or population-level win rates. No additional demonstrated data-loss or permanent progression stall was found in the inspected release paths.

## Reproduction and evidence

Run from workspace root, with APPDATA pointing at `outputs/verification/release/balance`:

```powershell
& work/godot-runtime/Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path outputs/FantasyTactics --script res://tests/release_balance_tests.gd
```

The final before/after matrix and exact exit statuses are recorded below after execution. `before.log` / `after.log` and JSON snapshots are the authoritative sample evidence. Early exploratory `headless.log` is superseded: it used the inherited test helper before explicitly resolving Easy roster and dispatching an enemy-first initial turn. Those harness omissions were corrected before the retained before/after runs.

## Completed results

Before: 18/18 terminal samples; exit 0, zero harness failures. After: all nine affected Cleric samples terminal; exit 0, zero harness failures. Numeric-only build/strategic checks and campaign_tests.gd also exited 0 with zero failures. Final before.log, after.log, numeric.log and campaign-regression.log contain no SCRIPT ERROR or ERROR entries.

V / D indicate victory / defeat; the number is the ending round. Unaffected pairs retain their measured baseline result (no claim of an after rerun).

| Pair | Easy before → after | Standard before → after | Hard before → after |
|---|---|---|---|
| knight/ranger | V5 → unchanged | D8 → unchanged | D7 → unchanged |
| knight/mage | V7 → unchanged | V10 → unchanged | D5 → unchanged |
| knight/cleric | V6 → V6 | D14 → V19 | D6 → D7 |
| ranger/mage | V6 → unchanged | D8 → unchanged | D5 → unchanged |
| ranger/cleric | V7 → V5 | V26 → V12 | D8 → D9 |
| mage/cleric | D7 → V6 | D6 → D8 | D5 → D6 |

The affected rerun improves Easy Mage/Cleric from D7 to V6 and Standard Knight/Cleric from D14 to V19; Standard Ranger/Cleric wins in 12 rounds instead of 26. Hard remains difficult for this planner. These samples support keeping the minimal HP-only correction; they do not justify changing enemy damage, threat, rewards, gear or healing.

For fast numeric checks append `-- --numeric-only`; for the affected nine encounters append `-- --cleric-only`. Full reruns use the current 22 HP definition, so reproducing historical before.json exactly requires restoring Cleric HP18 temporarily. The older transient-edit after log is explicitly superseded by the clean after.log.
