# Milestone 3 — Onboarding and Tactical Clarity

Implemented against the approved29 October2026 plan. This is the latest roadmap Milestone3, not the historical mission-variety milestone. Campaign balance, combat rules, roster definitions, progression and saves retain their existing semantics.

## Player-facing changes

- **Basic Tutorial** retains camera, real route preview, move/attack/move, turn observation, ranged ability and victory. Cooldown instructions read the equipped definition; completion remains tied to actual gameplay. The completion message points to optional rescue practice.
- **Rescue Practice** is available from the title, camp and basic-tutorial sidebar. It is a separate fixed encounter using the same courtyard kit, models, navigation, collision, HUD and commands. It teaches downing, approaching, stabilising, the shared action, ending a turn, carrying with half movement, moving to safety and extracting.
- Practice uses a privately prepared low-health training companion and one legal enemy move/basic attack; later training enemy turns legally end. Normal hero definitions and tactical AI are unchanged. There are no free player actions or damage callbacks in presentation.
- Both companions extracting completes the exercise while the real tactical result remains retreat/DEFEAT. The text explains that safety is not mission victory. No rewards, campaign writes or basic-tutorial completion flag are granted by practice.
- **Camp Guide** is dismissible/reopenable, session-local and based on actual roster readiness. **Camp Rules** explains current XP thresholds, optional training, permanent class choice, recruitment, injuries/rest, Supplies, threat and interrupted-mission saving. Accepted changes are observed only after persistence succeeds; rejected/rolled-back changes do not advance guidance.
- Mission preparation keeps a compact commitment summary visible. Detailed consequences and readiness warnings use the existing scroll area, preserving space for hero cards. Actual adjusted stats, injuries and enemy roles remain authoritative.
- Help now distinguishes downed/stabilised/dead, explains Mend revival and space-to-stand, and documents carried companions and automatic objective completion for Extraction. Basic attacks, abilities and rescue share one action; movement remains separate.
- Rescue prompts and open menu/combat help follow current bindings, including changes applied while help remains open. Alternate cancel labels are safe to format repeatedly. Long guides support Page Up/Page Down while keyboard focus remains visible.
- Rescue practice hides unrelated ability-row clutter and derives button availability from the same pure teaching policy used for acceptance. Normal combat controls retain their existing behaviour.

## Safety and lifecycle

All practice player commands go through CombatController. Its existing range, obstruction, occupancy, movement-budget and action checks remain intact. Command-policy restrictions are guidance only. Actor overrides in normal EncounterConfiguration were **not** relaxed: the private training hero is prepared only on the explicit rescue-practice spawn path.

Practice is not a campaign deployment and never binds the campaign-result processor. A test preserves the campaign snapshot and exact save bytes across completion, repeated restarts, failures and exits. Existing tutorial completion/preferences are preserved. Camp-guide dismissal is session-only; no new campaign fields or preference schema were added.

Blocking help/settings use existing pause ownership. The scripted opponent checks pause and encounter freshness; it performs at most one introductory move/attack and cannot queue player actions. Exiting/restarting cancels its work, restrictions, markers and pending presentation. Missing actors, premature death or an unaffordable blocked route offer full exercise restart rather than unsafe partial-state rewinds.

## Verification

Baseline before changes: tutorial_tests and usability_tests both passed. New checks were written failing first for the help gaps, missing rescue entry, committed-change observation, result-overlay refresh, practice control clutter, deployment layout, keyboard paging and live rebinding. Failed attempts remain under verification/onboarding; no assertions were removed to produce green results.

New focused tests: onboarding_help_tests, onboarding_bindings_tests, onboarding_campaign_tests and rescue_tutorial_tests. The `onboarding` runner category includes the relevant tutorial, rescue, campaign, settings, input, interface, save and transition regressions. Final consolidated results are recorded in verification/onboarding/final2/results.json; packaged checks are recorded separately.

A read-only final code review found stale already-open help after rebinding. That finding was reproduced with3 failed assertions and fixed with preference-aware text providers and idempotent cancel formatting. The targeted binding/help run then passed2/2. No other concrete blocker was reported by that review; this is not a guarantee of bug absence.

### Actual renderer checks

Nineteen real-renderer screenshots are in [screenshots](onboarding/screenshots). Captures cover title, camp guide/rules, mission preparation, approach/stabilise/carry/complete at1280×720 and1920×1080, plus maximum UI scale1.15 with larger text at720p. These are implemented game screens, not mockups. Native runtime: Godot4.7.2 standard Windows, Compatibility/OpenGL3.3, NVIDIA RTX500 Ada Generation Laptop GPU, driver596.71. Dummy audio was used; no listening assessment or FPS claim.

The existing rendered-input basic tutorial review completed the encounter, help, replay, cancellation and skip paths at both resolutions and enlarged text with zero gameplay assertions. Early review runs emitted6 ObjectDB cleanup warnings. Explicitly retiring scenes and freeing the harness-owned offscreen viewport removed those warnings in fresh720p/1080p runs, which exited cleanly. The fresh enlarged-text run still ended with Windows0xC0000005 after printing zero assertions: **that process remains failed**. Its screenshots/assertions are evidence of exercised UI, not a passing stability check.

The new onboarding showcase exited cleanly. Native screenshots exposed a squeezed hero list and cluttered practice ability row; these were corrected and protected by layout/policy tests. Before-layout evidence remains in verification/onboarding/before-layout.

### Outstanding stability/build limits

One final import attempt returned nonzero after a completed log without parser diagnostics. The original wrapper did not retain its native exit code, so its precise cause is unknown. It is retained as a failed import under verification/onboarding/final. The runner now includes the import exit code in future failures. Fresh source verification runs under final2; it does not erase earlier evidence.

The previously documented intermittent native shutdown access violation remains unresolved. No standalone Windows executable was exported or certified; the matching Windows release template is still absent. Resource-pack tests use the installed engine and are not equivalent to a standalone release. Human new-player usability, subjective readability and all class/objective strategies remain unproven by automation.

## Reproduce

```powershell
$Godot = './verification/toolchain/standard/Godot_v4.7.2-stable_win64_console.exe'
./tests/run_regressions.ps1 -Godot $Godot -Category onboarding -TimeoutSeconds 240 -ReportDirectory ./verification/onboarding-review
```

Set private APPDATA/LOCALAPPDATA/TEMP/TMP under a fresh verification directory first; never use player save folders. For actual renderer capture use dev/onboarding_showcase.gd without --headless and with a private user-data environment. Existing tests/tutorial_review.gd exercises actual rendered UI input; its outputs now remain inside the project verification folder and capture failures are checked.

## Short human playtest checklist

1. From a fresh profile, find and finish Basic Tutorial without coaching. Explain movement versus the shared action afterward.
2. Run Rescue Practice; identify downed versus dead, stabilise/carry/extract, and explain why safe retreat is not a mission win.
3. Cancel targets, make an invalid move, pause during movement, restart and leave mid-lesson. Confirm recovery guidance is understandable.
4. Start a campaign, find training/class selection, inspect injury/rest costs and predict mission failure consequences before deploying. Do not require a purchase.
5. Rebind Move/cancel, apply while help is open, and verify displayed controls and actual inputs. Check keyboard focus and Page Up/Page Down.
6. Inspect720p/1080p and larger text, scroll all readiness details, and return from training to an unchanged saved campaign.

Ask players where they hesitated before adding more guidance. No formal accessibility compliance or full keyboard-only combat support is claimed.

## Main files

New: scripts/rescue_tutorial_encounter.gd, rescue_tutorial_director.gd, campaign_onboarding.gd; four onboarding/rescue source test suites; tests/onboarding_pack_smoke.gd; dev/onboarding_showcase.gd.

Integrated: field_guide.gd, control_bindings.gd, tutorial_director.gd, combat_encounter.gd, scene_flow.gd, combat_hud.gd, player_controller.gd, campaign_coordinator.gd, campaign_screen.gd, menu_screen.gd, guide_overlay.gd, tests/tutorial_review.gd and tests/run_regressions.ps1. Existing art and definition resources remain unchanged. No commit or later milestone was started.

## Final verification results

- Godot 4.7.2 source import and all 18 onboarding-category regression suites passed (`verification/onboarding/final2/results.json`).
- Resource-pack export exited zero; all four existing pack smoke phases and the standalone onboarding smoke passed. This verifies the exported PCK with Godot, not a standalone Windows executable.
- Native 720p and 1080p basic tutorial reviews and the 19-capture showcase passed. Enlarged-text native tutorial review failed with Windows access violation 0xC0000005 after zero gameplay assertion failures. This remains an unresolved runtime risk.
- `git diff --check` passed; Git emitted environment/line-ending warnings. No full repository regression, new-player human playtest or performance profile is claimed.
