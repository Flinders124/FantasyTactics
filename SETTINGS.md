# Settings and accessibility

Open **Settings** on the title screen, **Pause** in combat, **P**, or the protected **F10** shortcut. The same interface serves menus, tutorials, results and encounters. Combat pauses while it is open. Tab/Shift+Tab moves focus; PgUp/PgDn changes categories; arrows change sliders/options; Enter/Space activates controls. Escape/F10 cancels. Primary menus support keyboard focus; this is not keyboard-only combat support.

Changes preview immediately. **Apply** accepts all categories and saves them; **Cancel / Resume** restores the values present when the panel opened, including bindings and confirmed display previews. **Reset Category** previews defaults only for that tab. Tutorial completion is never reset by these controls. Main Menu cancels previews before leaving the encounter.

## Options and defaults

| Category | Defaults and bounds |
| --- | --- |
| Display | Windowed 1280×720; 1600×900 and 1920×1080 also offered; borderless fullscreen and Windows exclusive fullscreen; VSync on; frame cap Unlimited, 30, 60, 120 or 144 |
| Cosmetic quality | Standard: shadows and 70% of foliage instances. Low: no directional shadows, 35% foliage, no blast sparks. High: shadows and all foliage. Existing rock/building meshes remain. |
| Audio | Master 80%, Music 55%, SFX 80%, Ambience 35%; independent mute states; 0–100% labelled sliders. Test Sound stops/replaces its previous test voice. |
| Camera | Orbit/pan/zoom sensitivity 1×, adjustable 0.25–2×; independent orbit-axis inversion off; edge scroll off, speed 1× (0.25–2×); reduced camera motion off |
| Accessibility | Interface scale 1× (0.85–1.15×), larger text off (+15%); high-contrast indicators off; reduced effects off; combat feedback text 1× (0.8–1.5×) |

Display mode/window resolution must be confirmed within **12 seconds**. Countdown and Keep/Revert remain active while combat is paused. Timeout or failure restores the last valid preview; Cancel restores the opening display even after Keep. Apply is unavailable during confirmation. Windowed requests larger than the current screen are rejected. Exclusive mode is rejected off Windows; headless/embedded previews cannot change the native display. Unsupported driver settings report failure rather than restarting combat. Native mode switching remains hardware dependent.

Quality changes only draw visibility and shadows. Foliage MultiMesh transforms, gameplay obstacles, collision layers, navigation, spawn positions, objective geometry and RNG streams remain unchanged. **No current graphics option requires an encounter reload.** No benchmark or performance improvement is implied by a preset name.

Camera pan sensitivity applies to both drag and keyboard/edge scrolling. Pitch, zoom and battlefield bounds remain enforced. Reduced motion retains initial battlefield framing and explicit Focus, suppressing subsequent automatic reframing. The existing camera has no shake or automatic turn-follow motion.

## Rebinding

All existing gameplay/camera actions accept a single physical keyboard key or mouse button/wheel where appropriate. Select the row, then provide the new input. Drag actions require a held key/button, not a wheel tick. Conflicts never commit silently: **Swap**, **Replace** (explicitly unbind the other action), or **Cancel**. Default WASD pan also has arrow alternatives. Category reset restores them.

Escape always remains Cancel and F10 always remains Settings, even when extra bindings are added. Tab, Enter and Space are reserved for UI navigation. These protections cannot be displaced through a conflicting bind. Capture Escape cancels capture; all captured events are consumed before world input. Controller support and modifier chords are not provided. HUD hints, help, tutorial instructions and action labels read the current InputMap. A keyboard world binding uses the current pointer position; pointer-free combat is not implemented.

## Presentation

Containers/scroll panels keep menus, settings, active-unit information, help and abilities usable with larger fonts. Focus has a gold outline. Tutorial guidance occupies the log sidebar while training so it cannot cover the marked destination; the authoritative log still records events and returns when training ends. Objective progress has its own left-side panel.

Faction letters, ACTIVE/OK/NO/ALLY HIT labels, indicator shapes, status names, area warnings and the combat log supplement colour and sound. High contrast adds stronger text outlines and depth-independent selection/health labels. Reduced effects suppress unit flashes, hit glyph bursts and blast decoration while preserving damage/healing/status text, targeting areas and outcomes. Combat text has an independent size multiplier. These improvements do not constitute formal accessibility compliance; human accessibility playtesting remains necessary.

## Ownership and persistence

The existing **GameAudio** remains the single preference owner (the legacy class/file names are retained to preserve callers). `SettingsSchema` is a validation/serialization helper; `SettingsPresentation` applies cosmetic options; `AudioSettingsPanel` is the unified transactional panel. No second settings singleton or encounter-config field was introduced.

Preferences remain in **user://audio_preferences.cfg**, now schema version **2**, including the existing `tutorial/completed` flag. On Windows this is normally `%APPDATA%/Godot/app_userdata/Fantasy Tactics/audio_preferences.cfg`. Old unversioned audio settings migrate; missing/invalid types use defaults, numeric values clamp, unknown binding maps revert safely, unsupported versions fall back. The last accepted file is retained as `.bak`; writes use `.tmp` then rename/restore. Corrupt primary data can recover the backup. A save failure leaves the panel open and keeps the previous accepted snapshot. Tutorial completion writes never persist unaccepted settings previews. There is no telemetry, account, campaign save or combat save.

Encounter pause uses named owners (`settings`, `guide`) so closing one overlay cannot release the other's pause. SceneTree pause freezes motors, AI processing, action timers, animations and encounter effects. The settings UI/countdown and background menu audio remain responsive. Closing/replacing an encounter cancels the settings transaction, clears pause ownership and retires old work through existing lifecycle cleanup. Presentation callbacks never own damage or spending.

UI/service backreferences intentionally use `Node` at the settings boundary: strong script-type cycles between the existing scene-flow/combat/presentation classes caused empty PackedScene instances and resource leaks during review. Typed helper data and local combat classes remain intact.
