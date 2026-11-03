# Milestone 2 — Tactical situations and optional objectives

Status: implementation authorised by the user after movement and courtyard scope discussion.

Goal: make existing tactical mechanics produce varied problems through tactical situations and optional objectives. Exact mission content remains to be planned.

## Confirmed addition: movement range preview and maximum-distance movement

Requested by the user: show the complete navigation route toward the hovered destination, green for the affordable portion and red beyond the active unit's remaining movement. Clicking a point beyond the budget should move as far as that budget permits, rather than rejecting the command or requiring precise distance selection.

- Measure the actual path around obstacles, not straight-line distance.
- Use remaining movement this turn, not always the default6 metres. Previous movement and existing status/equipment modifiers still apply.
- Display the reachable stopping point distinctly from the requested destination. Preview the movement cost actually executable and the total route distance.
- Clicking an over-budget reachable destination submits one move to the displayed legal stopping point. It does not queue movement for future turns.
- Keep existing collision, occupancy, navigation and command validation authoritative. A genuinely unreachable destination remains invalid; clipping a valid full route to budget must not treat a partial navigation result as reachable.
- If the budget boundary would leave the unit in an occupied or invalid position, choose an earlier legal point along the route and reflect it in the preview. If no useful legal move exists, explain why and spend nothing.
- Preview and submission share endpoint/path calculations, revalidated at submission. Charge only actual travel and retain existing bounded blocked-movement recovery.
- UI clicks, enemy turns, resolving actions and zero movement retain current input protections. Camera controls remain available.

Acceptance checks: green/red split follows bends around obstacles; partial remaining allowances work; clicking past range reaches the previewed stopping point without exceeding budget tolerance; occupied boundary points stop earlier safely; unreachable targets and invalid commands spend nothing; repeated inputs cannot queue moves; no automatic movement on following turns.


## Courtyard architecture and tactical situations

Reusable original architecture using the existing Lantern Oath materials: walk-through arches/gates, simple roofless ruined houses with door openings, fountains, solid carts, and altars. Compose these deliberately within existing courtyard presets, with clear approaches and spawn/objective clearance. Collision/navigation/visibility must match the actual assembled parts. Existing camera occlusion fading applies. No elevation, new themes, cover bonuses, or explorable house subsystems.

Implementation choices: generation3 for newly created skirmish/campaign setups; legacy generation2 and frozen codes/layouts remain unchanged. Existing mission templates continue to determine role composition; new architecture gives those existing situations meaningful route/visibility variation.

Optional goals use existing rules, with one separately seeded frozen goal per new mission: Recover Cache (a living hero reaches a small marked point at a completed-action boundary;8 bonus Supplies on victory), Swift Victory (win by round4;6 Supplies), Stand Together (win without any hero being incapacitated;6 Supplies). These editable initial values are my implementation choice, not a change to main objectives. No extra XP, failure penalty, captive NPC, escaping-enemy scripting, or new commands. Skirmishes show completion only; campaign bonus rewards apply once through existing authoritative result processing. Abandonment/failure never awards bonus Supplies. Briefing/HUD/result/debrief explain progress and reward. Restart and interrupted mission restore fresh progress from frozen setup.
