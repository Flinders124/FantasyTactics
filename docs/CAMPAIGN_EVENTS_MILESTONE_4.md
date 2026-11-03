# Milestone 4 — Campaign Events and Character Identity

Implementation and verification report, 29 October 2026. Work stops for user review before milestone 5.

## Implemented scope

The existing camp now offers eight short authored event templates, deterministic descriptive backgrounds for companions, personal service records and memorial dossiers. It uses the existing interface, campaign coordinator, combat results and transactional save store. No combat stats, AI weights, action allowances or mission generation rules were changed.

### Player flow

After a non-final mission, read the debrief and return to camp. A pending-decision banner opens the event. Exact costs and effects appear before confirmation. Decide Later preserves the offer; resolve a choice or explicitly decline before deploying again. The History page also reopens the decision. Settings, help, training and equipment remain accessible; choices are revalidated when committed.

Open Service Record from the roster, training or armoury cards. Dossiers show the actual character portrait/stats, background, purpose and recorded service. The same link is available for fallen companions. Backgrounds are descriptive and have no stat modifiers.

## Initial event catalogue

| Event | Eligibility | Choice A | Choice B |
| --- | --- | --- | --- |
| The Broken Waycart | Living companion | +4 Supplies | Leave a repair cache; narrative only |
| A Herbwarden’s Visit | Injured companion | -4 Supplies, recover one existing injury step | +3 Supplies |
| The Quiet Watchfire | Living companion | +2 Supplies | Listen; narrative only |
| Lessons by Lamplight | Specialist | +3 Supplies | Record lesson; narrative only |
| A Passing Caravan | Living companion | +6 Supplies | Share directions; narrative only |
| A Name at the Fire | A previous roster death | Memorial stone; narrative only | Letter home; narrative only |
| An Hour of Shelter | Injured companion | Recover one existing injury step, free | +2 Supplies |
| The Quartermaster’s Ledger | Living companion | +3 Supplies | Record makers; narrative only |

Every event also offers an explicit neutral decline. No item is removed or created by narrative salvage/trade text. Choices grant no XP, new abilities or statuses. Event resources reject values outside -6 to +6 Supplies and zero/one recovery step. Spending protects the existing recruitment reserve. An already recovered participant cannot consume treatment supplies.

At most one decision follows a mission resolution and at most four occur per run. Resolved templates do not repeat. An ended campaign produces no decision; events cannot reverse victory or defeat. Eight backgrounds cover ferryman, mason, herbalist, scribe, shepherd, courier, forge hand and gardener. Assignment uses a dedicated seed stream based on the campaign seed and persistent hero ID.

## Persistence and lifecycle

Save/state schema advances from 2 to 3. Explicit v1 and v2 migration retains names, equipment, XP, injuries, processed results and frozen mission configurations. Legacy dossiers begin with a truthful Record Begins Here entry and acquire no retroactive event/reward. New service records retain up to 64 entries; existing lifetime mission counters remain separate. Up to four event records and their processed IDs persist.

Pending events store their original bounded text, choices and effect amounts. After an authored event revision increases, old pending offers keep their displayed prices and resolved records remain readable; future revisions and missing template IDs fail safely. Content changes must increase the event revision. Campaign identity and scene epoch guards prevent cached confirmation callbacks from affecting a later campaign.

Existing campaign mission timing is retained: rewards/threat/recovery/new injuries/outcome, frozen next offers, then one eligible event. Selection never advances the mission or decoration random stream. The coordinator saves a complete choice through its existing rollback boundary. Invalid choices and failed writes spend nothing. Tutorial and skirmish flows do not schedule events.

## Verification

Final Godot 4.7.2 import/type checking and **22/22 scoped regression suites passed**, with exit zero, explicit zero assertions and empty stderr. Raw results: verification/campaign-events/final/results.json. Tests use isolated saves, never the active player slot.

Coverage includes all 24 authored choice branches, ten fixed event seeds, deterministic identities, all six specialisations, bounded personal records, real v1/v2 save fixtures, interrupted deployments, permanent death/replacement, a five-victory state-driven campaign, final-outcome precedence, neutral declines, recruitment reserve protection, stale participants, invalid content, future revisions, duplicate resolution and actual treatment rollback after failed persistence. Flow tests cover settings access and five repeated camp/dossier cycles, plus cached confirmation rejection after a same-seed campaign replacement. Existing campaign_flow tests exercise all six original hero-pair deployments in real generated encounters.

After fixes, a fresh native renderer run again passed and regenerated the 16 screenshots. Resource-pack export passed. The existing four-phase pack smoke test passed across separate processes; it restored an interrupted mission, completed an actual encounter (VICTORY, 6 rounds), and restored its debrief without reapplying rewards. The new standalone external campaign-events pack harness passed pending/resolved saves, once-only choice effects, dossier opening and next interrupted-deployment restoration. This is PCK-with-Godot testing, not standalone EXE testing. Detailed, sanitized evidence: docs/campaign-events/verification.json.

Regression command: `./tests/run_regressions.ps1 -Godot verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe -Category events -TimeoutSeconds 240 -ReportDirectory verification/campaign-events/local` (use isolated APPDATA/LOCALAPPDATA). The report preserves earlier intentional failing tests as evidence; only the final run is the passing result. `git diff --check` passed, with environment/line-ending warnings. The complete repository-wide suite was not run.

The initial native showcase executed with Godot 4.7.2 Compatibility/OpenGL on Windows, NVIDIA RTX 500 Ada Generation Laptop GPU, driver 596.71. Sixteen actual-renderer screenshots cover headquarters, event choices, confirmation and dossier at 1280x720 and 1920x1080 with default and maximum supported UI scale/large text. Real mouse clicks opened and confirmed decisions. The run exited zero with zero assertions and empty stderr. Representative event/dossier720p enlarged text, headquarters720p enlarged text and confirmation1080p screenshots were inspected directly.

## Limitations and human review

Event economy tuning is provisional: automated tests do not establish whether Supplies/recovery choices feel balanced or narratively engaging. There is no relationship/morale system, hidden trait bonus, new art or branching dialogue framework. Histories begin at migration for old campaigns rather than inventing past details.

The previously documented intermittent native Windows shutdown access violation and missing standalone Windows release template remain external release risks. A passing PCK smoke test is not standalone EXE certification. No full human campaign playtest or independent performance benchmark is claimed for this milestone.

Manual playtest: load a copy of an old campaign; complete a mission; inspect dossier, event choices and exact consequences; cancel confirmation; reopen; accept once; close/relaunch and continue. Treat an injured participant before choosing event treatment and verify the stale option disables without spending. Complete or decline four events; finish or lose the campaign and verify no extra decision. Review a casualty memorial and a replacement recruit. Check keyboard focus, scrolling and enlarged text at both resolutions.

## Main files

New: scripts/campaign_events.gd, campaign_event_definition.gd, campaign_background_definition.gd; editable background/event resources; four focused source suites; external resource-pack smoke harness; dev/campaign_events_showcase.gd and screenshots.

Integrated: campaign_state.gd, campaign_save_codec.gd, campaign_coordinator.gd, campaign_screen.gd, field_guide.gd and regression runner. Legacy test fixtures explicitly decline decisions where they exercise unchanged pre-event balance.

## Defects found during implementation and fixed

- JSON numeric versions needed normalization before membership validation; genuine old/current saves now round-trip.
- Duplicate scheduling could prepare a second decision for the same resolution; a per-resolution guard prevents it.
- Editable event definitions could exceed the approved economy envelope; definition and saved-snapshot boundaries now validate it.
- Recovery logs recorded the available recovery budget instead of actual steps removed; service and debrief text now report the true amount without changing healing.
- Matching only the current event revision would invalidate historical campaigns after content updates; bounded prior-revision snapshots are retained.
- A cached confirmation could affect a replacement campaign with the same seed; campaign ID/scene epoch guards reject it.
- History displayed a structured decision and its raw log entry twice; presentation now shows it once.

Each significant fix has a focused red-to-green regression. One independent read-only review contributed the recovery and revision findings.

## Release and review status

Implemented and verified in the scoped source/native/PCK flows. Economy and narrative quality still need human playtesting. No new critical blocker was reproduced in these tested flows; testing does not prove absence of all bugs. The existing intermittent Windows native-shutdown crash remains unresolved even though both new showcase runs exited cleanly. The configured Windows template `C:/work/export-templates/windows_release_x86_64.exe` was checked and is absent, so no new standalone Windows executable was exported or certified. No commits or milestone 5 implementation were performed.
