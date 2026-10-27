# Brag Plan: Fantasy Tactics

> Revision 2 supersedes the original edit below: native 60 fps continuous camera shots, 80 BPM / 0.75 s beat grid, scene changes at 3/6/9 seconds, actions at 11/13.5 seconds and final reveal at 16 seconds. Preserve the exact original music/SFX mix. See motion-revision.md and the current composition for the complete revised implementation.

## The nine answers
1. A turn-based fantasy tactics game: establish the Lantern Watch, choose two of four heroes, and fight a five-victory campaign.
2. The impressive contrast: only two heroes deploy, but every mission changes the campaign's threat, injuries, supplies and progression.
3. The visual hook is the Lantern Oath world: blue-stone ruins, copper leaves, teal armour and warm brass.
4. Show the real 3D headquarters, the actual two-hero preparation screen, and real command-driven combat using the existing developer fixture.
5. Twenty seconds is enough to carry headquarters → party → battle → title.
6. Cinematic; a small party against a larger world. Earnest, compact and grounded in the game.
7. Use the project's original D-minor combat/menu score with its own weapon/magic/interface cues. No narration.
8. “Two heroes. One last beacon. Fantasy Tactics: build the Lantern Watch, choose your pair, and make every turn count.”
9. Headquarters → choose a mission and two heroes → deploy and use abilities. The capture demonstrates the actual UI and authoritative commands; the combat shot is staged with the existing development fixture.

## The angle and hook
“TWO HEROES.” over the actual paired heroes; “ONE LAST BEACON.” completes the premise. The Last Beacon is the campaign's authored finale. No promise of a released storefront or invented gameplay feature.

## Tone and format
Cinematic, 1920 × 1080 landscape, 30 fps, 20 seconds. Music and SFX on; voice off. My creative choice: a restrained indie-game trailer with large editorial titles beside live game imagery. Default brag invocation authorizes the full local video workflow.

## Visual identity
HUD ground #101E28, panel #172D36, paper #F2E5C9, gold #E8BC78, teal #64C6BB, copper #D98A67; world blue stone #556D83. Game uses Godot's fallback sans; video uses bundled EB Garamond 700 for cinematic titles and Montserrat 400/700 for small labels (a deliberate video typography choice).
LOOK: solid #101E28 ground; #F2E5C9 title ink; #E8BC78 accent; EB Garamond 700 titles at 92–146 px; Montserrat 700 labels at 28–32 px; 104 px margins; 2 px brass rules; game imagery occupies 55–100% of each shot. BANNED: generic SaaS cards, invented stats, stock footage, generated game art, animated gradient backgrounds.

## Storyboard
1. **The pair — 0–3 s.** Close view of actual Warden and Arcanist, “TWO HEROES.”; title settles rapidly and holds. A low impact accompanies the reveal. Actual visual from the source game, not generated art.
2. **The Watch — 3–7 s.** Actual headquarters, with a measured camera orbit; “BUILD THE WATCH.” and “Headquarters → mission board” as a short label. UI click as the mission board is selected. Any recreated interaction is based on source UI.
3. **The choice — 7–11 s.** Actual preparation/party view, two selected heroes; “CHOOSE YOUR TWO.” with a concise four-role line. Roles reveal together and hold at least 2 s. Subtle selection sound.
4. **The turn — 11–16 s.** Actual staged combat using existing real-command fixture: Power Strike followed by Fireburst if captures permit. “MAKE EVERY TURN COUNT.”; motion-matched sword/magic sounds. Readability takes priority over beat locks.
5. **The beacon — 16–20 s.** Source courtyard/hero imagery beside the title “FANTASY TACTICS”, “ONE LAST BEACON.” and “Turn-based fantasy • The Lantern Watch”. Brass emblem comes from the game's branding icon. Final end card holds at least 2 s; music fades to a short victory cadence.

## Music cue guidance
The project's original menu.wav (24 s) and combat.wav (19.2 s) are original CC0 D-minor loops. Prefer one continuous menu bed for the complete 20 s, with combat effects providing escalation. No brag bundled cue preset exists for these project tracks; measured audio-energy data may guide the brass accent only. Cue timing is secondary to clear text and real actions. SFX sparse, moderate gain. No beat/BPM claim without detection.

## Integrity
Source: README.md, CAMPAIGN.md, scripts/oath_ui.gd, scripts/lantern_art.gd, campaign/camp UI and dev/combat/showcase.gd. No personal data or secrets. Stage combat through existing authoritative commands; do not imply capture is unscripted gameplay. Do not modify production game logic. All outputs remain local.
