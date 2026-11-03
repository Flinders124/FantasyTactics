# Opening Campaign and Headquarters Progression Implementation Plan

> After user approval of the design, use executing-plans inline and focused red/green tests. User authorised the full discussed milestone on 2 November 2026.

**Goal:** Deliver the complete campaign loop with purchased 3/4-hero capacity, visibly growing camp, level-gated equipment/shop/slot UI and a reproducible premium trader.
**Architecture:** Keep tactical legality in CombatController, generation in BattlefieldGenerator, and persistent operations in CampaignState through existing coordinator save/rollback. Small editable headquarters rules and equipment/trader helpers extend existing definitions. New equipment art is UI-only; do not imply corresponding equipped 3D meshes changed.
**Tech:** Godot4.7.2 typed GDScript, dependency-free suites, existing OathUI and camp kit.
**Spec:** docs/superpowers/specs/2026-11-02-opening-squad-shop-design.md.

## Global constraints and rulings

- Preserve uncommitted prior milestones, all old saves/encounter codes and exact two-hero generation streams/layouts.
- Command upgrades20/30 Supplies after victories1/2; optional deployment2..capacity, never free heroes or actions.
- Equipment slots weapon/garb remain available at1, helmet2/accessory3, advanced equipment4. Preserve old equipment and stat calculations.
- Trader after each two completed mission resolutions; three frozen limited offers, leaves on committed deployment, price30..45. Purchases never equip. Keep reserve protection and exact-once saves.
- Campaign Extraction requires all originally deployed heroes alive/safe; tutorial/skirmish defaults remain2.
- Save schema migrations validate old exact shapes, no retroactive purchases/visits. Use isolated test files. No player save access.
- Avoid multiplayer, extra combat rules, classes, construction systems, crafting or unrelated refactoring.
- Test at720p/1080p/maxUI, native review and PCK smoke when available; never claim missing Windows EXE template/native crash risk fixed.

## A — Squads, command upgrades and compatibility

- [x] Capture real v3 initial/interrupted fixtures and baseline tests.
- [x] RED: capacity purchases, selection2/3/4, duplicate IDs, encounter code roundtrip, spawn/objective/result and old-save tests.
- [x] Add editable HeadquartersRules. Extend CampaignState capacity and purchases, EncounterConfiguration/Code version4 for larger parties, layout hero_count/generator extra spawn positions without changing old RNG.
- [x] Extend CombatEncounter spawning/IDs, ObjectiveController, briefing/HUD text and save codec party/result validation. Migrate schema3 to4 with capacity0 and trader empty.
- [x] GREEN: real3/4-hero navigation/turn/death/extraction/interrupted restore and legacy regression.

## B — Equipment/shop/character integration

- [x] RED: level/class gates, shop-only purchases, owned variant persistence, all four slots, transfer uniqueness, failed-save rollback.
- [x] Extend item configuration with default-compatible level/rarity/art fields. Keep old fingerprints stable. Add curated helmet/accessory/advanced gear resources and exact tuning table.
- [x] Refine Armoury to shop cards and shared inventory, no equip controls. Add character/dossier slot selection and compatible owned chooser, actual previews, transfer confirmation and empty/locked feedback.
- [x] Use generated art with rarity labels; keep art variants immutable per owned item.
- [x] GREEN: stat isolation, gates, UI routes, old equipment and transactional tests.

## C — Visiting trader

- [x] RED: visit timing, decline/failure/abandon count, deterministic three offers, stock purchase-once, no refresh/reload rerolls and write failure.
- [x] Add bounded separate-seeded stock helper and frozen persistent offers. Arrival only after authoritative resolution; departure only after successful deployment commit (rollback restores stock).
- [x] Add trader UI using existing shop conventions; display next arrival, price, availability, rarity and requirements.
- [x] GREEN: all timing, save/load/interruption and stock safeguards.

## D — Camp visuals and opening pacing

- [x] RED: tier-dependent presentation, conditional trader interaction, camp camera/labels/settings, unchanged battlefield geometry.
- [x] Build distinct command tent tiers, extra shelters/stores/paths and merchant stalls using existing kit. Preserve navigation and history access; extend destination handling only as necessary.
- [x] Improve new-campaign opening offers/briefings with clear teaching progression and two bounded existing enemies, no hidden scaling to hero count. Preserve frozen legacy mission offers and rules.
- [x] Measure representative2/3/4 party encounters through real commands; tune only demonstrated failures and document provisional balance.

## E — Regression and delivery

- [x] Run new tests plus campaign/events/persistence/roster/objectives/navigation/onboarding/settings regressions; reproduce/fix failures, keep logs.
- [x] Native screenshots for shop, slots/chooser, trader, all command tiers and larger-party combat at both sizes/maxUI. Test keyboard focus, scrolling, pause and repeated transitions.
- [x] Fresh read-only review of complete delta; fix actionable findings with regressions.
- [x] Export PCK and execute external smoke if available; distinguish from unavailable Windows EXE.
- [x] Report changes, exact settings, measured encounter outcomes/timing, verified/unverified checks and known limits. Stop before the next milestone.

## Review focus

Purchase double clicks/write failure, old codes preserving old layouts, extraction with carried/missing actors in3/4 parties, save migration with existing equipment, trader stock freezing across reload and late eligibility changes, extra AI/turn work cancellation during menu transitions, large-text UI, presentation-only camp growth.


## Completion evidence

Final31/31 selected source suites passed,90 larger-squad live maps and6 real-command opening encounters. Full native UI run plus enlarged-text/keyboard-focus follow-up passed. Production PCK export, external headquarters smoke and4 existing production smoke phases passed. No standalone EXE template was available. Details, tuning,26 screenshots, failed intermediate runs and deferred minor: docs/HEADQUARTERS_MILESTONE_1.md. No commit or next milestone started.
