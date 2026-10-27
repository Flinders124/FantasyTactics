# Headquarters camp implementation plan

Goal: Deliver the approved interactive 3D headquarters overview without changing campaign rules.
Architecture: CampOverview owns a separate viewport, scenery and destination picking. CampaignScreen opens existing tab content in an overlay; CampaignCoordinator remembers whether the overlay is open across mutations.
Tech stack: Godot 4.7.2, typed GDScript, native meshes and existing character GLBs; no dependencies.
Spec: ../specs/2026-10-22-headquarters-camp-design.md

Constraints: Five destinations, keyboard alternatives, bounded camera, settings-aware motion, clean scene-local lifetime, both target resolutions.
Review focus: clicks behind overlays; settings input leakage; repeated panel rebuilds; projected labels clipping; scaling/keyboard access.

- [x] Test first: add camp_tests.gd asserting overview exists, five destinations open correct pages, Back to Camp, preserved equipment context, settings blocks view controls, repeated cleanup and both resolutions.
- [x] Camp assets: add editable CampKit source producing canvas tents, board, dummies, racks, fire ring; reuse courtyard props and character visuals.
- [x] CampOverview: own-world viewport, daylight/dusk lighting, scene composition, projected location buttons, geometric picking, focus/hover accents, bounded orbit/zoom/reset, preference application and input blocking.
- [x] CampaignScreen: preserve existing page builders in overlay; wire destinations and Back to Camp; keep compact campaign summary/help/settings/abandon accessible.
- [x] Coordinator: remember opened headquarters page during mutation; fresh campaign and return-to-HQ show overview.
- [x] Verify: focused tests, existing campaign rules/flow/play suites, GPU captures at 720p and 1080p including large text, inspect screenshots and correct layout defects. Document actual results and limitations.

Execution: Inline, already authorized by player to implement and test. No git repository exists, so work remains in the existing task workspace and no commit/worktree is created.

Execution record: all 44 regression suites passed with empty runtime stderr; both rendered review runs passed. Independent review found guide-layer visibility and keyboard camera-input defects, each pinned by failing then passing checks. Label overlap was reproduced and fixed at maximum text size; camera-extreme tests also pass. Editor import completed with the pre-existing Windows safe-save diagnostic; main-scene runtime smoke is clean. No Git integration is available in this workspace.
