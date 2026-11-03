# Milestone 3 — Onboarding and Tactical Clarity Implementation Plan

> **For agentic workers:** Use the executing-plans skill to implement this plan task-by-task after user approval. No implementation is authorised by this draft alone.

**Status:** Approved and implemented, 29 October 2026. Scoped regression and resource-pack smoke checks pass; the enlarged-text native tutorial review remains failed with a Windows access violation. See docs/ONBOARDING_MILESTONE_3.md.

**Goal:** Teach players the current combat and campaign rules without requiring developer knowledge or replacing working systems.

**Architecture:** Retain TutorialDirector/TutorialEncounter for basic combat. Add a small optional rescue lesson using existing commands and a separate encounter-local director, and contextual headquarters guidance using the existing campaign coordinator and help overlay. Shared help formatting reads current definitions, bindings and validation results; it never determines combat legality or awards campaign rewards.

**Tech stack:** Godot4.7.2, typed GDScript, existing OathUI, ControlBindings, GuideOverlay, preference storage and dependency-free tests. No external assets or packages.

**Spec:** Latest five-milestone roadmap: Milestone3 is Onboarding and Tactical Clarity, not the historical More Mission Variety milestone. Scope includes recruits, specialisation, downing, carrying/extraction, injuries, threat and actionable feedback. The existing rules-v2 campaign balance is authoritative.

## Findings from the current source

- The fixed basic tutorial already teaches camera input, path preview, movement before/after an action, melee, enemy turn observation, Crippling Shot and Elimination. It uses private training opponents which hold position. Preserve it and state this distinction clearly.
- TutorialDirector observes authoritative completion/turn/result signals; skip/restart/menu, pause and completion preferences already exist.
- Campaign survival and recruitment are newer than the guided sequence. Existing help is mostly prose and does not walk through readiness or rescue.
- FieldGuide.objective says both Extraction heroes must stand at the exit, omitting the carried-companion rule. Mend guidance omits revival of eligible downed/stabilised allies.
- PlayerController rescue messages hard-code Esc; ControlBindings.instructions replaces click wording but not Escape labels. Rebound controls can therefore disagree with guidance.
- CombatHUD has working rescue buttons/shared survival help. CampaignScreen already displays readiness, costs, injuries, adjusted definitions, mission previews and debrief consequences; refine these instead of creating competing screens.
- Native shutdown faults and the missing Windows release template remain separate Milestone2 risks. This plan does not claim to resolve them.

## Approach and alternatives

**Recommended: modular guidance.** Keep core combat training, offer a separate rescue practice exercise, and teach campaign management contextually in the real headquarters. Everything is skippable/reopenable and normal campaigns retain full freedom.

Text-only help is smaller but would not teach carrying/extraction through actual interaction. A single mandatory campaign tutorial would be longer, risk overwriting progress and tightly couple guidance to campaign rules. Neither is recommended.

## Global constraints

- No balance changes, new mechanics, forced purchases, free campaign resources or changes to permanent death/objectives.
- Real commands pass through CombatController; only successful authoritative outcomes advance gameplay exercises.
- Use current InputMap labels and current definition values. Do not hard-code costs, penalties, durations or thresholds in reusable guidance.
- Tutorial fixtures use private runtime state and never replace or autosave into the active campaign slot.
- Preserve existing tutorial completion and settings. Rescue practice need not add new persisted progress flags.
- Camera, help, settings and confirmed exit remain available. Blocking briefings use existing pause ownership; nonblocking hints do not quietly pause/resume combat.
- No unsafe partial-state rewind; restart the current isolated exercise if its requirements become impossible.
- No UI redesign, roster-management overhaul, new asset dependency or automatic camera movement that fights player input.
- Preserve unrelated local changes. No commit/export or later milestone without separate authorisation.

## Phase A — Shared, accurate explanations

Files: scripts/field_guide.gd, control_bindings.gd, combat_hud.gd, player_controller.gd and existing tooltip support.

- [ ] Add failing checks for carried Extraction, revival versus permanent death, current bindings and separate movement/action availability.
- [ ] Correct objective/survival/Mend descriptions and distinguish downed, stabilised, carried, extracted and dead.
- [ ] Centralise small reusable explanation helpers reading definitions/rules and shared validation. Keep targeting legality in CombatController.
- [ ] Explain range/obstruction, cooldown timing, Slowed, ward and forced displacement where relevant; retain a safe inspect-and-cancel Fireburst tip.
- [ ] Give unavailable actions a specific reason and a useful next step, without promising that an invalid command can succeed.
- [ ] Verify rebound cancel/world-confirm labels throughout rescue/help/ability prompts.

Deliverable: help and previews accurately describe the implemented game.

## Phase B — Preserve and refresh core combat training

Files: scripts/tutorial_director.gd, tutorial_encounter.gd, scene_flow.gd and tutorial tests.

- [ ] Keep the existing camera→preview→move→attack→move again→end turn→ability→victory sequence and shared-action demonstration.
- [ ] Identify current class names/models consistently; explain that normal enemies fight back while these training opponents hold position.
- [ ] Ensure instructions use the actual bound controls and selected ability data.
- [ ] Review repeated clicks, cancelled targeting, blocked movement, missing actors, unexpected deaths, skip/restart and exit.
- [ ] Preserve existing completion semantics and preferences; do not mark gameplay demonstrations complete after a button click or timer.

Deliverable: existing training remains short, accurate and safely replayable.

## Phase C — Optional rescue practice

New small files proposed: scripts/rescue_tutorial_director.gd and scripts/rescue_tutorial_encounter.gd. Reuse GuideOverlay, HUD and encounter setup; do not build a generic dialogue/quest framework.

- [ ] Add a labelled rescue-practice choice within Tutorial/help and after the basic lesson, without replacing the current campaign.
- [ ] Author a fixed navigation-validated training layout with private units and an explicit training-only enemy policy submitting legal commands.
- [ ] Teach an actual incapacitation, stabilisation, action spending, ending a turn, carrying with reduced movement, entering the retreat zone and extraction.
- [ ] Observe completed rescue/movement/turn events and actual unit life states. Rejected commands, previews and effect callbacks cannot complete steps.
- [ ] Explain revival as optional help, including space-to-stand requirements; do not require every ability or class in the lesson.
- [ ] Explain that safe extraction can preserve companions while the tactical mission still counts as a failure. A lesson-complete message must not rewrite the combat outcome into a victory.
- [ ] Offer Restart Exercise/Skip/Exit if a required actor is lost or an action path becomes impossible. Always clean restrictions, signals, markers and pause ownership on exit/restart.

Deliverable: players can practise rescue without risking a campaign hero or save.

## Phase D — Contextual campaign orientation and decision feedback

Files: scripts/campaign_screen.gd, campaign_coordinator.gd, field_guide.gd; optionally one small campaign_onboarding.gd if needed to keep guidance separate from screens.

- [ ] Offer dismissible/reopenable orientation explaining recruits, two-person deployment and the existing camp locations. Never force spending or class choices.
- [ ] Show the path to specialisation: current XP/level, threshold, optional paid training, permanence and available classes.
- [ ] Clarify readiness: adjusted health/movement, injury recovery when resting versus deployed, replacement/training costs and current funds.
- [ ] Before deployment, show authoritative enemy roles, objective-specific survival requirements, defeat/abandonment consequences and expected threat/reward changes including the board cap.
- [ ] Use current result/commit data for debrief explanations: who survived/died, injury/recovery, XP, funds and threat. Do not recalculate or apply results in UI.
- [ ] Observe accepted, persisted coordinator mutations when advancing contextual guidance; clicking a rejected purchase/training button is not success.
- [ ] Keep tutorial/guide state out of campaign rules and snapshots. Existing tutorial completion stays compatible; guidance remains reopenable and does not lock normal play.

Deliverable: a new player understands preparation and consequences before committing.

## Phase E — Integration, verification and handoff

- [ ] RED→GREEN focused tests for explanatory text/data, bound controls, rescue lesson progression, rejected/cancelled actions, missing actors and guidance cleanup.
- [ ] Extend tutorial/usability tests; reuse rescue validation, campaign recovery, save/flow, objective and settings lifecycle suites.
- [ ] Protect existing saves/settings with isolated user folders. Verify entering/leaving either lesson cannot modify a real campaign or mark unrelated lessons complete.
- [ ] Complete the basic lesson and rescue lesson through real commands; test restart/skip/exit at early/middle/late steps and repeated scene transitions.
- [ ] Run normal skirmish and campaign smoke flows after leaving training, including an early casualty and loaded campaign.
- [ ] Inspect1280×720 and1920×1080, enlarged UI/text, keyboard focus, tooltip bounds and remapped controls. Capture actual renderer screenshots where available.
- [ ] Attempt production-pack checks only where tooling permits; distinguish source, packaged runtime and standalone Windows verification. Retain all failures.
- [ ] Deliver a change/test report plus a short human playtest checklist. Stop for review; do not start Milestone4.

## Definition of done

A player can learn basic combat, practise rescue, understand specialisation and prepare a party without debug knowledge. Instructions match actual controls and rules. Invalid/cancelled actions cannot deadlock guidance. Lessons cannot damage campaign progress. Existing campaign/combat regression checks pass, and unavailable visual/export checks are explicitly reported.

Automated completion is not proof of new-player usability. Human testers should independently explain action versus movement, cooldowns, downed versus dead, safe extraction versus mission success, and training/recovery costs after playing. Observe where they hesitate before adding more prompts.

## Review focus

- Extraction with a carried companion versus standing units; no false mission-victory teaching.
- A downed required actor, blocked carry route, unavailable shared action or unexpected death; safe restart rather than a stalled lesson.
- Rebinding while guidance is visible; hints update and UI input never issues a world command.
- Pausing, skipping or returning to menus during an action; no stale restrictions or callbacks in a later encounter.
- Existing campaign loaded before entering training; save, roster, funds, offers and completion preferences remain intact.

## Approval requested

The user approved this plan. Phases A–E were implemented. Final evidence: 18/18 scoped source suites, four existing resource-pack smoke phases and the standalone onboarding pack smoke passed. Native default-size tutorial reviews and the 19-image showcase passed; enlarged-text native tutorial shutdown failed. No later milestone was started.
