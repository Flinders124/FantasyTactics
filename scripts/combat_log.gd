class_name CombatLog
extends Node

signal changed(entries: PackedStringArray)
@export_range(8, 100) var capacity: int = 40
var entries: PackedStringArray = PackedStringArray()

func bind(controller: CombatController) -> void:
	controller.combat_event.connect(_on_event)
	controller.encounter_reset.connect(clear)

func clear() -> void:
	entries.clear()
	changed.emit(entries)

func _on_event(kind: String, data: Dictionary) -> void:
	var message: String = ""
	match kind:
		"turn":
			message = "Round %d · %s's turn" % [data.round, data.actor]
		"move":
			message = "%s moved %.2f m. %s" % [data.actor, data.distance, data.reason]
		"attack":
			message = "%s → %s: %d damage · %s (%s)" % [data.actor, data.target, data.damage, data.attack_type, data.attack_name]
			if data.damage != data.health_lost:
				message += " (%d HP lost)" % data.health_lost
		"ability":
			message = "%s uses %s on %s." % [data.actor, data.ability, data.target]
		"heal":
			message = "%s restores %d HP to %s." % [data.actor, data.healing, data.target]
		"status_apply", "status_refresh":
			message = "%s: %s %s (%d future turns)." % [data.actor, data.status, "refreshed" if kind == "status_refresh" else "applied", data.turns]
		"status_expire":
			message = "%s: %s expired." % [data.actor, data.status]
		"telegraph_prepare":
			message="WARNING · %s prepares %s. Leave the marked area before its next turn."%[data.actor,data.ability]
		"telegraph_resolve":
			message="%s resolves %s."%[data.actor,data.ability]
		"telegraph_cancel":
			message="%s's prepared attack was cancelled."%data.actor
		"area":
			message = "%s uses %s: %d damage, %d unit(s) hit." % [data.actor, data.ability, data.damage, data.count]
		"area_hit":
			message = "%s: %d area damage (%d HP lost)%s." % [data.target, data.damage, data.health_lost, " · FRIENDLY FIRE" if data.friendly else ""]
		"death":
			message = "%s was defeated." % data.actor
		"objective":
			message = data.message
		"result":
			message = "DRAW · Both factions eliminated." if data.get("draw", false) else ("VICTORY · All enemies defeated." if data.victory else "DEFEAT · All heroes defeated.")
	if kind=="result" and data.has("reason"):
		message=("DRAW" if data.get("draw",false) else ("VICTORY" if data.victory else "DEFEAT"))+" · "+str(data.reason)
	if message.is_empty():
		return
	entries.append(message)
	while entries.size() > capacity:
		entries.remove_at(0)
	changed.emit(entries)
