# Tactical Situations and Courtyard Architecture Implementation Plan

> Execute inline using executing-plans and TDD. User approved the discussed scope; no further design gate. One fresh read-only final review.

**Goal:** Easier budget-limited movement and more purposeful courtyard encounters with optional goals.
**Architecture:** Shared player-move evaluation returns the full route and legal affordable prefix without changing strict AI MoveCommand rules. Architecture generation3 owns colliding visible kit pieces; old generation2 is retained. Optional goals are separate runtime state sampled by CombatController atomic boundaries and frozen by encounter codes; campaign results own once-only rewards.
**Tech Stack:** Godot4.7.2, typed GDScript, existing dependency-free tests and original procedural mesh sources.
**Spec:** docs/MILESTONE_2_SCOPE.md

## Constraints

Preserve prior dirty work in the requested checkout; no commits/reset. One Godot process at a time; isolated test saves. No new combat mechanics, classes, difficulties or primary objectives. No extra action/movement grants. Keep UI clicks/cancellation and pause safe. Preserve old code/save layouts and baseline resource fingerprints. Use generation3 and explicit code/save compatibility for newly authored configuration.

## Review focus

Occupied budget boundary and revalidated endpoint cost; genuinely disconnected destinations; arch/door apertures vs physics and navigation; bonus outcome at the last atomic action; old interrupted saves and exact-once bonus rewards; restart/scene teardown clears all goal markers/state.

### A — Shared movement preview/execution
- [x] Baseline existing movement/input/generation/campaign/persistence tests.
- [x] RED tests for full valid route, green/red split, clipped endpoints, occupancy fallback, unreachable/zero budget, and real partial move spending.
- [x] Add CombatController.plan_player_move and player-only MoveCommand factory/flag; revalidate same plan before committing. Strict evaluate_move/AI remains strict. Add split path graphics and distinct stopping/requested markers and actual-route feedback/help.
- [x] GREEN new tests plus existing movement, player input, navigation, tutorial regressions.

### B — Courtyard architecture
- [x] RED tests for generation3 deterministic kinds/parts, arch passage and blocked pillar rays, house door/interior, valid0-decor/layout invariance, legacy2 signatures.
- [x] Add reusable CourtyardArchitecture kit with shaped meshes and matching collision, footprints/occlusion bounds. Compose presets and bounded fallback before navigation baking. Extend settings/config/code version validation while retaining old streams.
- [x] Validate at least90 maps across3 presets/3 objectives/10 seeds, with2/3/4 heroes represented; connectivity, clearance and objective routes.

### C — Optional goals and rewards
- [x] RED tests for authoritative cache inclusion, round boundary, incapacitation history, loss/abandonment, reward-once, configuration freezing, save migration and interrupted recovery.
- [x] Add three editable definitions and a small runtime controller; no rule duplication. New encounter codes carry stable goalID/hash. Versioned mission results preserve captured bonus; campaign resolve validates against frozen offer and grants once. Maintain old saves/codes via explicit migration.
- [x] Integrate briefing, HUD, world marker, combat log, result/debrief and setup summary; markers do not intercept clicks. Full lifecycle reset.

### D — Regression and delivery
- [x] Focused tests, complete source suite, deterministic encounters and compatibility fixtures. Record any pre-existing/native failures without suppressing.
- [x] Native renderer review both720p/1080p, multiple courtyard angles, move split and optional goals; screenshots.
- [x] One fresh read-only review, fix Important findings with RED/GREEN.
- [x] PCK export and external smoke; Windows EXE only if template available.
- [x] Report implemented scope, exact rewards/geometry, results, performance observations, limitations and modified files. Stop for review.

Verification caveat: full sweep104/111, then12/12 affected/related reruns passed; no fresh full111 sweep. Editor native crash and absent EXE template remain open. See final report.
