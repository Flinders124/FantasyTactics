# Smarter tactical AI implementation plan

Goal: improve the existing shared bounded utility planner without changing combat rules, stats, player control or campaign formats.
Spec: user-provided Milestone2 Smarter Allies and Enemy Tactics attachment, 2026-10-27.
Architecture: EnemyTactics stays read-only; CombatController validates and commits every command. EnemyController owns bounded execution/cancellation. Role and faction profiles remain reusable resources. Tests may drive either faction; normal heroes remain player controlled because there is no existing allied-autoplay feature.

## Tasks and acceptance
- [x] A: record clean Git baseline, available Godot version and existing combat regression results; preserve a Git archive baseline for comparisons. Document existing healing/status, warning, role and navigation weaknesses.
- [x] B: failing tactical scenarios first: relevant Slowed versus stationary ranged opponent; critical healing with multiple observable threats; living blocker beyond a safe movement prefix; ranged clear-shot stability; warned-area escape/overlap/no escape; objective retention and support positioning.
- [x] B: minimally extend EnemyTactics and EnemyTacticalProfile. Bound all queries, reuse validation and add only decision-local threat/position caches. Improve status usefulness, meaningful healing, prefix navigation, bounded detours, survival and team spacing.
- [x] C: add small recent-turn movement/rejection memory in EnemyController, cleared on reset/ending. Preserve one move/action, serial guards and completion-driven execution. Structured bounded alternatives explain choices; disabled diagnostics must remain cheap.
- [x] D: deterministic scenarios and AI-versus-AI metrics across six hero pairs, factions, elites and existing objectives. Reproduce seed1740; do not raise watchdogs or hide failures. Test legality, cancellation, determinism and query caps.
- [ ] E: complete Milestone1 regression suite, representative simulations, decision-time comparison and supported export checks. Document actual results, balance impact and limitations; stop for review before Milestone3.

## Review focus
- Stale decisions after death, restart, turn change and navigation revisions must submit nothing.
- Safe movement prefixes may not cross living units; alternate candidates must still validate actual path cost.
- Warning checks use only committed public zones, including opposing warnings; no future input inspection.
- Hold/Extraction valuation must be faction aware without changing objective outcomes.
- No new playable-hero automation UI, mechanics, combat stat tuning or dependency framework.

Runtime evidence is stored under ignored verification/ai-m2; only source/tests/documentation changes belong in Git. Existing save formats and authored art are untouched.
Final Phase E status: verification executed, but acceptance is not signed off: 65/68 full suites passed; persistence/lifecycle timeouts and a native shutdown access violation remain. Separate 60 matches, six deterministic replays and four packed-resource smoke phases passed. See docs/TACTICAL_AI_MILESTONE_2.md. Stop for review; do not start Milestone3.
