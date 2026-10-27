# Headquarters camp overview

## Intent and scope
Replace the headquarters tab landing view with an inhabited, stylized 3D fantasy camp. Existing mission preparation, roster, recovery, training, inventory, progression and campaign rules remain authoritative and unchanged. This is a headquarters presentation change, not a new exploration or combat system.

## Approaches
- Selected by the player: a 3D camp overview with a gently movable camera and clickable locations. Spatial navigation gives the headquarters the inhabited feel requested without requiring character locomotion.
- Considered: walking a character between tents. More traversal and input complexity for the same existing menus; not selected.
- Considered: an illustrated 2D camp. Cheaper presentation but less depth and camera movement than the requested overview; not selected.

## Proposed presentation
Use original low-poly canvas tents, timber frames, a mission board, training dummies, equipment racks and a central campfire. Reuse existing character models, vegetation, stone meshes and compatible materials. Warm restrained lighting and modest idle animation make the camp feel occupied. Retain editable sources for new camp meshes.

Five labelled destinations open existing headquarters content:
- Mission board: mission offers and preparation.
- Companions’ tents: roster, injuries and recovery services.
- Training yard: permanent upgrade choices.
- Armoury tent: shop, owned equipment and transfers.
- Commander’s table: campaign history.

A compact top strip retains supplies, threat, campaign progress and session-only warning. Settings, help and the existing confirmed abandon flow remain accessible.

## Interaction
Click a location or its projected label to open the corresponding existing scrollable panel above the camp, with a clear Back to Camp control. Hover and keyboard focus identify the location by outline/label as well as colour. Provide a compact keyboard-focusable destination list as an alternative to precise world clicking. Background camp clicks cannot trigger actions through an open panel.

Use a bounded orbit with modest zoom and an explicit reset-view control; no free walking. Avoid camera motion while a menu or settings is active. Reduced-motion settings suppress nonessential camera transitions. Labels remain aligned with their locations at 1280×720 and 1920×1080 and respect existing text preferences.

## Integration and lifecycle
A scene-local camp view owns scenery, camera and location selection only. CampaignScreen retains the existing panel builders; CampaignCoordinator retains state changes and guarded transitions. Opening or rebuilding a panel must preserve its context without duplicating camp scenes, signals or purchases. Leaving headquarters releases the entire view. No shared definitions or tactical controls are changed.

## Validation
Check each destination, Back to Camp, hover/focus, keyboard navigation, view controls, settings overlays and repeated headquarters transitions. Retain campaign regression coverage for mission preparation, purchases, training and result processing. Run Godot parsing and focused lifecycle tests; capture and inspect both target resolutions where runtime tools permit. State visual checks actually performed.

## Builder decisions
Exact tent geometry, camp arrangement, material palette, camera bounds and animation amplitudes are implementation choices. Keep important landmarks and all five labels visible from the initial overview. No new dependencies or campaign mechanics.
