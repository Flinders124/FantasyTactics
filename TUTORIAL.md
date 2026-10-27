# Tutorial and usability — milestone 7

Open `project.godot` in Godot 4.7.2 and run the main scene. Title **Tutorial** starts the authored training encounter; **New Encounter** retains the normal setup flow. No packages or new asset downloads are required.

## Guided sequence

1. Actually orbit, pan, zoom and focus the camera. Guidance also identifies the active initiative card and resource panel.
2. Select Move and hover the blue training ring; a valid, costed navigation preview advances the instruction.
3. Complete the marked move with Warden.
4. Complete a legal basic melee attack against Raider, spending the shared action.
5. Move to the second ring using the remaining movement from that same turn.
6. End Turn; observe the enemies' real turns completing and Scout becoming active.
7. Complete Scout's ranged Crippling Shot against Sentinel; inspect its cooldown and Slowed indicator.
8. Finish Elimination with normal commands. Only a successful final victory after these demonstrations records completion.

The fixed map uses seed **7001**, one boundary-side wall, Warden / Scout, and private copies of Raider / Sentinel with **10 / 8 maximum health**. Hero stats, movement, damage, abilities and timing are unchanged. Training opponents hold position and submit validated End Turn commands, with a short 0.5-second presentation delay between decisions. These explicit training settings never enter normal setup or normal tactical AI. The opening briefing explains the differences. Training configuration sharing is hidden; Replay Tutorial reconstructs the authored encounter, while New Skirmish returns to normal setup.

Only requested player commands are enabled until the final free-play step. This guidance policy is separate from combat legality: all allowed commands still pass through CombatController. Invalid commands, cancelled targeting and incomplete/blocked movement cannot advance steps or spend an extra action. A blocked move retains actual distance spent and can be retried. Missing/dead required actors offer a full tutorial restart; there is deliberately no unsafe partial-state “Restart Step.”

**Skip Tutorial**, **Restart Tutorial** and **Exit to Main Menu** remain available on the tutorial card and blocking tutorial guidance. Abandonment requires confirmation. Skip returns to normal setup without marking completion. Replay is always available, including after completion. Existing normal setup selections are preserved separately.

## Controls and help

Defaults: RMB drag orbit; MMB drag or WASD/arrows pan; wheel zoom; F focus; M Move; T Attack; 1/2/3 equipped abilities; E End Turn; Escape cancel; F1 Help; F10 Audio. Left-click commits movement/unit targeting; Fireburst uses a separate selection click and confirmation click. UI clicks do not issue world commands.

`ControlBindings` registers missing default InputMap actions under `tactics_` and generates displayed labels from their events. Existing configured actions are retained. Keyboard-only virtual events are normalized against those bindings as well. This is not a rebinding interface. The compact field guide shows primary pan bindings; the full guide also lists arrow alternatives.

**Briefing** reopens the current objective rules. Opening help or a briefing clears targeting and pauses simulation, AI timers/planning, movement and action resolution. Closing resumes the existing action. Camera processing and audio settings remain independent. The title/setup screens also expose F1 help. Focused combat/menu buttons have visible focus styles. Combat hover/focus tooltips wrap inside the viewport, including disabled ability cooldown explanations.

Optional guide sections explain obstruction, invalid range, shared action versus movement, Mend/full-health targets, cooldown/status timing, Hold Ground and Extraction. A safe Fireburst exercise is to select and inspect its friendly-fire preview, then press Escape before confirming; damaging a teammate is never required.

## Implementation and preferences

- `tutorial_encounter.gd`: authored configuration and validated teaching routes; copies definitions before training-only tuning.
- `tutorial_director.gd`: explicit steps; observes camera transform input, navigation previews, authoritative action completion, turn transitions and final outcome. Ability damage/ability notifications are treated as one resolved action. No timer or button-press completion conditions.
- `guide_overlay.gd`, `field_guide.gd`: reusable briefing/help and scoped pause/abandon controls.
- `readable_tooltips.gd`: bounded in-canvas hover and keyboard-focus tooltips; no gameplay ownership.
- `SceneFlow` retires old encounters; shutdown clears tutorial policy, pause ownership, guidance, AI and effects. In-place development restart resets the director too.
- Existing `GameAudio` ConfigFile (`user://audio_preferences.cfg`) also stores `[tutorial] completed=true`. Missing or wrong-type values default to false. Audio edits retain the preference. This is not a combat save. A gentle title suggestion is hidden after completion; normal play is never gated.

## Repeatable verification

Use the installed console executable or your Godot 4.7.2 console path:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'work/godot-appdata'
& work/godot-runtime/Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path outputs/FantasyTactics --script res://tests/tutorial_tests.gd
& work/godot-runtime/Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path outputs/FantasyTactics --script res://tests/usability_tests.gd
& outputs/FantasyTactics/tests/run_regressions.ps1 -Godot work/godot-runtime/Godot_v4.7.2-stable_mono_win64_console.exe -TimeoutSeconds 90
```

`tests/tutorial_review.gd` renders and interacts with the actual game in a local SubViewport, avoiding desktop-pointer interference. Run without `--headless`; add `-- 1080` for 1920×1080, otherwise it uses 1280×720. It captures under `../verification/tutorial/`. Its first preview uses real mouse events and navigation; the focused headless test separately injects a validated preview event to isolate director behaviour. The free-play finish uses legal automated hero commands, not a human playthrough.

## Remaining human playtest checklist

- Start with an incomplete tutorial preference (back up preferences, change only `[tutorial] completed=false`, then restore your file after testing).
- Without developer explanation, follow each instruction and describe the active hero, full path cost, shared action and remaining movement.
- Cancel targeting several times; make an invalid/out-of-range click; cancel and confirm Skip/Exit/Restart at different steps.
- Confirm that both enemy turn entries are understandable and that the third-round result explains replay/setup options.
- Replay, then launch normal skirmishes; inspect Elimination, Hold Ground and Extraction briefings and contextual feedback.
- At both resolutions, use Tab/Shift-Tab/Enter, hover disabled abilities and bottom/right-edge controls, and check text comfort and focus visibility.
- Inspect the optional Fireburst preview and cancel without friendly damage. Check audio access, camera comfort and pause/resume around help.

Automated success does not establish new-player usability, readability for every user, or accessibility. Screen-reader narration, text scaling, colour-vision presets and a full settings/accessibility pass remain milestone 8 work.
