# Milestone 4 — Campaign Events and Character Identity

> **For agentic workers:** After user approval, use executing-plans to implement these tasks with focused regression tests. This is a proposed design and implementation plan, not authorization to change gameplay.

**Status:** Approved and implemented, 29 October 2026. Final 22-suite scoped regression, native renderer review and PCK smoke checks passed. Human playtesting and standalone Windows EXE verification remain outstanding; see the milestone report.

**Goal:** Give the Lantern Watch companions memorable identities and add short, meaningful headquarters decisions without expanding combat mechanics or replacing existing campaign systems.

**Architecture:** Editable event/background resources hold authored content; CampaignState holds plain persistent identity, event and service records. CampaignCoordinator uses its existing mutate/save/rollback transaction for choices. CampaignScreen presents events and hero dossiers through existing camp pages and styling. Combat remains authoritative and unchanged.

**Tech stack:** Godot 4.7.2, typed GDScript, current dependency-free tests and existing UI components. No new packages, art production or online services.

## Inspected foundation

- CampaignState already assigns stable hero IDs and seeded names. Recruits specialise, gain XP, equip inventory instances, recover from injuries and can die permanently.
- Individual records already contain missions_completed, death_cause, level, equipment and injury state. The camp has roster, training, armoury, history and memorial presentation.
- resolve() guards mission result processing, updates rewards/threat/recovery/injuries, determines the ending and freezes the next board's encounter codes. Preserve this order.
- CampaignCoordinator.mutate() saves accepted changes and rolls state back if persistence fails. Use this boundary rather than saving from a dialog.
- CampaignSaveCodec and CampaignState currently use version 2, exact field validation and definition fingerprints. Adding fields requires explicit migrations; simply appending arbitrary keys will reject saves.
- Campaign history is currently bounded to 60 text lines. It is useful feedback but insufficient as a structured personal service record.
- Native Windows shutdown access violations and the unavailable standalone Windows export template are pre-existing risks. This milestone does not certify or silently fix them.
- No AGENTS.md was found during this inspection. Recheck instructions before implementation.

## Recommended scope and alternatives

**Recommended: authored camp events plus personal records.** Deliver eight concise events and eight short original backgrounds, using existing Supplies and injury-recovery operations. Keep backgrounds descriptive, not stat modifiers.

A records-only pass is lower risk but adds little strategic choice. A relationship/morale/trait simulation would add new balancing, persistence and UI obligations disproportionate to the short campaign. Defer it.

## Player-facing changes

### Character identity

Each recruit receives a deterministic background and a brief personal motivation. Generate these from campaign seed and stable hero ID using a separate identity random stream; never affect mission, roster or decoration randomness. Existing names, classes and equipment remain intact.

Add a dossier to the existing roster: name, background, motivation, current class, current condition and dated service entries. Record only authoritative facts: joining, completed missions and outcomes, specialisation, learned upgrades, injury/recovery and death. Attribute extracted/recovered outcomes only where actual result data supports them; do not invent rescues or kill totals.

Keep the hero's story when they die and link it to their existing memorial. Replacement recruits get new identities. Do not add personality-based combat bonuses, relationships, morale, cosmetic model variations or manual biography editing.

### Camp events

Start with eight authored templates across supply management, recovery, training/mentorship flavour and remembrance. Each has two meaningful choices where applicable plus a neutral defer/decline option. Examples: spend a modest amount of Supplies on an eligible companion's recovery, accept supplies instead of a recovery opportunity, or choose how the Watch commemorates a loss. Display exact outcomes and eligible hero names before confirmation; no hidden rolls.

Proposed tuning envelope for approval: gains at most 6 Supplies per event; costs at most 6 Supplies; recovery at most one step of an existing injury. Do not remove the recruitment reserve, resurrect heroes, grant actions, directly change stats or award new injury/status types. Some events are narrative-only. Do not charge for a no-op recovery or allow currency farming.

Offer at most one event after each non-final mission resolution, no more than four across the normal five-victory run. Stable event IDs, eligibility requirements and once-per-run limits prevent repetition. If no event qualifies, continue normally. Campaign completion takes precedence: never generate an event after victory or defeat, or use an event to reverse an established ending.

Select and freeze the event after existing post-mission processing and next-offer generation. Show it on return to headquarters, not over tactical results. Unresolved events may be closed and reopened; require a choice or explicit decline before the next deployment, with a clear explanation. Training, equipment, settings, help and menus remain accessible; revalidate a choice against current state before committing it.

### Journal and continuity

Keep the existing event/history panel. Add readable event results and an entry point to a pending decision. Use existing roster and history pages rather than a competing headquarters screen. Structured campaign event records and per-hero service records are bounded (proposed 128 and 64 respectively); lifetime counters and processed-ID guards must not be discarded when display history is trimmed.

## Timing, determinism and persistence contract

1. Resolve the tactical mission exactly once using current rules.
2. Apply current XP/rewards/threat/recovery/new injuries and determine campaign ending in the existing order.
3. Generate/freeze the next offers as currently implemented.
4. If still active and eligible, deterministically freeze one pending event with participant IDs, template revision, offered choices and displayed effect amounts.
5. Persist the complete debrief and event atomically through the existing coordinator path.
6. On choice: validate pending instance ID, choice ID, living/eligible participants, costs and campaign phase; apply effects once; record outcome; clear pending event; persist. Failed writes roll back all effects and leave the event pending.

Repeated clicks, loading, reopening a page and interrupted saves cannot reroll events or reapply effects. Interrupted missions retain their existing frozen encounter configuration and deployment policy. Skirmishes and tutorials never run campaign events or acquire persistent identity changes.

Bump to the next save/state schema with explicit migration from currently supported v1/v2 formats. Preserve existing definition IDs, names, mission codes, processed results, inventory and stats. Legacy heroes receive deterministic descriptive identity and a truthful 'Record begins here' entry; do not reconstruct fictional detailed service history. Migration creates no retroactive event or reward. Preserve already-supported fingerprint mappings, reject unknown future formats, and test backup recovery. Save revisions/snapshots needed to keep pending event outcomes stable across content updates; unknown definitions fail safely without overwriting files.

## Implementation phases

### A — Persistent identity and compatibility

- [x] Add failing deterministic identity, independent-record and v1/v2 migration tests using isolated save paths.
- [x] Add small background definition/catalog resources and eight authored backgrounds; extend recruit creation and snapshot validation.
- [x] Add structured per-hero service entries and memorial access; preserve existing counters and names.
- [x] Verify save round trips, unsupported versions, legacy interrupted missions and unchanged derived combat stats. Keep the project runnable.

### B — Event state and transactional choices

- [x] Add failing tests for deterministic eligibility, maximum frequency, once-only effects, recruitment reserve, invalid participants and terminal campaigns.
- [x] Add CampaignEventDefinition resources, bounded deterministic catalog selection and a focused event service with pure eligibility/effect validation helpers.
- [x] Extend CampaignState with pending event, resolved event IDs and records; expose choose_event(instance_id, choice_id) through coordinator.mutate().
- [x] Add eight templates within the proposed tuning envelope. Freeze choices before display; no live rerolls or elapsed-time logic.
- [x] Prove duplicate clicks/reloads and injected save-write failures cannot spend/reward twice or lose a pending event.

### C — Camp integration and dossier

- [x] Add failing flow tests for pending event reopening, deployment gate, explicit decline, stale choice rejection and dead participants.
- [x] Integrate event presentation, choice previews, unavailable reasons and confirmation using existing CampaignScreen/Coordinator and UI theme.
- [x] Add roster dossier/service log and memorial navigation. Preserve camp guide, model previews, keyboard focus and scroll layouts.
- [x] Refresh dynamic help to explain event timing and descriptive backgrounds. Do not teach unimplemented mechanics.
- [x] Verify no double-submit, stale callbacks or tutorial/skirmish contamination across menu/load transitions.

### D — End-to-end regression and review

- [x] Add a dependency-free campaign-events regression category and short deterministic multi-resolution harness using actual CampaignState rules.
- [x] Exercise victory/failure, existing injuries, death, replacement recruits, all six specialisations, interrupted deployment and final campaign results.
- [x] Cover every template and branch, including ineligible/no-event cases, and at least ten fixed campaign seeds for event reproduction.
- [x] Run current campaign, roster, persistence, recovery, onboarding and transition regression suites; keep native failures visible.
- [x] Inspect headquarters, event choices, dossiers and memorials at 1280x720 and 1920x1080, including maximum UI/text settings. Test pause/menu/load and repeated page opening.
- [x] Export and execute the resource-pack smoke path if available. Claim standalone Windows verification only if an actual executable can be exported and launched.
- [x] Deliver event catalogue/effect table, migration notes, test results, screenshots, remaining issues and human playtest checklist. Stop for review before milestone 5.

## Expected files

New focused scripts: campaign_background_definition.gd, campaign_event_definition.gd, campaign_event_catalog.gd and campaign_events.gd (combine catalog/evaluator only if that is genuinely simpler). New definitions under definitions/campaign/backgrounds and definitions/campaign/events.

Integrate scripts/campaign_state.gd, campaign_save_codec.gd, campaign_coordinator.gd and campaign_screen.gd; extend existing field-guide text if needed. Keep CampaignSaveStore's safe replacement strategy. Add campaign_identity_tests.gd, campaign_events_tests.gd and campaign_events_flow_tests.gd, plus runner/docs updates. Do not change combat commands, navigation, AI scoring or unit balance definitions.

## Acceptance and review focus

- Repeated state/seed generates the same identities and pending event without altering mission offers or encounter layouts.
- Choices spend/apply once and survive save/load; invalid choices and failed writes spend nothing.
- A cost cannot strand the roster below its existing recruitment reserve.
- A participant dying, recovering or becoming ineligible never traps deployment; an explicit neutral decline remains available.
- Hero records remain distinct through specialisation, replacements, loading and permanent death.
- Old saves migrate without rerolling offers or retroactive rewards; malformed saves remain untouched.
- Final victory/defeat remains unambiguous; event effects cannot bypass campaign rules.
- UI works with keyboard navigation and enlarged text; no narrative overlay advances combat invisibly.
- Existing combat tuning is unchanged. Event economy tuning is provisional until human playtesting.

## Approval requested

Approve the recommended scope: descriptive backgrounds/service records, eight bounded camp events, explicit safe choices, persistent once-only resolution and existing-screen integration. The user approved the numerical envelope and deployment gate. Implementation is recorded in docs/CAMPAIGN_EVENTS_MILESTONE_4.md; final verification and remaining risks are reported there.

## Final review limits

The completed checks above refer to automated source/native-renderer/PCK testing, not independent human usability or a full human-played campaign. Mouse confirmation flows and scrolling layouts were captured at both sizes; detailed keyboard-only usability remains on the human checklist. The missing Windows template prevents EXE verification. See docs/CAMPAIGN_EVENTS_MILESTONE_4.md for actual test evidence and retained risks.
