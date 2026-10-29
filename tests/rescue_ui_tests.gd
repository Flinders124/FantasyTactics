extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var encounter: Node3D = load("res://scenes/combat_encounter.tscn").instantiate()
 encounter.get_node("EnemyController").enabled = false
 root.add_child(encounter)
 while not encounter.navigation_ready: await physics_frame
 var controller: CombatController = encounter.get_node("CombatController")
 var player: PlayerController = encounter.get_node("PlayerController")
 var hud: CanvasLayer = encounter.get_node("HUD")
 while controller.scheduler.active_unit().faction != CombatUnit.Faction.HERO:
  controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
 check(hud.rescue_buttons.size() == 4 and not hud.rescue_row.visible, "Skirmish hides all four rescue buttons")
 player.target_rescue(0)
 check(player.selected_rescue == -1, "Skirmish cannot enter rescue targeting")
 controller.survival_enabled = true
 hud._refresh()
 check(hud.rescue_row.visible, "Campaign exposes rescue controls")
 hud.rescue_buttons[0].pressed.emit()
 check(player.selected_rescue == 0 and player.mode == PlayerController.Mode.ATTACK and hud.rescue_buttons[0].button_pressed, "Stabilise selects exclusive target mode")
 player.cancel_targeting()
 check(player.selected_rescue == -1 and player.mode == PlayerController.Mode.NONE, "Cancellation clears rescue selection")
 hud.rescue_buttons[1].pressed.emit()
 check(player.selected_rescue == 1, "Carry selects ally targeting")
 player.toggle_attack_targeting()
 check(player.selected_rescue == -1 and player.mode == PlayerController.Mode.ATTACK, "Basic attack replaces rescue targeting")
 var ability := AbilityDefinition.new()
 ability.display_name = "Preview"
 ability.magnitude = 3
 ability.displacement_distance = 2.0
 ability.effect = AbilityDefinition.Effect.WARD
 check(player.ability_preview_text(ability, null).contains("3 damage absorption"), "Ward explains absorption")
 ability.effect = AbilityDefinition.Effect.PULL
 check(player.ability_preview_text(ability, null).contains("3 damage") and player.ability_preview_text(ability, null).contains("pull up to 2.0 m"), "Reel distinguishes damage and displacement")
 ability.effect = AbilityDefinition.Effect.TOW
 check(player.ability_preview_text(ability, null).contains("Tow ally up to 2.0 m") and player.ability_preview_text(ability, null).contains("no damage"), "Tow never claims healing or damage")
 check(hud.rescue_buttons[0].tooltip_text.contains("3 future round-end") and hud.rescue_buttons[1].tooltip_text.contains("halves movement") and hud.rescue_buttons[3].tooltip_text.contains("permanent"), "Rescue controls explain campaign survival consequences")
 player.cancel_targeting()
 encounter.queue_free()
 await process_frame
 print("RESCUE UI RESULT: %d failures" % failures)
 quit(1 if failures else 0)
