class_name SpecialisationCatalog
extends RefCounted
static func ids() -> PackedStringArray:
	return PackedStringArray(["knight", "ranger", "mage", "cleric", "aegisbearer", "chainbinder"])
static func definition(id: String) -> UnitDefinition:
	return HeroCatalog.find(id) if ids().has(id) else null

static func description(id: String) -> String:
	match id:
		"knight": return "Sword and shield. Strong melee burst and emergency healing; must close with distant foes."
		"ranger": return "Bow and quiver. Mobile ranged support, Slowed and Fireburst; minimum bow range and light armour demand spacing."
		"mage": return "Staff and focus. Ranged magic and area damage; fragile, with no healing. Fireburst can hit allies."
		"cleric": return "Mace and sacred emblem. Durable healer; short melee reach limits offence."
		"aegisbearer": return "Tower shield and spear. Prevent damage with a finite ward; low damage and no healing."
		"chainbinder": return "Hooked polearm and chain. Pull enemies or rescue allies from a distance; walls and occupied ground limit control."
	return ""
