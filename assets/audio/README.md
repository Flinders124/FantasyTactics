# Combat sound and effects

Original local audio for Fantasy Tactics, made with offline synthesis. **40 assets**, 48 kHz PCM16 source WAVs: 27 short movement/weapon/damage/death variations, seven ability/interface cues, three result stings, two stereo musical loops and one stereo courtyard ambience loop. The source WAVs and editable composition/synthesis script ship with the project. No online runtime, paid dependency, downloaded sample, third-party music or voice acting is used.

This is a deliberately synthesized fantasy palette: damped stone/metal transients, filtered noise, plucked-string and flute-like score layers, bell-like healing/status cues and quiet wind. It is not recorded orchestral music or sampled Foley. Listening quality and final mix approval remain a manual review step; valid imports and non-silent captured output do not establish sound quality.

## Sources and assets

`source/build_audio.py` is the editable source. It uses Python 3 and NumPy only for rebuilding; neither is required to play. From the project root:

```powershell
python assets/audio/source/build_audio.py
Godot_console.exe --headless --editor --path . --import --quit
```

All output files are in `clips/`; `manifest.json` records duration, channels, peak, RMS and loop-boundary delta. Source generation uses dedicated seeded NumPy generators, deterministic envelopes/resonators and original eight-bar D-minor chord arrangements. Music tails/echoes wrap around their loop length; ambience uses periodic filtered noise. Sources retain headroom, remove DC and taper one-shot ends. Godot imports the WAVs locally; `GameAudio` enables full-sample forward looping on duplicated music/ambience streams without mutating shared imported resources.

| Assets | Purpose |
| --- | --- |
| `step_0..2`, `armour_0..2` | Stone footfall/scrape and sparse metal movement |
| `swing_0..2`, `impact_0..2`, `mace_0..2` | Melee sweep, bright metal impact, lower blunt impact |
| `bow_0..2`, `arrow_0..2` | String release and short projectile impact |
| `damage_0..2`, `death_0..2` | Quiet body impact and short falling/body/equipment thud |
| `power`, `mend`, `slow`, `expire`, `fireburst`, `arcane` | Distinct ability/role cues; Fireburst is one blast, not one sound per victim |
| `ui`, `victory`, `defeat`, `draw` | Nonspatial interface click and result cadences |
| `menu` (24 s), `combat` (19.2 s), `courtyard` (12 s) | Soft musical loops and wind ambience |

Licence: [CC0 original-asset dedication](LICENSE.txt). No external attribution is required.

## Integration and ownership

- Existing `CombatController.combat_event` remains the authoritative event source. A monotonic event sequence/ID and committed action ID are added to snapshots. Actor/target positions and visual roles are copied at publication. Combat spending, damage, healing, status timing and outcomes stay in the controller; no audio/effect code submits damage or owns action completion.
- Existing `CombatPresentation` handles event-driven numbers, tracers, blast and new glyphs/sounds. It ignores replayed/stale event sequences, including across in-place restart. IDs do not reset during that controller's lifetime. New geometry helpers in `CombatEffectMeshes` create only meshes/materials.
- MovementMotor reports actual positive physics displacement. Footfalls occur per 0.65 m travelled; equipment rattle occurs every third step for armoured roles. Motor completion immediately removes pending/playing footsteps. Idle and blocked animation states cannot synthesize footsteps.
- Melee uses a short curved trail and impact. Power Strike has a broader golden trail and low impact. Ranged shots keep the existing immutable-position tracer/bead; Crippling Shot uses violet travel and a descending chevron/status cue. Mage bolts use an arcane cue; Cleric impacts use the blunt cue.
- Mend uses a rising cross/ring and `+N HP`. Damage uses `−N HP`, with a separate lane for status/death text alongside the health bar. Hit/heal overlays belong to individual MeshInstances, preserve the original overlay and restore after 0.13 s or reset. Definitions and shared materials are never recoloured.
- Fireburst uses a fixed outer ring at the **configured radius from its first frame**, an expanding internal wave and twelve small rising sparks. No opaque sphere hides units. Damage is already committed before this effect appears. A four-target blast has one main voice and at most two quiet death voices, not four stacked impacts. Existing skeletal death animation stays authoritative presentation for the fallen model.
- `GameAudio` is local to SceneFlow and persists between menus/replacement encounters. Direct development encounter scenes create one standalone service if no flow service exists. Menu/party share one track; turns and HUD updates never restart it. Loading/results fade tracks; combat starts its loop after navigation/encounter setup. Results play one brief nonspatial cue and let the courtyard ambience remain.

## Settings, spatial mix and bounds

`default_bus_layout.tres` provides **Master, Music, SFX, Ambience** with a Master limiter. Defaults: Master 80%, Music 55%, SFX 80%, Ambience 35%. Values never exceed unity bus gain. All music/UI sounds use nonspatial players; world cues use AudioStreamPlayer3D on SFX. Both music and effects have additional source headroom.

Use **Audio Settings** on the title, **Audio** in the encounter field guide, or **F10**. Sliders/mutes apply immediately and save to `user://audio_preferences.cfg`, outside encounter data. Missing files use defaults; malformed types use defaults, finite numeric values clamp to 0–1. Syntax-corrupt ConfigFile data falls back and displays a readable warning (Godot also emits its expected configuration parse diagnostic). Settings are not reset by Retry/New Battlefield. Escape/F10 closes the modal. It blocks combat clicks/shortcuts; **combat continues**, including AI, while it is open.

The world listener is fixed at arena centre, y=3 m, with a fixed orientation. Camera orbit/zoom/pan cannot pump volume or swing stereo violently. World players use unit size 20 m, maximum distance 120 m, max gain −6 dB, restrained panning strength 0.45 and a high attenuation-filter cutoff. This keeps the supported arena sizes audible; it is a tactical mix rather than a camera-mounted cinematic listener. Foley pitch variation is ±4%, using a dedicated presentation RNG that never touches gameplay or decoration RNG. Pitched magic remains at its composed tuning.

Caps: 12 total active/pending world voices, four nonspatial cue players, two crossfading music tracks, one ambience player, 16 transient glyphs, 24 floating labels, 12 tracers and four blasts. All delays are short entries in bounded local arrays, not uncancellable timers. Restart/scene shutdown clears world players, delayed sounds, glyphs, flashes, numbers and blast/tracer nodes. Scene-flow retirement keeps one global audio service; its nodes do not accumulate. Music fades use a small process envelope, not stacked tweens or signal callbacks.

## Verification and listening review

See [the current verification record](../../../verification/SOUND_EFFECTS.md) for the checks actually run, screenshots, mixer recording, limitations and performance sample. Run:

```powershell
./tests/run_regressions.ps1 -Godot C:/path/to/Godot_console.exe
Godot_console.exe --path . --script res://tests/sound_review.gd
Godot_console.exe --headless --path . --script res://tests/audio_preferences_roundtrip.gd -- write
Godot_console.exe --headless --path . --script res://tests/audio_preferences_roundtrip.gd -- read
```

The rendered review needs a graphics/audio device and should run **without fixed-fps**. Headless tests deliberately suppress actual playback to avoid dummy-mixer shutdown retention during accelerated simulation; they still load assets and verify scheduling, IDs, caps, controls and cleanup. The real-device review captures mixed audio and tests silent muted child buses. Neither test listens to audio.

Manual listening: start with low speaker/headphone volume; listen to a full title loop and two full combat/ambience loops; perform move/stop/block, sword, mace, bow, Focus Bolt, Power Strike, Mend, Crippling Shot and Fireburst; compare foreground cues against music/ambience. Check each mute and 0/100% setting, camera orbit/zoom and restart during sound tails. Check result cadences and smooth menu/party/combat transitions. Tune editable gains/score layers after listening. No HRTF, wall acoustic simulation, recorded instrument library, voiced efforts or dynamic adaptive score is provided in this milestone.
