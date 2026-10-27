# Camp headquarters

Start **New Campaign** and establish the Watch to enter the interactive 3D camp.

| Location | Existing campaign page |
|---|---|
| Mission Board | Frozen offers, preparation and deployment |
| Companions’ Tents | Roster, injuries and recovery treatment |
| Training Yard | Permanent upgrades |
| Armoury Tent | Shop, inventory, equipment and transfers |
| Commander’s Table | Campaign history |

Select scenery or its projected label. Bottom destination buttons provide the same navigation. Tab/Enter operate buttons. **Back to Camp** or configured Cancel (default Escape) closes a page; PgUp/PgDn cycles pages. Default camera controls: right-button drag to orbit, wheel to zoom, Reset view to restore framing. Help displays actual bindings, including keyboard replacements. Orbit is bounded to ±0.48 radians; zoom to 0.86–1.15 of framed view. Camera position survives headquarters transactions. Pages, help, confirmations and settings block camp input.

## Editable original assets and architecture

- `scripts/camp_kit.gd`: original editable mesh source for peaked canvas tents with flaps, ropes, stakes and pennants; timber board with notices; dummies; equipment rack; map table; log fire ring. Native meshes are built locally on entering headquarters. No downloaded assets or dependencies.
- `scripts/camp_overview.gd`: composition, own-world viewport, lighting, picking, projected labels/leader lines, hover rings, bounded camera and preferences.
- Existing `assets/characters/models/*.glb`: four idle heroes, without tactical actors/controllers or mutable campaign statistics.
- Existing original courtyard meshes: shrubs, stones, benches, crate, barrel and cart. Their source/licence remains in `assets/courtyard`.
- New camp content is original project content under the same ownership/licence as existing original project assets. No third-party attribution is required.

`CampaignScreen` retains existing page builders in a scrollable overlay. `CampaignCoordinator` retains authoritative campaign actions and guarded transitions. No combat balance, mission generation, rewards, injury rules or saving changes. The camp's five pick bodies only select menus; they do not participate in combat/navigation. Dressing uses an independent fixed RNG. Scene-owned meshes, viewport, characters and connections are released on transition.

Reduced effects hides the fire mesh; reduced motion stops its restrained animation. Existing UI scaling, larger text and high-contrast focus remain active. Camera hints come from InputMap.

## Verification and limitations

See [actual verification and screenshots](../verification/CAMP_HEADQUARTERS.md). The camp is deliberately stylized and compact. Heroes idle in fixed places, without simulated schedules or free walking. Equipment keeps existing role visuals. Human usability and performance testing on other hardware remain outstanding.
