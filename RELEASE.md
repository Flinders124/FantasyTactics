# Fantasy Tactics 0.12.0-rc1 — Windows release candidate

Double-click FantasyTactics.exe. Game resources are embedded: no separate PCK,
Godot editor, SDK, .NET installation or internet connection is required.
Windows x86_64 with a compatible graphics driver is required. The executable is
unsigned. Include the accompanying licence notices when redistributing.

## Building

From C:\Temp\FantasyTactics:

    powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1

Requires the standard Godot4.7.2 editor under verification/toolchain/standard
and templates/windows_release_x86_64.exe under verification/toolchain.
Download the official matching archive and extract only that file:
https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
Archive SHA256: f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011

The portable build script imports, checks export scope, exports the embedded
release and copies notices/checksums. Output: releases/FantasyTactics-0.12.0-rc1.
Logs and private editor data: verification/windows-standalone.
Build only after source tests pass. Player saves are never part of the build.

## Packaging scope

The all_resources preset deliberately retains every imported runtime resource:
string-loaded character GLBs, audio WAVs, courtyard mesh/collision/material .res
and .tres files, every campaign/unit/objective/difficulty/preset definition and
main/combat scenes. Authoring sources, tests, tools, documentation, showcases and
editor templates are excluded. Export resource remaps may replace source paths
with .godot/imported entries; inspect with ResourceLoader.exists, not OS paths.

## Smoke checks before distribution

Launch the copied release directory outside the source project. Check title,
New Campaign, recruit/party selection, mission launch, movement and combat,
mission result/return to camp, save/quit, process relaunch and Continue. Verify
custom controls, volume/display settings and tutorial. Confirm all four hero
models, enemies, courtyard materials and sounds load without missing-resource
errors. Capture 1280x720 and 1920x1080 screenshots. The official native template disables external --script overrides. For automated
resource and campaign checks, run the editor with --main-pack pointing to the
shipped PCK and an external SceneTree harness. This tests packed game resources;
native executable launch and interactive review are separate checks. Avoid
changing the normal save location during interactive migration checks.

The executable is unsigned. Code signing is a separate distribution step.
This candidate must pass the standalone smoke checks before being called tested.

## Licences

Original environment, characters and synthesized audio are CC0 (the three
included asset licence files contain their provenance). Original FT branding is
CC0. Godot is MIT; GODOT-LICENSE.txt and GODOT-THIRD-PARTY.txt contain the exact
engine version copyright, licence and third-party notices alongside the binary. See
https://godotengine.org/license/ and https://docs.godotengine.org/en/stable/about/complying_with_licenses.html.

Build documentation:
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html


## Campaign continuation
Continue Campaign resumes accepted headquarters changes and completed debriefs.
Deployment is saved before combat. Closing during a mission restarts that exact
mission from its initial deployment when you Continue; it is not a mid-combat
save. Confirmed abandonment applies failure consequences instead. Campaign and
settings files live under `%APPDATA%\Godot\app_userdata\Fantasy Tactics`, never
beside the executable. Failed saves show Retry Save; do not dismiss the app if
it reports unsaved progress. Corrupt saves require explicit backup recovery or
confirmed replacement. Rules/content versions must match this release.

This unsigned release candidate still needs human balance/usability testing and
clean-machine testing on additional Windows/GPU configurations. Automated matches
are diagnostic; they do not establish player-facing balance.

## Recorded release verification

The shipped PCK passed an external four-process test with the Godot 4.7.2 editor:
create seed 17 Easy campaign, buy/equip Reachguard in HQ, save/relaunch, Continue,
commit Knight/Ranger mission, close during an enemy turn, Continue the same
layout/seed/roster/configuration with fresh tactical resources, complete an actual
battle (victory in seven rounds), and reopen the saved debrief without duplicate
rewards. Volume settings survived all four processes. The isolated test save is
under work/release-smoke-userdata; actual player files were not used.

Workspace command: powershell -ExecutionPolicy Bypass -File work/run_release_smoke.ps1 -Runtime editor-pack
Use a fresh isolated userdata directory for a new full run. Evidence is in
outputs/verification/release/native-1..4.json and .log (the engine header records
the editor runtime). Native executable title launch also passed. Packed dynamic
resource checks loaded 148 resources and verified development files are absent.

Text resources remain text in the PCK: Godot 4.7.2 binary export conversion lost
campaign item compatible_heroes arrays in the reproduced release export. The
project disables that conversion; packed item and campaign codec probes pass.
