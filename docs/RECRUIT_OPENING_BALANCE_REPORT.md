> Subsequent campaign tuning is documented in [Campaign Balance and Recovery](CAMPAIGN_BALANCE_MILESTONE_1.md); the findings below retain their historical values.

# Recruit-stage balance investigation — 29 October 2026

## Method

Godot4.7.2, headless fixed60fps. Actual generated encounter scenes, navigation, enemy controller, combat validation, movement, action spending, deaths and campaign result processing. The existing command-driven hero bot uses EnemyTactics to choose legal actions. Only presentation delay/movement speed/resolution delay are accelerated; HP, damage, allowances and enemy decisions remain unchanged. Isolated user data under verification/recruit-balance; player saves are untouched.

Opening matrix: campaign seeds7,17,423 on Easy/Standard/Hard, first offered Elimination mission, two original recruits, default equipment, no purchases or paid training. Comparison repeats the same configurations with a diagnostic-only Raider+Bowhunter roster. This comparison is not applied to the game or old saves.

## Results

| Difficulty | Current opening wins | Diagnostic two-enemy wins | Deaths in comparison |
|---|---:|---:|---:|
| Easy |1/3|3/3|0|
| Standard |0/3|3/3|1|
| Hard |0/3|3/3|3|

Current Easy seed7 generated Shieldguard+Bowhunter and both recruits survived at level2/25XP. Easy17/423 generated two Raiders+Bowhunter. Standard17/423 generated three Raiders+Bowhunter; Standard7 generated Shieldguard+two Bowhunters. Hard17/423 generated two Raiders+Bowhunter+Shieldguard. All Standard/Hard samples lost both people before earning XP. Thus progression is possible, but the opening varies considerably and is disproportionately punishing for two melee-only recruits.

One victory awards25XP, crossing the20XP level2 threshold. The class-unlock mechanism works; the demonstrated problem is reaching that victory. Paid training8Supplies/person can unlock classes before combat, but should not be assumed to make the opening fair.

A complete Standard17 campaign was run with legal paid training and Knight/Ranger specialisation before each pair's first deployment. First mission: defeat in round5, threat2→6. Reserve pair: defeat in round9, threat6→10, campaign defeat. No bonus supplies, rerolls or reward injection. Two failure increments plus ignored offers account for the four-point threat rise per loss. This is a campaign ending, not a successful completion.

## Diagnosis and recommendation

MissionCatalog.compose fills a template's role slots until the faction budget is exhausted; cheap one-cost Raiders/Bowhunters allow three or four enemies even on the first board. It does not account for the new starting recruit roster. Two recruits have two actions, no healing/ranged/status abilities and lower initiative than Raiders/Bowhunters. The opening inherited encounter composition designed around established specialists.

Recommended narrow correction: newly generated introductory campaign offers should use a fixed two-unit Raider/Bowhunter opposition until the first success, then ramp regular templates gradually. Keep recruit stats, shared action rules, skirmishes and later enemies intact. Preserve already committed/frozen offers and save compatibility explicitly. Do not turn the diagnostic override into a hidden difficulty multiplier. Test the revised progression across more seeds and objectives before shipping it.

## Limitations

These are deterministic automated gameplay runs, not manual playthroughs or new-player usability tests. Three seeds per difficulty are strong reproduction evidence, not a balance win-rate estimate. The hero bot does not model every human tactic or rescue decision. No production balance, save schema, build or campaign rule was changed by this investigation. The previously captured intermittent native shutdown crash remains unresolved; these investigation processes exited cleanly.

Raw results: verification/recruit-balance/baseline/recruit-openings.json; pair/recruit-openings.json; campaign/roster-campaign-play.json. Source: dev/recruit_opening_audit.gd and dev/recruit_campaign_audit.gd. See the natural campaign result below for the successful-opening continuation.

## Natural progression campaign

Easy seed7 completed five consecutive victories with the original two recruits and no paid training, purchases, recruit replacement or stat changes. The first victory granted25XP each; they specialised into Knight/Ranger at headquarters, spent ordinary earned upgrade choices, and won the remaining four missions including the finale. All four original roster members remained alive; final threat4. This proves natural recruit→specialist→campaign victory is achievable in at least one real generated campaign, while the wider opening results demonstrate poor consistency.

Result: verification/recruit-balance/natural/roster-campaign-play.json; capture source dev/recruit_natural_campaign_audit.gd. All four diagnostic engine runs exited0 with zero harness failures (baseline, comparison, Standard campaign defeat, Easy campaign victory). Harness success means the scenarios completed and reports were written; it does not turn lost encounters into wins.

Reproduce opening matrix with the installed engine:

```powershell
$Godot = './verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe'
# Set APPDATA, LOCALAPPDATA, TEMP and TMP to private writable verification folders first.
& $Godot --headless --fixed-fps 60 --path . --script res://dev/recruit_opening_audit.gd -- --report-root=C:/Temp/FantasyTactics/verification/recruit-review
# Add --variant=pair for the diagnostic two-enemy comparison.
```

## Applied correction — 29 October 2026

Approved recommendation implemented in CampaignState.generate_offers. Newly created offers before the first victory use exactly one Ashfang Raider and one Ashfang Bowhunter. Difficulty health/damage/search modifiers still apply. After the first victory, existing faction/template generation resumes immediately; this is the only opposition ramp added. No recruit, equipment, XP, threat, objective or combat-rule values were changed. Legacy specialist campaigns retain their prior generation. Existing frozen offers and committed missions are never rewritten, including on save/load; start a new campaign to see the new initial board.

The configuration is frozen before offer encoding, so briefing/deployment/retry/interrupted recovery all use the same two IDs. No save format or content fingerprint changed. The new recruit_opening_tests is included in the ordinary all/roster runner.

Verification: regression first failed36 opening assertions, then all6 focused suites passed with clean exits (new opening rules, mission templates, campaign roster, roster saves, persistence and factions). Import/type checking passed. Cases cover all3 difficulties,3 seeds, all3 opening objectives, failed-opening regeneration, restoration of normal composition after victory and preservation of a frozen four-enemy saved offer.

Actual changed-game opening matrix produced9 victories with zero harness assertion failures, matching the prior diagnostic comparison. However the engine exited unsuccessfully after the final success record; the wrapper retained the run as failed. This is consistent with the separately documented intermittent native shutdown issue and is not counted as a clean runtime pass. Logs/results: verification/recruit-tuning/openings.log and openings/recruit-openings.json; clean focused results: checks-green/results.json.

Post-fix Standard17 campaign: opening VICTORY in round5, surviving recruit earned25XP and specialised without paid training. Subsequent two missions were defeats, campaign ending at threat10 after one victory. Engine exit0 and zero harness failures; this is a clean lifecycle run, not a campaign win. Later attrition/replacement balance therefore remains provisional. Raw record: verification/recruit-tuning/campaign/roster-campaign-play.json, campaign.log, campaign-exit.txt. No standalone build was exported or manually played during this adjustment.
