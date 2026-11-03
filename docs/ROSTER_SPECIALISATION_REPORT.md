> Later campaign balance rules are documented in [Campaign Balance and Recovery](CAMPAIGN_BALANCE_MILESTONE_1.md). Numerical defaults below describe the roster milestone's original rules.

# Milestone 4 — individual roster, rescue and approved classes

Status: implementation delivered; verification results and outstanding release risk are recorded below. This report supersedes the implementation status in the historical class-approval document. Only Aegisbearer (A) and Chainbinder (B) were approved; Hexweaver and Arbalist are not implemented. No Milestone 5 work is included.

## Implemented flow

New Campaign → four named, independently identified Level 1 sword recruits → deploy exactly two living people → complete or retreat from a mission → persistent XP, injury, recovery or permanent loss → recruit/train replacements → permanent class choice at Level 2 → ordinary upgrades/equipment → continue the existing five-victory campaign.

Two people may choose the same class. Their IDs, names, inventory, XP, injuries and combat resources remain independent. Standalone skirmishes and Tutorial retain their original four-character selection and immediate tactical death rules. The roster's basic recruit is not a seventh advanced class.

The existing camp, mission templates, objectives, difficulty, free movement and one-action economy remain in use. Headquarters shows actual living roster classes, individual portraits, availability, mission counts, training and a memorial. Class selection shows actual model previews, roles, weapons, strengths/weaknesses and ability descriptions. Dead people cannot be redeployed, healed, trained or awarded XP.

## Editable defaults

`definitions/roster_rules.tres`: four starters; recruitment 12 Supplies; optional basic training 8 Supplies, bringing a Level 1 recruit to 20 XP once; bleed-out three future round ends. Spending on gear, treatment or training reserves enough Supplies to replace a missing second deployable companion. If mission consequences leave fewer than two survivors and insufficient recruitment funds, the campaign ends explicitly.

Existing economy/progression: 30 initial Supplies; 10 participation XP +15 victory XP for survivors; level thresholds 0/20/50/90; mission victory 22 Supplies, failure 4; recovery offers 14; existing elite bonuses unchanged. Existing injuries remain −3 maximum health/−0.5 m, with established recovery timing. A rescued zero-health survivor receives the existing severe injury; a dead hero receives no XP. Mission counts include fallen participants. Migrated veterans start mission counts at zero because the old schema did not record individual service history.

| Blueprint | Health | Initiative | Movement | Basic attack | New abilities |
|---|---:|---:|---:|---|---|
| Recruit |20|12|6 m|Sword,4 damage,1.5 m melee|None|
| Aegisbearer |22|10|5.5 m|Spear,3 damage,1.5 m melee|Aegis:3 absorption within4 m,CD2. Shield Bash:2 damage +Slowed,CD2.|
| Chainbinder |18|13|6 m|Hook,4 damage,1.8 m melee|Reel In:2 damage within5 m, pull up to2 m,CD2. Towline:friendly/downed pull up to2 m within4 m,CD3.|

Cooldown N blocks the next N owner turns and becomes ready at the following turn start. Aegis replaces a finite pool; it does not stack. It expires after two future target turn ends or depletion. Damage, including area/elite blasts, consumes absorption before health. Shield Bash uses existing Slowed, without changing initiative or action allowance.

Reel/Tow use the shared ranged marker-distance and line-of-sight convention. Forced movement is a short synchronous swept capsule, not a target MoveCommand or extra actor movement. Static geometry/living bodies block it; the landing must remain on navigation. No useful clear displacement means rejection before action/cooldown spending. Successful motion never waits on the chain presentation.

Two choices at each level2–4 remain. New tier3/4 choices improve specific ability range/magnitude/cooldown or health; no extra actions. Gear modifiers and class changes derive fresh private definitions. Existing four classes retain their base stats and abilities.

### New progression/equipment values

- Aegisbearer level2: Stoneguard +3 HP or Spear Drill +1 basic damage; level3: Long Vigil +1 m Aegis range or Stoneheart +3 HP; level4: Deep Aegis +1 absorption or Quick Brace Bash CD2→1.
- Chainbinder level2: Hardened +3 HP or Hook Drill +1 basic damage; level3: Long Chain +1 m Reel/Tow targeting range or Anchor Stance +3 HP; level4: Rending Hook +1 Reel damage or Practised Haul Tow CD3→2.
- Stonepoint Spear / Barbed Hook:18 Supplies, +1 basic damage/−0.5 m movement. Vigil Spear / Longhaft Hook:16 Supplies, +0.5 m basic range/−2 HP. Free issue weapons and the existing shared garb keep an affordable baseline. New class cooldown reductions floor at1; existing class tuning is unchanged.

## Survival rules and controls

Campaign life states: ACTIVE, DOWNED, STABILISED, EXTRACTED, DEAD. At zero health a campaign hero becomes downed: nonblocking, nonacting, still selectable for rescue. Bleed-out skips the incapacitation round, then advances once at each future round end. Stabilise stops it. Further area damage shortens an unstabilised bleed counter by one per atomic blast. Ordinary enemy targeting ignores downed units.

Campaign-only HUD controls:
- **Stabilise**: target an adjacent downed ally; stops bleed-out without healing.
- **Carry**: target one adjacent downed/stabilised ally. Movement allocation halves and distance already spent remains spent.
- **Drop**: place the companion on one of eight checked nearby clear navigation positions. No movement refund.
- **Extract**: remove the carrier and any carried companion at the marked zone.

Each rescue command costs the shared action. Rescue adjacency uses a1.5 m capsule-surface gap, matching the normal melee convention, and static line of sight. Mend may revive a downed/stabilised ally only when there is room to stand; it grants no immediate action or movement. Dead people cannot be resurrected. A carrier's incapacitation drops the companion. Carried units have no collision; a supporting-arm pose and named carrying label communicate the state.

Extraction objectives use their existing exit; other campaign missions show a labelled retreat ring (radius2.8 m) at the hero spawn zone. Ordinary move/attack shortcuts and camera controls are unchanged. Rescue targeting cancels through the existing Escape/cancel binding; menu clicks do not issue world commands.

Victory recovers conscious and stabilised heroes, companions being carried by a conscious rescuer, and already extracted heroes. A draw with no enemies also recovers stabilised heroes. Unstabilised bleeding companions left behind die. Failure/retreat/abandon preserves only explicitly extracted people. If no conscious hero remains, the mission ends; it does not simulate rescue by nonexistent actors. Extraction requires both original people alive and at safety (a carried companion counts with its carrier); permanent loss makes it impossible. Retreat/abandon confirmation warns about permanent losses. Cancellation before battlefield setup is safe.

## Persistence and compatibility

Campaign schema2 stores stable person IDs, name, specialisation, legacy flag, level/XP/upgrades, missions completed, injuries, equipment and permanent death/cause. Temporary health/status/ward/cooldown/carry state is encounter-owned; HQ health derives from private adjusted stats. Mission-result schema2 contains final recovered/extracted/dead outcomes; immutable result IDs retain exactly-once processing.

Actual shipped schema1 saves are validated and migrated transactionally. IDs/classes/levels/XP/equipment/offers remain intact; Level1 veterans retain their legacy class. Frozen offers are not rerolled. A known historical content hash is accepted for v1 only. New default attack/status fields are omitted from old fingerprints. Encounter-code v3 adds an explicit duplicate-class flag when necessary; old v1/v2 codes retain validation. Saves remain between encounters; interrupted missions restart from their committed original deployment.

Tests use isolated user-data directories. The original fixed-four test scenarios explicitly use `LegacyCampaignFixture`; modern roster tests exercise actual new campaigns rather than weakening historical assertions.

## Assets and source

Original CC0 shared-rig meshes: `assets/characters/oath_models/{recruit,aegisbearer,chainbinder}.glb`; editable additive source `assets/characters/source/build_roster_v4.py`; validation `verify_roster_v4.py`; complexity `manifest-v4.json`. Existing21 character GLBs are unchanged. Recruit3185/Aegisbearer3763/Chainbinder4943 triangles; each18 joints,7 material surfaces,7 clips: Idle,Walk,Run,Attack,Cast,Hit,Death. Original outline SVG icons and actual-model portrait renders are integrated. Aegis has a shield glyph; Reel/Tow use a short chain-line afterimage; presentation never applies effects.

Review scene: `scenes/character_showcase.tscn` (F6). 1–4 select front/side/rear/tactical views; Q/W/E/R/T/Y/U select clips. Capture harness: `dev/roster_showcase.gd`.

## Verification

Final consolidated run: **87/87 suites passed**, every process exiting cleanly with zero assertion failures and empty stderr; summed suite runtime1824.55s. Results: `verification/roster-m4/complete/results.json`. Final source pack was re-exported after this run and its four fresh smoke phases passed (`verification/roster-m4/export-smoke-final/results.json`). These clean runs do not erase the intermittent native failure below. Engine: Godot4.7.2.stable.official.ed1daf0bf, standard Windows console build. Baseline before approval:17/17 fast suites passed. New command-contract test first failed for the absent rescue/abandon APIs, then passed after implementation. Focused unit/class/art/UI/combat tests passed in the initial integration run. Initial full run exposed the Chainbinder's mesh-budget overrun (reduced real chain geometry to4943 triangles), legacy test-variable typing, and historical save-flow fixtures; those were corrected without weakening assertions. Bounded generation batches exceeded old runner time budgets while continuing to progress; no turn watchdog was increased.

### Executed checks and measurements

- All14 new roster suites passed in the final consolidated run. Coverage includes private state, migration, rescue validation, extraction with a carried companion, ward/pull/tow, cooldowns, pose transitions and campaign flow.
- A modern campaign harness completed six real missions: one defeat, then five victories using the reserve pair, reaching campaign victory. Six advanced-class pair scenarios completed through real commands. These establish progression and legality, not player-facing balance.
- The broader regression validated 150 objective-generation cases and 225 difficulty configurations plus the original six hero pairs. The previous consolidated run had 81 clean passes out of83: a subsequently fixed test parse error and a native shutdown crash. Failed runs remain on disk.
- Final faction regression completed93 encounters,270 bounded decisions and15 roles. Combat stress completed6 cases with188 enemy commands. Twelve encounter/session cycles retained242 nodes each. The final cycle retained216 resources and approximately60.49 MB of Godot static allocation; an earlier warmed run ranged60,091,523–60,476,879 bytes; this is not process/GPU memory or proof of all leak absence.
- Direct blueprint lookup replaces loading every blueprint graph for each lookup. An80-lookup microbenchmark measured107,087µs versus447µs. The expanded225-configuration generation batch completed in85.45s after previously exceeding360s. No gameplay layout or tuning changed.
- Native renderer: Windows, Godot4.7.2, OpenGL3.3, NVIDIA RTX500 Ada Generation Laptop GPU, driver596.71. Actual captures cover front/side/rear/tactical character views, animation poses, headquarters, roster, specialisation, deployment, combat and rescue at1280×720/1920×1080. No frame-rate or universal performance target is claimed.
- Resource-pack export and four external-engine smoke phases passed: title/skirmish/tutorial, new roster/equipment/settings, interrupted enemy-turn recovery, actual encounter victory, debrief reload without duplicate rewards. This uses the installed engine and is **not a standalone Windows release**. The configured release template `C:\work\export-templates\windows_release_x86_64.exe` is absent.

### Unresolved native shutdown crash

An intermittent Windows access violation (0xC0000005) occurred after tests had printed zero assertion failures. Affected runs remain failed. Three isolated save-integrity repetitions produced two clean exits and one crash. A native debugger also captured the failure outside restricted execution: Godot executable RVA0x3e2d181, invalid read with a freed-heap marker. Without matching native symbols, the responsible function and root cause are not established. Evidence: `verification/roster-m4/native-debug.log` and `native-save-av.dmp`. A similar shutdown failure was documented before this milestone. No timeout, automatic retry, or suppressed failure masks it. This remains a high-severity release-stability risk; no save corruption was observed in the executed cases.

### Review captures and repeatable verification

Nineteen actual renderer captures are in [screenshots](roster-milestone/screenshots). Review the front/side/rear/tactical images, class-selection and roster screens at both resolutions, and rescue/combat shots. The source capture harness is `dev/roster_showcase.gd`.

Run `tests/run_regressions.ps1 -Godot verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe -Category roster -ReportDirectory verification/roster-review` with isolated APPDATA/LOCALAPPDATA/TEMP/TMP under the project. Use `-Category all -TimeoutSeconds 600` for the full matrix. The runner requires clean exit, zero assertions and empty error output.

Manual validation still required: play a fresh campaign without harness assistance; recruit, train each new class, deploy duplicate classes, down/stabilise/carry/extract and abandon; reload the resulting headquarters save; compare a normal skirmish/tutorial. Inspect normal camera motion and equipment through every animation, largest accessibility scales, and balance with human players. A standalone executable smoke test awaits the matching export template. Independent final code review did not complete because the review agent exhausted its quota.

## Known presentation/balance limits

Carry uses an arm brace and label while the carried model is hidden; there is no bespoke shoulder-carry animation or physics rope. Downed/stabilised use the existing collapse pose. Pull resolution is immediate with a short visual afterimage. The two new classes and harsher campaign consequences require human playtesting; automated matches establish legality and progress, not balance or usability. No new enemy classes, campaign length, currency, dialogue or unapproved classes were added.
