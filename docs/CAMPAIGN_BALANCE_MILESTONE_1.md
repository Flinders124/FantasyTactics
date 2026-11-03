# Campaign Balance and Recovery — Milestone 1

## Scope and baseline

This milestone tunes the existing five-victory campaign. No new combat mechanics, hero stats, abilities, AI tactics, injury rules or objectives. Original data/art and all unrelated uncommitted work are preserved. No player saves are used by tests.

Baseline: after the introductory-roster fix, Standard17 still suffered an opening casualty, then two defeats and campaign failure at threat10. A fresh prepared-party baseline (legal training and resting injured companions) also ended after one victory/two defeats. Its replacement policy initially produced duplicate Rangers; the revised simulation fills the missing Knight/Ranger role. Consequently final simulations demonstrate viability but are not a controlled estimate of the balance change alone.

## Exact changes

| Rule | Before | After |
|---|---|---|
| Modern campaign maximum opposition by prior victories0/1/2/3/4 |2, then ordinary templates up to4|2/2/3/3/3; template roles retained as a stable prefix; elite leader retained|
| Ignored-offer threat per mission resolution |Sum of ignored offers, normally2|Capped at1 per board|
| Failed-mission Supplies |4|12|
| Rules configuration version |1|2|

Starting Supplies30, recruitment12, training8→20XP, mission XP10+15, success Supplies22, recovery Supplies14, threat start2/max10, failure threat2 and victory threat−1 remain unchanged. Severe injuries3 future resolutions, strain2, rest recovery2/deployed1 and penalties−3HP/−0.5m remain unchanged. No hidden stat multipliers or guaranteed victories. Three repeated losses can still end the campaign; the increased failure reward is not an unlimited farming route.

A normal victory now changes threat by at most0 (−1 mission +at most1 ignored), while a failure adds at most3. A recovery offer/finale may produce less ignored threat. Recovery is a choice between deploying veterans, resting injuries, training reserves and spending Supplies; dead heroes remain permanently lost and receive no XP.

Editable values: definitions/campaign/lantern_watch.tres and scripts/campaign_definition.gd. The earlier two-unit introduction remains. Legacy specialist campaigns retain their original roster composition; the new economy/threat settings apply after migration. Skirmish rosters, enemy definitions and difficulty multipliers are unchanged.

## Persistence and interface

Campaign save schema stays2. A captured actual pre-change v2 content fingerprint is explicitly supported, alongside the existing shipped v1 migration. Their rules version upgrades transactionally to2 before validation. Unknown content, corrupt data and future formats remain rejected. The regression fixture is an isolated generated campaign save, not a user file.

Existing money, threat, heroes, inventory, processed result IDs and frozen mission offers are preserved. No retroactive reward is granted and committed missions are not rerolled. New generation uses the new caps; loading an already-ended campaign does not reopen it.

HQ setup help explains training/rest and the new failure consequences; mission details display the actual configured ignored-threat cap. Debriefs show when ignored threat was capped and the authoritative final total. This is a text clarification within existing screens, not an interface redesign.

## Regression work

New campaign_recovery_tests first reproduced21 failing assertions. Tests cover casualty consequences, affordable reserve training, permanent loss/XP rules, no immediate injury recovery, duplicate reward rejection, rest recovery, pressure after a victory, valid bounded compositions across difficulties/stages and transactional old-save loading with unchanged offers. The saved-offer assertion compares normalized validated JSON values on both sides, retaining full structural equality.

An initial resource-order mistake prevented new values from loading; it was fixed by assigning the script before custom properties. Earlier failures remain in verification/campaign-balance/green. Two earlier suites also printed zero assertions and then exited0xC0000005; these remain failed native-process evidence, not passes. A fresh suite runs under verification/campaign-balance/final.

## Verification and remaining limitations

Final focused rule/save/composition run: **10/10 clean passes**, including actual old-v2 migration, shipped-v1 compatibility, strict save integrity and342 normal composition cases. Final data is in verification/campaign-balance/final/results.json. Six campaign simulations completed with exit0, zero harness failures and no error records. Results: verification/campaign-balance/play/simulations.json. Simulations use actual generated scenes, navigation, commands, AI, effects, actions and outcomes. Only presentation/movement speed is accelerated; normal budgets and damage remain unchanged. The early-loss scenario applies a labelled immutable development result, then plays real subsequent battles. It is not presented as a manually played first battle.

No human playtest, rendered UI inspection, Windows release export or complete87-suite regression is claimed for this tuning pass. The existing native shutdown access violation remains an unresolved release risk. Human balance is provisional even when simulated campaigns win. Stop before roadmap Milestone2 (Reliability and Windows Build).

### Campaign outcomes (actual commands)

| Scenario | Real battles | Victories | Campaign result | Final threat |
|---|---:|---:|---|---:|
| Standard7 |5|2|Defeat|10|
| Standard17 |8|4|Defeat|10|
| Standard423 |6|5|Victory|4|
| Standard17 after explicit early-loss fixture |5|3|Defeat|10|
| Easy17 |5|5|Victory|1|
| Hard17 |5|2|Defeat|10|

Total:6 clean campaign runs,34 real battles,21 victories/13 defeats. The recovery run has one additional synthetic initial mission result, not counted as a real battle. `passed` in the runner means technical completion, not campaign victory.

Standard423 is the strongest recovery example: three victories, a real mission defeat killing both deployed companions, legal preparation of the remaining roster, then two more victories including the finale. Standard17 improved from one victory/two losses in the prepared baseline to four victories/four losses; composition and preparation both differ, so this is not a controlled causal win-rate estimate. The early-loss fixture left42 Supplies/threat5; reserve training was affordable and subsequent real missions produced three victories before later defeats. No hidden grants, retries, modified hero stats or free actions.

Standard remains demanding: two of three sampled campaigns lost, often in three-enemy or elite encounters. The sample does not justify weakening every later enemy or claiming acceptable human win rates. Evaluate those fights with human players before further tuning. This milestone provides a measured first balance/recovery pass, not definitive balance signoff.

### Reproduction

```powershell
$Godot = './verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe'
./tests/run_regressions.ps1 -Godot $Godot -Category all -TestNames campaign_recovery_tests,recruit_opening_tests,campaign_tests,roster_campaign_tests,roster_save_tests,persistence_tests,save_integrity_tests,mission_template_tests,mission_replay_tests,faction_compatibility_tests -TimeoutSeconds 180 -ReportDirectory ./verification/campaign-rules-review
./tests/run_campaign_balance.ps1 -Godot $Godot -ReportDirectory ./verification/campaign-play-review
```

Use fresh report directories and private writable APPDATA/LOCALAPPDATA/TEMP/TMP for the regression runner. The campaign runner isolates/restores those itself. Failed earlier runs remain on disk; no automatic retries erase them. The initial simulation launch had a PackedStringArray.any harness parse error, which was fixed by using the existing Array API and adding a parse preflight to the runner. All six reported scenarios were then actually executed.

Manual checklist: load a real existing save and verify its offers; start a fresh Standard campaign; lose/extract a companion; train an affordable reserve and rest an injury; inspect debrief pressure/rewards; choose Hold Ground/Extraction as well as Elimination; test all class pairs and optional elite offers. Review the largest UI scale for expanded help text. None of these manual interactions or exported-build checks is claimed here.

Important files: scripts/campaign_definition.gd, scripts/campaign_state.gd, scripts/campaign_save_codec.gd, scripts/campaign_screen.gd, definitions/campaign/lantern_watch.tres, tests/campaign_recovery_tests.gd, tests/legacy_campaign_balance_v2.json, tests/recruit_opening_tests.gd, tests/campaign_tests.gd, tests/run_regressions.ps1, tests/run_campaign_balance.ps1 and dev/campaign_balance_audit.gd. Related README/report links were updated. No commit was made and pre-existing work was retained.
Final integration: **7/7 clean passes** (interface, objectives, difficulty, campaign flow, headquarters, save flow and modern roster flow). Together with the10 rule/save/composition suites, **17/17 targeted suites passed**. Source import/type checks and git diff whitespace checks passed. These are scoped regressions, not a new run of the full89-suite category.
