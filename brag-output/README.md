# Fantasy Tactics — The Lantern Watch

`brag.mp4` is the finished 20-second 1920×1080, 60 fps trailer. The exact original music/SFX mix is preserved. `brag.jpg` shows the deliberately composed opening frame, which is also frame zero of the film. `share-copy.txt` is the ready-to-post caption.

The committed package contains the final video, poster, five Markdown context documents, share caption, and the compact `motion-verification.json` / `final-media.json` reports. Captures, source media, editing projects, scripts, intermediate renders, review screenshots and earlier versions are excluded by `.gitignore` and remain local.

The revision uses continuous native camera travel, full-width imagery, beat-led selection and transitions, and closer action. The hero introduction uses the project's existing art reference; the battle is staged using the existing development fixture. No gameplay rules were modified. See `motion-revision.md` for the edit and the measured 80 BPM timing grid.

## Local editing workspace

The original local workspace also contains the editable Hyperframes project in `composition/`; it is not part of this output/context commit. When that workspace is available:

```powershell
Set-Location C:\Work\_\FantasyTactics\brag-output\composition
hyperframes.cmd preview --background --port 3017
hyperframes.cmd check --json
hyperframes.cmd render --quality delivery --output ..\brag.mp4
```

The editor URL is `http://127.0.0.1:3017/#project/composition` while its local server is running. To stop it, run `hyperframes.cmd preview --stop` from the composition directory. Re-rendering replaces the poster-baked file; repeat the poster step from the brag skill after changing the video.

`capture_motion.gd` generates the revised native source frames with portable Godot 4.7.2 at fixed 60 fps; capture saves are isolated under `user://brag-motion/`. `build_motion_revision.py` encodes those frames and regenerates the five scene files. `capture.gd` and `build_composition.py` belong to version one. Edit the HTML directly for ordinary revisions; each build script overwrites it.

## Verification

- Hyperframes 0.8.207: full `check` passed, browser ran, zero errors and warnings. All 22 sampled DOM-text contrast checks passed. Two informational overflow notices are intentional camera reframing at clip edges. The full browser report remains in the local editing workspace.
- Native capture log confirms both Power Strike and Fireburst commands were accepted.
- Revised MP4: H.264 High / Level 4.2, 1920×1080, 60 fps, exactly 1,200 video frames / 20 seconds, AAC audio, fast-start enabled. Audio extends the container by 0.01 seconds.
- Every measured frame interval is 0.016666–0.016667 seconds. FFmpeg freeze detection (`n=-50dB`, minimum hold 0.25 s) found 12.2 seconds of frozen holds in version one and zero in version two (`motion-verification.json`). This is an automated cadence/motion measurement, not a guarantee of playback performance in every player.
- The final original/revised AAC packet SHA-256 hashes match exactly. The original audio mix and timing are unchanged, including the ending.
- Rendered opening, selection, deployment, strike, blast and closing frames were visually inspected. The opening is intentionally settled and poster-ready at frame zero; the old end-card flash is removed.
- Godot's tracked metadata changes were audited as line endings only, then restored from an explicit allowlist. All production tracked files are unchanged.

See `asset-notes.md`, `brag-plan.md` and `composition-brief.md` for provenance and creative choices. Everything remains local; nothing was published.
