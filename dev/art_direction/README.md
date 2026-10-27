# Art-direction lab - run, validate and revert

The prototypes are already installed in the existing project:

`C:\Users\Daniel.Flinders\Documents\Codex\2026-10-20\implement-the-first-milestone-of-a\outputs\FantasyTactics`

## Open the preview

1. Open that project's `project.godot` in Godot 4.7.2.
2. In the FileSystem dock, open `dev/art_direction/comparison.tscn`.
3. Press **F6** (Run Current Scene).
4. Use **1 / 2 / 3** to compare A / B / C. Use **G / D / L** for matching gameplay / detail / architecture views. You can also click the labelled buttons.

F5 still opens the normal game. Switching direction preserves your current orbit/pan/zoom, actor positions, selected animation, marker visibility and freeze setting. Space animates/freezes; Q/W/E/R/T/Y chooses a clip; H toggles labels/rings; F9 hides the lab interface. Use RMB orbit, MMB or arrows to pan and the wheel to zoom. The existing camera also accepts WASD, so holding W while choosing Walk can briefly pan; arrows avoid that overlap.

From a terminal in the project directory, with a standard Godot 4.7.2 executable on PATH:

```powershell
godot --path . res://dev/art_direction/comparison.tscn
```

The standard non-.NET distribution was used for validation. The installed .NET editor initially reported missing .NET assemblies in this tool environment; no C# is required by this game.

## Deliverables

- [Artistic rules, palettes, scored comparison and recommendation](ART_DIRECTION_COMPARISON.md)
- [All matching views side by side](comparison-all-views.png)
- [Detail comparison](comparison-detail.png)
- [Gameplay comparison](comparison-gameplay.png)
- [Validation record and limitations](VALIDATION.md)
- [Recorded rendering sample](render-metrics.json)

A/B/C each have a 1920 x 1080 gameplay, detail and architecture image, plus a 1280 x 720 gameplay image. Individual image links are in the comparison document. All are real renderer captures. The contact sheets contain resized copies of those captures only.

## Files added to the project

All experimental source files are under **dev/art_direction/**:

| File | Purpose |
| --- | --- |
| comparison.tscn | F6 entry point; never referenced by the normal main scene |
| comparison.gd | Fixed composition, three local treatments, live switcher and camera/pose controls |
| geometry.gd | Original bevelled masonry, arch segments and folded-leaf mesh helpers |
| surface.gdshader | Compatibility material response: soft stylised / brushed / graphic bands |
| tests.gd | Camera/placement/clip invariants and normal-game startup after lab disposal |
| capture.gd | Reproducible screenshots, contact sheets and frame sample |
| README.md | In-project entry instructions |
| ART_DIRECTION_COMPARISON.md | In-project copy of the art rules and trade-offs |
| VALIDATION.md | In-project copy of verification and known limitations |

Godot also creates `.uid` companions and import/cache metadata for the new scripts/shader. These are normal authoring metadata.

**One existing project file changed:** `export_presets.cfg`. Its exclusion list now starts with `dev/art_direction/*, ` so the experiment does not ship in the Windows release pack. No production scripts, character source models, gameplay definitions, normal scenes, main-scene setting or input settings were edited for this milestone.

The existing faction-model work from the previous task remains intact. This experiment applies additional changes only to preview instances. The prototypes archive contains the development folder for backup/reapplication to this same project; it relies on that project's existing characters and courtyard assets and is not a standalone game.

## Reproduce checks and captures

Run in the project directory:

```powershell
godot --headless --path . --script res://dev/art_direction/tests.gd
godot --path . --rendering-method gl_compatibility --script res://dev/art_direction/capture.gd -- C:/your/writable/capture-folder
```

Capturing needs a graphics display; do not add `--headless` to the second command. The capture script freezes poses, sets exact camera presets and saves PNGs at both target resolutions. It samples 90 uncapped gameplay frames per option. It does not capture or alter real player saves.

## Revert

1. Close the preview scene/game.
2. Remove only the project's `dev/art_direction` folder, including its `.uid` companions.
3. Remove exactly `dev/art_direction/*, ` from the beginning of `exclude_filter` in `export_presets.cfg` if you want that file restored byte-for-byte apart from encoding. Keeping the exclusion is harmless.
4. Reopen Godot to refresh its generated cache. No changes to `project.godot`, gameplay scripts, original models, definitions, saves or settings need reversing.

The review images/documents are separate deliverables. Removing them is optional and has no effect on the game.

## Approval gate

No direction has been chosen. No art has been rolled out to normal maps or characters. Choose **A**, **B**, **C**, or describe a specific combination before work begins on the definitive polished reference scene.
